import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../utils/log_util.dart';

/// 空的 [HttpOverrides] 实现（使用默认 createHttpClient）。
/// 用于创建绕过全局代理配置的 HttpClient，
/// 避免直连模式下 DoH 查询流量被本地代理二次代理造成回环。
class BypassHttpOverrides extends HttpOverrides {}

/// DNS-over-HTTPS 解析结果
class _ResolvedHost {
  final List<String> ips;
  final DateTime expiry;

  _ResolvedHost(this.ips, this.expiry);
}

/// DNS-over-HTTPS 解析器
///
/// 通过阿里/腾讯公共 DoH 的 JSON 接口查询域名真实 IP，
/// 绕过本地 DNS 污染；查询失败时回退系统解析。
class DohResolver {
  /// 依次尝试的 DoH 服务器（JSON API，国内可直连）
  static const List<String> _servers = [
    'https://dns.alidns.com/resolve',
    'https://doh.pub/dns-query',
  ];

  static const Duration _queryTimeout = Duration(seconds: 5);
  static const Duration _minTtl = Duration(seconds: 60);
  static const Duration _maxTtl = Duration(minutes: 10);

  final Map<String, _ResolvedHost> _cache = {};
  final Map<String, Future<List<String>>> _inFlight = {};
  final HttpClient _client = HttpOverrides.runWithHttpOverrides(
    () => HttpClient()..connectionTimeout = _queryTimeout,
    BypassHttpOverrides(),
  );

  int _nextServer = 0;

  /// 解析域名，返回 IPv4 列表
  Future<List<String>> lookup(String host) {
    if (InternetAddress.tryParse(host) != null) {
      return Future.value([host]);
    }

    final cached = _cache[host];
    if (cached != null && cached.expiry.isAfter(DateTime.now())) {
      return Future.value(cached.ips);
    }

    // 去重并发查询
    final running = _inFlight[host];
    if (running != null) {
      return running;
    }

    final future = _resolve(host).then((ips) {
      return ips;
    }).whenComplete(() {
      _inFlight.remove(host);
    });
    _inFlight[host] = future;
    return future;
  }

  Future<List<String>> _resolve(String host) async {
    Object? lastError;
    // 依次尝试各 DoH 服务器
    for (var i = 0; i < _servers.length; i++) {
      final index = (_nextServer + i) % _servers.length;
      try {
        final ips = await _query(_servers[index], host);
        if (ips.isNotEmpty) {
          _nextServer = index;
          return ips;
        }
      } catch (e) {
        lastError = e;
        LogUtil.error('DoH query failed (${_servers[index]}, $host)', e);
      }
    }

    // 兜底：系统解析（行为等同标准模式，至少不比不开直连差）
    try {
      final addresses = await InternetAddress.lookup(
        host,
        type: InternetAddressType.IPv4,
      );
      return addresses.map((e) => e.address).toList();
    } catch (e) {
      LogUtil.error('System DNS lookup failed ($host)', e);
      if (lastError != null) {
        throw lastError;
      }
      rethrow;
    }
  }

  Future<List<String>> _query(String server, String host) async {
    final uri = Uri.parse(
      '$server?name=${Uri.encodeQueryComponent(host)}&type=A',
    );

    final HttpClientRequest request;
    try {
      request = await _client.getUrl(uri).timeout(_queryTimeout);
    } on TimeoutException {
      throw TimeoutException('DoH connect timeout', _queryTimeout);
    }
    request.headers.set(HttpHeaders.acceptHeader, 'application/dns-json');

    final HttpClientResponse response;
    try {
      response = await request.close().timeout(_queryTimeout);
    } on TimeoutException {
      throw TimeoutException('DoH response timeout', _queryTimeout);
    }

    if (response.statusCode != 200) {
      throw HttpException('DoH $server returned ${response.statusCode}');
    }

    final body = await utf8.decoder.bind(response).join();
    final data = jsonDecode(body);
    if (data is! Map) {
      return const [];
    }

    final answers = data['Answer'];
    if (answers is! List) {
      return const [];
    }

    final ips = <String>[];
    var ttl = 0;
    for (final answer in answers) {
      if (answer is! Map) continue;
      if (answer['type'] != 1) continue;
      final ip = answer['data'];
      if (ip is! String) continue;
      final address = InternetAddress.tryParse(ip);
      if (address == null || address.type != InternetAddressType.IPv4) {
        continue;
      }
      ips.add(ip);
      final answerTtl = answer['TTL'];
      if (answerTtl is int && (ttl == 0 || answerTtl < ttl)) {
        ttl = answerTtl;
      }
    }

    if (ips.isNotEmpty) {
      var clamped = Duration(seconds: ttl);
      if (clamped < _minTtl) clamped = _minTtl;
      if (clamped > _maxTtl) clamped = _maxTtl;
      _cache[host] = _ResolvedHost(
        ips,
        DateTime.now().add(clamped),
      );
    }
    return ips;
  }

  void dispose() {
    _client.close(force: true);
    _cache.clear();
  }
}
