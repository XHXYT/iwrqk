import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iwrqk/i18n/strings.g.dart';

import '../../../components/iwr_refresh/widget.dart';
import '../../../components/network_image.dart';
import '../../../data/models/account/conversations/conversation.dart';
import '../../../data/services/user_service.dart';
import '../../../routes/pages.dart';
import '../../../utils/display_util.dart';
import 'controller.dart';

class ConversationsPreviewPage
    extends GetView<ConversationsPreviewController> {
  const ConversationsPreviewPage({super.key});

  String _resolveAvatarUrl(
    ConversationModel conversation,
    String selfUserId,
  ) {
    for (var participant in conversation.participants) {
      if (participant.id != selfUserId) {
        return participant.avatarUrl;
      }
    }
    if (conversation.participants.isNotEmpty) {
      return conversation.participants.first.avatarUrl;
    }
    return '';
  }

  Widget _buildConversationTile(ConversationModel conversation) {
    UserService userService = Get.find();
    String selfUserId = userService.user?.id ?? '';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipOval(
        child: NetworkImg(
          imageUrl: _resolveAvatarUrl(conversation, selfUserId),
          width: 48,
          height: 48,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              conversation.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight:
                    conversation.unread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (conversation.unread)
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(left: 6),
              decoration: BoxDecoration(
                color: Theme.of(Get.context!).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
      subtitle: Text(
        conversation.lastMessage.body,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        DisplayUtil.getDisplayTime(DateTime.parse(conversation.updatedAt)),
        style: const TextStyle(fontSize: 12),
      ),
      onTap: () {
        Get.toNamed(
          AppRoutes.conversationDetail,
          arguments: {"conversation": conversation},
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t.messages.messages)),
      body: IwrRefresh<ConversationModel>(
        controller: controller,
        requireLogin: true,
        builder: (data, scrollController) {
          return CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  return _buildConversationTile(data[index]);
                }, childCount: data.length),
              ),
            ],
          );
        },
      ),
    );
  }
}
