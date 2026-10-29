import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: isMe ? null : Border.all(color: AppColors.border),
        ),
        child: Text(
          text,
          style: AppTextStyles.body.copyWith(
            color: isMe ? Colors.white : AppColors.text,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
