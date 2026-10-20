import '../providers/storage_provider.dart';

/// 网络连接模式
enum NetworkMode {
  /// 标准连接：使用系统网络直接访问
  standard('standard'),

  /// 直连：通过 DoH 解析域名真实 IP 后直接连接
  direct('direct'),

  /// 代理：通过用户配置的代理服务器访问
  proxy('proxy');

  final String value;

  const NetworkMode(this.value);

  static NetworkMode fromValue(String? value) {
    switch (value) {
      case 'direct':
        return NetworkMode.direct;
      case 'proxy':
        return NetworkMode.proxy;
      default:
        return NetworkMode.standard;
    }
  }

  /// 从配置读取当前模式
  ///
  /// 兼容旧版本 `proxyEnable` 开关：未保存过新模式且旧开关开启时迁移为代理模式。
  static NetworkMode load() {
    final saved = StorageProvider.config[StorageKey.networkMode];
    if (saved is String && saved.isNotEmpty) {
      return fromValue(saved);
    }
    if (StorageProvider.config[StorageKey.proxyEnable] == true) {
      return NetworkMode.proxy;
    }
    return NetworkMode.standard;
  }

  /// 持久化当前模式
  void save() {
    StorageProvider.config[StorageKey.networkMode] = value;
  }
}
