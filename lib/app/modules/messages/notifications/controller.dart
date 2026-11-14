import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

import '../../../components/iwr_refresh/controller.dart';
import '../../../data/enums/result.dart';
import '../../../data/models/account/notifications/notification.dart';
import '../../../data/services/user_service.dart';

class NotificationsController extends IwrRefreshController<NotificationItemModel> {
  final UserService userService = Get.find();

  @override
  Future<GroupResult<NotificationItemModel>> getNewData(int currentPage) {
    return userService.getNotifications(currentPage).then((value) {
      if (value.success) {
        return value.data!;
      } else {
        throw Exception(value.message);
      }
    });
  }

  Future<void> markAllRead() async {
    SmartDialog.showLoading();
    bool ok = await userService.readAllNotifications();
    SmartDialog.dismiss(status: SmartStatus.loading);
    if (ok) {
      refreshData(showSplash: true);
    }
  }

  Future<void> markRead(int index) async {
    NotificationItemModel notification = data[index];
    if (notification.read) return;

    bool ok = await userService.readNotification(notification.id);
    if (ok) {
      notification.read = true;
      data[index] = notification;
    }
  }
}
