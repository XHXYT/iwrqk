import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:iwrqk/i18n/strings.g.dart';

import '../../../data/enums/result.dart';
import '../../../data/models/account/conversations/conversation.dart';
import '../../../data/models/account/conversations/message.dart';
import '../../../data/providers/api_provider.dart';
import '../../../data/services/user_service.dart';
import '../../../utils/log_util.dart';

class ConversationDetailController extends GetxController {
  final UserService userService = Get.find();

  late ConversationModel conversation;

  final RxList<MessageModel> messages = <MessageModel>[].obs;

  final RxBool isLoading = false.obs;
  final RxBool isSending = false.obs;
  final RxBool loadFailed = false.obs;

  bool hasMore = true;

  final ScrollController scrollController = ScrollController();
  final TextEditingController inputController = TextEditingController();
  final FocusNode inputFocusNode = FocusNode();

  String get selfUserId => userService.user?.id ?? '';

  @override
  void onInit() {
    super.onInit();

    conversation = Get.arguments["conversation"];

    scrollController.addListener(() {
      if (scrollController.position.pixels >=
              scrollController.position.maxScrollExtent - 200 &&
          !isLoading.value &&
          hasMore) {
        loadMessages();
      }
    });

    loadMessages();
  }

  Future<void> loadMessages() async {
    if (isLoading.value) return;
    isLoading.value = true;

    try {
      String before = messages.isEmpty
          ? DateTime.now().toUtc().toIso8601String()
          : messages.last.createdAt;

      ApiResult<MessageResult> result = await ApiProvider.getMessages(
        conversation.id,
        before,
      );

      if (result.success) {
        List<MessageModel> newMessages = List.from(result.data!.results)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (newMessages.isEmpty) {
          hasMore = false;
        }
        messages.addAll(newMessages);
        loadFailed.value = false;
      } else {
        throw Exception(result.message);
      }
    } catch (e, stackTrace) {
      LogUtil.warning("Failed to load messages", e, stackTrace);
      if (messages.isEmpty) {
        loadFailed.value = true;
      } else {
        SmartDialog.showToast(e.toString());
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshMessages() async {
    hasMore = true;
    loadFailed.value = false;
    messages.clear();
    await loadMessages();
  }

  Future<void> sendMessage() async {
    String content = inputController.text.trim();
    if (content.isEmpty || isSending.value) return;
    isSending.value = true;

    try {
      ApiResult<MessageModel> result = await userService.sendMessage(
        conversationId: conversation.id,
        content: content,
      );

      if (result.success && result.data != null) {
        messages.insert(0, result.data!);
        inputController.clear();
        conversation.lastMessage = result.data!;
        conversation.numMessages += 1;
      } else {
        SmartDialog.showToast(result.message ?? t.notifications.error);
      }
    } finally {
      isSending.value = false;
    }
  }

  @override
  void onClose() {
    scrollController.dispose();
    inputController.dispose();
    inputFocusNode.dispose();
    super.onClose();
  }
}
