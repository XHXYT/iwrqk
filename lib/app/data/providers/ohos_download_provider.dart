import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 鸿蒙下载目录 Provider：管理"下载/应用名"公共目录的授权与文件搬移
class OhosDownloadProvider {
  static const _channel = MethodChannel('iwrqk/download_path');

  static String? _cachedDir;

  /// 获取公共下载目录路径；首次调用会弹系统授权框
  /// 返回 null 表示用户取消授权或平台不支持
  static Future<String?> getDownloadDir() async {
    if (_cachedDir != null) return _cachedDir;
    try {
      final path = await _channel.invokeMethod<String>('getDownloadDir');
      _cachedDir = path;
      return path;
    } on PlatformException catch (e) {
      debugPrint('getDownloadDir failed: ${e.message}');
      return null;
    } on MissingPluginException {
      return null; // 非 ohos 平台未注册该通道
    }
  }

  /// 把沙箱内下载完成的文件移动到公共下载目录
  /// 返回最终路径；失败返回 null（调用方降级为保留沙箱文件）
  static Future<String?> moveFile(String sandboxPath, String fileName) async {
    try {
      return await _channel.invokeMethod<String>(
        'moveFile',
        {'srcPath': sandboxPath, 'fileName': fileName},
      );
    } on PlatformException catch (e) {
      debugPrint('moveFile failed: ${e.message}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
