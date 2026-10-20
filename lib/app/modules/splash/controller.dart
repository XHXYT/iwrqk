import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:iwrqk/i18n/strings.g.dart';

import '../../data/providers/storage_provider.dart';
import '../../data/services/user_service.dart';
import '../../routes/pages.dart';

class SplashController extends GetxController with GetTickerProviderStateMixin {
  final UserService _userService = Get.find();

  void init(BuildContext context) {
    _runInitTask();
  }

  Future<void> _runInitTask() async {
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      print('>>> splash start');
      final accepted = StorageProvider.config.get(
        StorageKey.accpetedRules,
        defaultValue: false,
      );
      print('>>> splash acceptedRules=$accepted');
      if (!accepted) {
        print('>>> splash -> rules');
        Get.offNamed(AppRoutes.rules);
        return;
      }
      print('>>> splash step1: canLoginFromCache');
      final canLogin = await _userService.accountService.canLoginFromCache();
      print('>>> splash step1 done: $canLogin');
      if (canLogin) {
        print('>>> splash step2: loginFromCache');
        bool success = await _userService.accountService.loginFromCache().then((
          value,
        ) {
          print('>>> splash step2 login result: ${value.success}');
          if (value.success) {
            return true;
          } else {
            SmartDialog.showToast(t.account.require_login);
            return false;
          }
        });
        print('>>> splash step2 done: $success');
        if (success) {
          print('>>> splash step3: userService.init');
          success = await _userService.init();
          print('>>> splash step3 done: $success');
        }
        if (!success) {
          print('>>> splash login failed -> home + login');
          // 网络失败时仅重置内存状态，保留 token，
          // 避免因暂时性网络问题把登录凭据清掉导致被登出
          _userService.accountService.reset();
          Get.offNamed(AppRoutes.home);
          SchedulerBinding.instance.addPostFrameCallback((_) {
            Get.toNamed(AppRoutes.login);
          });
          return;
        }
      } else {
        print('>>> splash step1b: reloginOnTokenExpired');
        final relogin =
            await _userService.accountService.reloginOnTokenExpired();
        print('>>> splash step1b result: ${relogin.success}');
        if (relogin.success) {
          bool success = await _userService.init();
          print('>>> splash relogin init: $success');
          if (!success) {
            _userService.accountService.reset();
          }
        }
      }
      print('>>> splash -> home');
      Get.offNamed(AppRoutes.home);
      return;
    });
  }
}
