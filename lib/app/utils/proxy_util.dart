import 'dart:io';

import '../data/models/network_mode.dart';
import '../data/providers/storage_provider.dart';
import '../data/services/direct_connection_service.dart';
import 'log_util.dart';

class ProxyUtil {
  static NetworkMode _mode = NetworkMode.standard;

  /// 当前生效的网络模式（[init] 之后有效）
  static NetworkMode get mode => _mode;

  static Future<void> init() async {
    final mode = NetworkMode.load();
    _mode = mode;

    switch (mode) {
      case NetworkMode.standard:
        break;
      case NetworkMode.direct:
        try {
          final proxyHost = StorageProvider.config[StorageKey.proxyHost];
          final proxyPort = StorageProvider.config[StorageKey.proxyPort];
          await DirectConnectionService.instance.start(
            fallbackProxyHost:
                (proxyHost != null && proxyHost.isNotEmpty) ? proxyHost : null,
            fallbackProxyPort: (proxyPort != null && proxyPort.isNotEmpty)
                ? int.tryParse(proxyPort)
                : null,
          );
          final port = DirectConnectionService.instance.port;
          if (port != null) {
            HttpOverrides.global = ProxiedHttpOverrides(
              InternetAddress.loopbackIPv4.address,
              '$port',
            );
          } else {
            _mode = NetworkMode.standard;
          }
        } catch (e) {
          // 本地直连代理启动失败时回退为标准模式
          LogUtil.error('DirectConnectionService start failed', e);
          _mode = NetworkMode.standard;
        }
        break;
      case NetworkMode.proxy:
        final proxyHost = StorageProvider.config[StorageKey.proxyHost];
        final proxyPort = StorageProvider.config[StorageKey.proxyPort];
        if (proxyHost != null &&
            proxyPort != null &&
            proxyHost.isNotEmpty &&
            proxyPort.isNotEmpty) {
          HttpOverrides.global = ProxiedHttpOverrides(proxyHost, proxyPort);
        } else {
          _mode = NetworkMode.standard;
        }
        break;
    }
  }
}

class ProxiedHttpOverrides extends HttpOverrides {
  final String _port;
  final String _host;

  ProxiedHttpOverrides(this._host, this._port);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..findProxy = (uri) {
        // DoH 服务器必须直连，避免查询流量被本地代理回环
        final host = uri.host;
        if (host == 'dns.alidns.com' || host == 'doh.pub') {
          return 'DIRECT';
        }
        return 'PROXY $_host:$_port;';
      };
  }
}
