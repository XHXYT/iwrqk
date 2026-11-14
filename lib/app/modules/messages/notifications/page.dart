import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iwrqk/i18n/strings.g.dart';

import '../../../components/iwr_refresh/widget.dart';
import '../../../components/network_image.dart';
import '../../../data/enums/types.dart';
import '../../../data/models/account/notifications/notification.dart';
import '../../../utils/display_util.dart';
import 'controller.dart';

class NotificationsPage extends GetView<NotificationsController> {
  const NotificationsPage({super.key});

  String? _resolveItemLabel(NotificationItemModel notification) {
    switch (notification.type) {
      case 'newComment':
      case 'newReply':
        final doc =
            notification.video ??
            notification.image ??
            notification.profile ??
            notification.post;
        if (doc == null) return null;
        return doc.title ?? doc.username ?? doc.id;
      case 'videoReady':
        return notification.video?.title ?? notification.video?.id;
      case 'tagApproved':
        return notification.tag?.id;
      default:
        return null;
    }
  }

  String _resolveTitleText(NotificationItemModel notification) {
    String? item = _resolveItemLabel(notification) ?? '';
    switch (notification.type) {
      case 'newComment':
        return t.notifications.new_comment(
          user: notification.comment?.user.name ?? '',
          item: item,
        );
      case 'newReply':
        return t.notifications.new_reply(
          user: notification.comment?.user.name ?? '',
          item: item,
        );
      case 'videoReady':
        return t.notifications.video_ready(item: item);
      case 'tagApproved':
        return t.notifications.tag_approved(item: item);
      case 'joinedCreatorProgram':
        return t.notifications.joined_creator_program;
      case 'warning':
        return t.notifications.warning;
      case 'reviewApproved':
        return t.notifications.review_approved;
      case 'reviewRejected':
        return t.notifications.review_rejected;
      default:
        return t.notifications.default_notification;
    }
  }

  Widget _resolveLeading(
    BuildContext context,
    NotificationItemModel notification,
  ) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    if (notification.type == 'newComment' || notification.type == 'newReply') {
      return ClipOval(
        child: NetworkImg(
          imageUrl: notification.comment?.user.avatarUrl ?? '',
          width: 44,
          height: 44,
        ),
      );
    }

    IconData icon;
    switch (notification.type) {
      case 'videoReady':
        icon = Icons.videocam;
        break;
      case 'warning':
        icon = Icons.warning_amber_rounded;
        break;
      case 'tagApproved':
        icon = Icons.label;
        break;
      case 'joinedCreatorProgram':
        icon = Icons.star;
        break;
      case 'reviewApproved':
        icon = Icons.check_circle;
        break;
      case 'reviewRejected':
        icon = Icons.cancel;
        break;
      default:
        icon = Icons.notifications;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: colorScheme.onPrimaryContainer, size: 22),
    );
  }

  void _onTap(int index, NotificationItemModel notification) {
    controller.markRead(index);

    switch (notification.type) {
      case 'newComment':
      case 'newReply':
        if (notification.video != null) {
          Get.toNamed(
            "/mediaDetail?id=${notification.video!.id}",
            arguments: {"mediaType": MediaType.video},
          );
        } else if (notification.image != null) {
          Get.toNamed(
            "/mediaDetail?id=${notification.image!.id}",
            arguments: {"mediaType": MediaType.image},
          );
        } else if (notification.profile?.username != null) {
          Get.toNamed("/profile?userName=${notification.profile!.username}");
        }
        break;
      case 'videoReady':
        if (notification.video != null) {
          Get.toNamed(
            "/mediaDetail?id=${notification.video!.id}",
            arguments: {"mediaType": MediaType.video},
          );
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t.notifications.notifications),
        actions: [
          IconButton(
            tooltip: t.notifications.mark_all_read,
            onPressed: controller.markAllRead,
            icon: const Icon(Icons.done_all),
          ),
        ],
      ),
      body: IwrRefresh<NotificationItemModel>(
        controller: controller,
        requireLogin: true,
        builder: (data, scrollController) {
          return CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final notification = data[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: _resolveLeading(context, notification),
                    title: Text(
                      _resolveTitleText(notification),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight:
                            notification.read
                                ? FontWeight.normal
                                : FontWeight.bold,
                      ),
                    ),
                    subtitle:
                        (notification.type == 'newComment' ||
                            notification.type == 'newReply') &&
                        notification.comment != null
                        ? Text(
                            notification.comment!.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          DisplayUtil.getDisplayTime(
                            DateTime.parse(notification.createdAt),
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (!notification.read)
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    onTap: () => _onTap(index, notification),
                  );
                }, childCount: data.length),
              ),
            ],
          );
        },
      ),
    );
  }
}
