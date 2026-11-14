import 'package:flutter/material.dart';

import '../../../../data/models/account/conversations/message.dart';
import '../../../../utils/display_util.dart';
import '../../../../components/network_image.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool showUser;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.showUser,
  });

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    Widget bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isMe ? colorScheme.primary : colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            message.body,
            style: TextStyle(
              color: isMe ? colorScheme.onPrimary : colorScheme.onSurface,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            DisplayUtil.getDisplayTime(DateTime.parse(message.createdAt)),
            style: TextStyle(
              color: isMe
                  ? colorScheme.onPrimary.withAlpha(160)
                  : colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );

    if (isMe) {
      return Container(
        margin: const EdgeInsets.only(left: 48, top: 4, bottom: 4, right: 12),
        alignment: Alignment.centerRight,
        child: bubble,
      );
    }

    return Container(
      margin: const EdgeInsets.only(left: 12, top: 4, bottom: 4, right: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            children: [
              if (showUser)
                ClipOval(
                  child: NetworkImg(
                    imageUrl: message.user.avatarUrl,
                    width: 32,
                    height: 32,
                  ),
                )
              else
                const SizedBox(width: 32, height: 8),
            ],
          ),
          const SizedBox(width: 8),
          Flexible(child: bubble),
        ],
      ),
    );
  }
}
