import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iwrqk/i18n/strings.g.dart';

import '../../../components/load_fail.dart';
import 'controller.dart';
import 'widgets/message_bubble.dart';

class ConversationDetailPage extends GetView<ConversationDetailController> {
  const ConversationDetailPage({super.key});

  Widget _buildInputBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller.inputController,
              focusNode: controller.inputFocusNode,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: t.messages.type_message,
                isDense: true,
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Obx(
            () => IconButton.filled(
              onPressed: controller.isSending.value
                  ? null
                  : controller.sendMessage,
              icon: controller.isSending.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          controller.conversation.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              if (controller.loadFailed.value) {
                return Center(
                  child: LoadFail(
                    errorMessage: t.refresh.failed,
                    onRefresh: controller.refreshMessages,
                  ),
                );
              }
              if (controller.messages.isEmpty &&
                  controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView.builder(
                controller: controller.scrollController,
                reverse: true,
                padding: const EdgeInsets.only(top: 12, bottom: 12),
                itemCount: controller.messages.length,
                itemBuilder: (context, index) {
                  final message = controller.messages[index];
                  final bool isMe = message.user.id == controller.selfUserId;
                  final bool showUser;
                  if (index == controller.messages.length - 1) {
                    showUser = !isMe;
                  } else {
                    final next = controller.messages[index + 1];
                    showUser = !isMe && next.user.id != message.user.id;
                  }
                  return MessageBubble(
                    message: message,
                    isMe: isMe,
                    showUser: showUser,
                  );
                },
              );
            }),
          ),
          _buildInputBar(context),
        ],
      ),
    );
  }
}
