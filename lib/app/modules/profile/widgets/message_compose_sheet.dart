import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:iwrqk/i18n/strings.g.dart';

import '../../../data/models/user.dart';
import '../../../data/services/user_service.dart';
import '../../../routes/pages.dart';

class MessageComposeSheet extends StatefulWidget {
  final UserModel targetUser;

  const MessageComposeSheet({super.key, required this.targetUser});

  @override
  State<MessageComposeSheet> createState() => _MessageComposeSheetState();
}

class _MessageComposeSheetState extends State<MessageComposeSheet> {
  final UserService _userService = Get.find();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final RxBool _isSending = false.obs;

  Future<void> _send() async {
    String title = _titleController.text.trim();
    String body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      SmartDialog.showToast(t.messages.title_or_body_empty);
      return;
    }

    _isSending.value = true;
    final result = await _userService.createConversation(
      userId: widget.targetUser.id,
      title: title,
      body: body,
    );
    _isSending.value = false;

    if (!result.success || result.data == null) {
      SmartDialog.showToast(result.message ?? t.notifications.error);
      return;
    }

    Get.back();
    Get.toNamed(
      AppRoutes.conversationDetail,
      arguments: {"conversation": result.data},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        color: Theme.of(context).colorScheme.surface,
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              t.profile.message,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: t.messages.title,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160, minHeight: 80),
              child: TextField(
                controller: _bodyController,
                maxLines: null,
                expands: false,
                decoration: InputDecoration(
                  labelText: t.messages.message_body,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.targetUser.name,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Obx(
                  () => FilledButton(
                    onPressed: _isSending.value ? null : _send,
                    child: _isSending.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(t.messages.send),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }
}
