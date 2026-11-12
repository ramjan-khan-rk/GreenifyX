import 'package:flutter/material.dart';
import 'package:greenifyx/core/i18n/app_locale.dart';

class ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const ChatInput({
    super.key,
    required this.controller,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: tr("Type message..."),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: onSend,
          )
        ],
      ),
    );
  }
}