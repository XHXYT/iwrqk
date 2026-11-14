import 'package:get/get.dart';

import '../../../components/iwr_refresh/controller.dart';
import '../../../data/enums/result.dart';
import '../../../data/models/account/conversations/conversation.dart';
import '../../../data/services/user_service.dart';

class ConversationsPreviewController
    extends IwrRefreshController<ConversationModel> {
  final UserService userService = Get.find();

  @override
  Future<GroupResult<ConversationModel>> getNewData(int currentPage) {
    return userService.getConversations(currentPage).then((value) {
      if (value.success) {
        return value.data!;
      } else {
        throw Exception(value.message);
      }
    });
  }
}
