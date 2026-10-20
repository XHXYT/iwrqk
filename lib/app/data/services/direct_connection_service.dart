import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../utils/log_util.dart';
import 'doh_resolver.dart';

/// 直连模式本地代理服务
///
/// 在本机回环地址启动一个 HTTP 代理，所有流量经它转发：
/// - CONNECT 请求（HTTPS）：通过 DoH 解析目标域名的真实 IP，
///   直接与 IP 建立 TCP 连接后做双向隧道，绕过本地 DNS 污染；
/// - 普通 HTTP 请求：解析后向真实 IP 直接转发。
///
/// 回退策略：直连失败（解析失败/TCP 连不上）时，若用户配置了
/// 回退代理（即"代理设置"中的地址），自动改走该代理隧道，并将
/// 该域名拉黑一段时间（拉黑期内直接走代理，不再等待直连超时）。
///
/// 客户端 TLS 端到端保留（SNI/证书校验不受影响）。
class DirectConnectionService {
  DirectConnectionService._internal();

  static final DirectConnectionService instance =
      DirectConnectionService._internal();

  final DohResolver _resolver = DohResolver();

  HttpServer? _server;
  int? _port;

  /// 回退代理（用户在代理设置中配置的地址）
  String? _fallbackProxyHost;
  int? _fallbackProxyPort;

  /// 直连失败的域名拉黑表（域名 -> 拉黑截止时间）
  final Map<String, DateTime> _directFailUntil = {};

  /// 本地代理监听端口，未启动时为 null
  int? get port => _port;

  bool get isRunning => _server != null;

  static const Duration _directConnectTimeout = Duration(seconds: 5);
  static const Duration _proxyConnectTimeout = Duration(seconds: 8);

  /// 直连失败后的拉黑时长：期间该域名直接走回退代理
  static const Duration _directFailRetryInterval = Duration(minutes: 10);

  static final List<int> _connectionEstablished = utf8.encode(
    'HTTP/1.1 200 Connection Established\r\n\r\n',
  );

  static final List<int> _badGatewayResponse = utf8.encode(
    'HTTP/1.1 502 Bad Gateway\r\n'
    'Content-Length: 0\r\n'
    'Connection: close\r\n'
    '\r\n',
  );

  static final RegExp _httpStatusRegExp = RegExp(r'^HTTP/\d(?:\.\d)? (\d{3})');

  /// 逐跳头，转发时不应复制
  static const Set<String> _hopByHopHeaders = {
    HttpHeaders.connectionHeader,
    'keep-alive',
    'proxy-connection',
    'te',
    'trailers',
    HttpHeaders.transferEncodingHeader,
    HttpHeaders.upgradeHeader,
    HttpHeaders.proxyAuthenticateHeader,
    HttpHeaders.proxyAuthorizationHeader,
  };

  HttpClient? _forwardClient;
  HttpClient? _proxyForwardClient;

  /// 启动本地代理（幂等）
  ///
  /// [fallbackProxyHost]/[fallbackProxyPort]：直连失败时回退使用的代理。
  Future<void> start({
    String? fallbackProxyHost,
    int? fallbackProxyPort,
  }) async {
    if (_server != null) return;

    _fallbackProxyHost = fallbackProxyHost;
    _fallbackProxyPort = fallbackProxyPort;

    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
      shared: false,
    );
    _server = server;
    _port = server.port;
    server.listen(_handleClient, onError: (Object e) {
      LogUtil.error('DirectConnection server error', e);
    });
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _port = null;
    if (server != null) {
      await server.close(force: true);
    }
    _forwardClient?.close(force: true);
    _forwardClient = null;
    _proxyForwardClient?.close(force: true);
    _proxyForwardClient = null;
    _resolver.dispose();
    _directFailUntil.clear();
  }

  void _handleClient(HttpRequest request) async {
    try {
      if (request.method == 'CONNECT') {
        await _tunnel(request);
      } else {
        await _forward(request);
      }
    } catch (e, s) {
      LogUtil.error(
        'DirectConnection handle ${request.method} failed',
        e,
        s,
      );
      try {
        request.response.statusCode = HttpStatus.badGateway;
        await request.response.close();
      } catch (_) {}
    }
  }

  bool get _fallbackReady =>
      _fallbackProxyHost != null && _fallbackProxyPort != null;

  bool _isDirectBlacklisted(String host) {
    final until = _directFailUntil[host];
    if (until == null) return false;
    if (until.isBefore(DateTime.now())) {
      _directFailUntil.remove(host);
      return false;
    }
    return true;
  }

  void _blacklistHost(String host) {
    _directFailUntil[host] = DateTime.now().add(_directFailRetryInterval);
  }

  /// CONNECT 隧道：直连优先，失败回退代理
  Future<void> _tunnel(HttpRequest request) async {
    final (host, port) = _parseAuthority(request);
    final blacklisted = _isDirectBlacklisted(host);

    // 1. 直连（拉黑期内跳过）
    if (!blacklisted) {
      Socket? direct;
      try {
        final ips = await _resolver.lookup(host);
        direct = await _connectFirstSuccess(ips, port);
      } catch (_) {
        // 解析或连接失败，尝试回退
      }
      if (direct != null) {
        _directFailUntil.remove(host);
        await _tunnelDirect(request, direct);
        return;
      }
    }

    // 2. 回退代理
    Socket? proxySocket;
    if (_fallbackReady) {
      try {
        proxySocket = await Socket.connect(
          _fallbackProxyHost!,
          _fallbackProxyPort!,
          timeout: _proxyConnectTimeout,
        );
      } catch (e) {
        LogUtil.error('Connect fallback proxy failed ($host:$port)', e);
      }
    }
    if (proxySocket != null) {
      final ok = await _establishFallbackTunnel(
        request,
        proxySocket,
        host,
        port,
      );
      if (ok) {
        _blacklistHost(host);
      } else {
        // 代理拒绝：清除拉黑，让下次重试直连
        _directFailUntil.remove(host);
      }
      return;
    }

    // 3. 回退代理不可用：若因拉黑跳过了直连，最后再试一次直连
    if (blacklisted) {
      _directFailUntil.remove(host);
      try {
        final ips = await _resolver.lookup(host);
        final socket = await _connectFirstSuccess(ips, port);
        if (socket != null) {
          await _tunnelDirect(request, socket);
          return;
        }
      } catch (_) {}
    }

    // 4. 全部失败
    LogUtil.error('Open upstream failed ($host:$port)', null);
    request.response.statusCode = HttpStatus.badGateway;
    await request.response.close();
  }

  /// 直连隧道：TCP 已连上，直接双向转发
  Future<void> _tunnelDirect(HttpRequest request, Socket upstream) async {
    final clientSocket = await request.response.detachSocket(
      writeHeaders: false,
    );
    clientSocket.add(_connectionEstablished);
    await clientSocket.flush();

    unawaited(_pipe(upstream, clientSocket));
    await _pipe(clientSocket, upstream);
  }

  /// 通过回退代理建立隧道。
  ///
  /// 注意：detach 之后无法再用 [HttpResponse] 回复，失败时向客户端
  /// 写入原始 502 响应后关闭连接。
  ///
  /// 返回是否成功建立隧道。
  Future<bool> _establishFallbackTunnel(
    HttpRequest request,
    Socket proxySocket,
    String host,
    int port,
  ) async {
    final Socket clientSocket;
    try {
      clientSocket = await request.response.detachSocket(writeHeaders: false);
    } catch (e) {
      LogUtil.error('Detach socket failed', e);
      proxySocket.destroy();
      try {
        request.response.statusCode = HttpStatus.badGateway;
        await request.response.close();
      } catch (_) {}
      return false;
    }

    // 持久监听代理 socket：先解析代理响应头，确认 200 后转发隧道数据。
    // 不能用 StreamIterator/addStream 重复订阅（单订阅流，二次订阅会失效）。
    final established = Completer<void>();
    final buffer = <int>[];

    proxySocket.listen(
      (data) {
        if (established.isCompleted) {
          try {
            clientSocket.add(data);
          } catch (_) {
            proxySocket.destroy();
          }
          return;
        }
        buffer.addAll(data);
        final end = _indexOfHeaderEnd(buffer);
        if (end < 0) return;
        final header = utf8.decode(
          buffer.sublist(0, end),
          allowMalformed: true,
        );
        final match = _httpStatusRegExp.firstMatch(header);
        if (match != null && match.group(1) == '200') {
          try {
            clientSocket.add(_connectionEstablished);
            final leftover = buffer.sublist(end + 4);
            if (leftover.isNotEmpty) {
              clientSocket.add(leftover);
            }
            established.complete();
          } catch (e) {
            established.completeError(e);
          }
        } else {
          established.completeError(
            HttpException('Fallback proxy rejected CONNECT: $header'),
          );
        }
      },
      onDone: () {
        if (!established.isCompleted) {
          established.completeError(
            const HttpException('Fallback proxy closed before response'),
          );
        }
        clientSocket.destroy();
      },
      onError: (Object e) {
        if (!established.isCompleted) {
          established.completeError(e);
        }
        clientSocket.destroy();
      },
      cancelOnError: true,
    );

    try {
      proxySocket.write('CONNECT $host:$port HTTP/1.1\r\nHost: $host:$port\r\n\r\n');
      await proxySocket.flush();
      await established.future.timeout(_proxyConnectTimeout);
    } catch (e) {
      LogUtil.error('Fallback proxy CONNECT failed ($host:$port)', e);
      proxySocket.destroy();
      _respondRawBadGateway(clientSocket);
      return false;
    }

    // 隧道建立：客户端数据经写端发往代理
    unawaited(
      proxySocket.addStream(clientSocket).then((_) {
        proxySocket.close();
      }, onError: (Object _) {
        proxySocket.destroy();
        clientSocket.destroy();
      }),
    );
    return true;
  }

  void _respondRawBadGateway(Socket clientSocket) {
    try {
      clientSocket.add(_badGatewayResponse);
      unawaited(
        clientSocket.flush().then((_) {
          clientSocket.destroy();
        }, onError: (Object _) {
          clientSocket.destroy();
        }),
      );
    } catch (_) {
      clientSocket.destroy();
    }
  }

  /// 并发连接所有 IP，取第一个成功的连接
  Future<Socket?> _connectFirstSuccess(List<String> ips, int port) {
    if (ips.isEmpty) return Future.value(null);

    final completer = Completer<Socket?>();
    var remaining = ips.length;

    void onFail() {
      remaining--;
      if (remaining == 0 && !completer.isCompleted) {
        completer.complete(null);
      }
    }

    for (final ip in ips) {
      Socket.connect(ip, port, timeout: _directConnectTimeout)
          .then((socket) {
        if (!completer.isCompleted) {
          completer.complete(socket);
        } else {
          socket.destroy();
        }
      }).catchError((Object _) {
        onFail();
      });
    }
    return completer.future;
  }

  static int _indexOfHeaderEnd(List<int> bytes) {
    for (var i = 0; i + 3 < bytes.length; i++) {
      if (bytes[i] == 13 && bytes[i + 1] == 10 && bytes[i + 2] == 13 &&
          bytes[i + 3] == 10) {
        return i;
      }
    }
    return -1;
  }

  /// 普通 HTTP 请求（absolute-form）直接转发（失败回退代理）
  Future<void> _forward(HttpRequest request) async {
    final target = request.uri.hasScheme ? request.uri : request.requestedUri;
    final host = target.host;
    final useProxy = _fallbackReady && _isDirectBlacklisted(host);

    HttpClientRequest outgoing;
    try {
      final client = useProxy ? _getProxyForwardClient() : _getForwardClient();
      outgoing = await client.openUrl(request.method, target);
    } catch (e) {
      if (_fallbackReady) {
        LogUtil.error('Direct forward failed ($host)', e);
        _blacklistHost(host);
        final client = _getProxyForwardClient();
        outgoing = await client.openUrl(request.method, target);
      } else {
        rethrow;
      }
    }

    outgoing.followRedirects = false;
    request.headers.forEach((String name, List<String> values) {
      if (_hopByHopHeaders.contains(name.toLowerCase())) return;
      for (final value in values) {
        outgoing.headers.add(name, value);
      }
    });
    if (outgoing.headers.value(HttpHeaders.hostHeader) == null) {
      outgoing.headers.set(
        HttpHeaders.hostHeader,
        target.hasPort ? '${target.host}:${target.port}' : target.host,
      );
    }
    await outgoing.addStream(request);

    final response = await outgoing.close();
    final clientResponse = request.response;
    clientResponse.statusCode = response.statusCode;
    if (response.reasonPhrase.isNotEmpty) {
      clientResponse.reasonPhrase = response.reasonPhrase;
    }
    response.headers.forEach((String name, List<String> values) {
      if (_hopByHopHeaders.contains(name.toLowerCase())) return;
      for (final value in values) {
        try {
          clientResponse.headers.add(name, value);
        } catch (_) {
          // 忽略不可设置的响应头
        }
      }
    });
    await clientResponse.addStream(response);
    await clientResponse.close();
  }

  HttpClient _getForwardClient() {
    final existing = _forwardClient;
    if (existing != null) {
      return existing;
    }
    final client = HttpOverrides.runWithHttpOverrides(
      () => HttpClient()..connectionTimeout = _directConnectTimeout,
      BypassHttpOverrides(),
    );
    _forwardClient = client;
    return client;
  }

  /// 走回退代理的转发客户端
  HttpClient _getProxyForwardClient() {
    final existing = _proxyForwardClient;
    if (existing != null) {
      return existing;
    }
    final proxyHost = _fallbackProxyHost;
    final proxyPort = _fallbackProxyPort;
    final client = HttpOverrides.runWithHttpOverrides(() {
      return HttpClient()
        ..connectionTimeout = _proxyConnectTimeout
        ..findProxy = (uri) => 'PROXY $proxyHost:$proxyPort;';
    }, BypassHttpOverrides());
    _proxyForwardClient = client;
    return client;
  }

  static Future<void> _pipe(Socket from, Socket to) async {
    try {
      await to.addStream(from);
      await to.close();
    } catch (_) {
      // 隧道任一方向异常时直接销毁两端
      from.destroy();
      to.destroy();
    }
  }

  /// 解析 CONNECT 请求的目标 authority（host, port）
  (String, int) _parseAuthority(HttpRequest request) {
    String authority;
    final hostHeader = request.headers.value(HttpHeaders.hostHeader);
    if (hostHeader != null && hostHeader.isNotEmpty) {
      authority = hostHeader;
    } else if (request.uri.host.isNotEmpty) {
      return (
        request.uri.host,
        request.uri.hasPort ? request.uri.port : 443,
      );
    } else {
      authority = request.uri.toString();
    }

    final parsed = Uri.tryParse(authority);
    if (parsed != null && parsed.host.isNotEmpty) {
      return (parsed.host, parsed.hasPort ? parsed.port : 443);
    }

    final idx = authority.lastIndexOf(':');
    if (idx > 0 && idx < authority.length - 1) {
      final port = int.tryParse(authority.substring(idx + 1));
      if (port != null) {
        return (authority.substring(0, idx), port);
      }
    }
    return (authority, 443);
  }
}
