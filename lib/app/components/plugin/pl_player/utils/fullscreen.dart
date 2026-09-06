import 'dart:io';
import 'package:auto_orientation_v2/auto_orientation_v2.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

/// dart:io 的 Platform 没有 isOhos，用 operatingSystem 判断
bool get isOhos => Platform.operatingSystem == 'ohos';

// 横屏
Future<void> landScape() async {
  dynamic document;
  try {
    if (kIsWeb) {
      await document.documentElement?.requestFullscreen();
    } else if (isOhos) {
      // ohos：弃用 AutoOrientation（未适配），直接用 SystemChrome
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else if (Platform.isAndroid) {
      await AutoOrientation.landscapeAutoMode(forceSensor: true);
    } else if (Platform.isIOS) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      await const MethodChannel(
        'com.alexmercerind/media_kit_video',
      ).invokeMethod('Utils.EnterNativeFullscreen');
    }
  } catch (exception, stacktrace) {
    debugPrint(exception.toString());
    debugPrint(stacktrace.toString());
  }
}

// 竖屏
Future<void> verticalScreen() async {
  if (Platform.isAndroid) {
    await AutoOrientation.portraitUpMode();
  } else {
    // ohos 走这里，SystemChrome 竖屏在 ohos 上正常回包
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }
}

Future<void> enterFullScreen() async {
  if (Platform.isWindows) {
    await windowManager.setFullScreen(true);
    return;
  }
  // 注意：ohos 上 immersiveSticky 的 Future 不回包（引擎 bug），
  // 调用方不应 await 本函数
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
}

// 退出全屏显示
Future<void> exitFullScreen() async {
  if (Platform.isWindows) {
    await windowManager.setFullScreen(false);
    return;
  }
  dynamic document;
  late SystemUiMode mode = SystemUiMode.edgeToEdge;
  try {
    if (kIsWeb) {
      document.exitFullscreen();
    } else if (Platform.isAndroid || Platform.isIOS || isOhos) {
      if (Platform.isAndroid &&
          (await DeviceInfoPlugin().androidInfo).version.sdkInt < 29) {
        mode = SystemUiMode.manual;
      }
      try {
        await SystemChrome.setEnabledSystemUIMode(
          mode,
          overlays: SystemUiOverlay.values,
        ).timeout(const Duration(milliseconds: 800));
      } catch (e) {
        debugPrint('exitFullScreen: restore UI mode timeout: $e');
      }
      await SystemChrome.setPreferredOrientations([]);
      // 全屏切换不改变状态栏颜色，样式只由详情页进入/离开时管理
    } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      await const MethodChannel(
        'com.alexmercerind/media_kit_video',
      ).invokeMethod('Utils.ExitNativeFullscreen');
    }
  } catch (exception, stacktrace) {
    debugPrint(exception.toString());
    debugPrint(stacktrace.toString());
  }
}

