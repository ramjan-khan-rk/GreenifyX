import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_status.dart';
import '../../application/providers/chats_provider.dart';
import 'chat_screen.dart';

class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(chatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Chat", style: AppTextStyles.title),
      ),
      body: chats.when(
        loading: () => const AppLoading(),
        error: (e, _) => AppErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(chatsProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const AppEmptyState(
              icon: Icons.chat_bubble_outline,
              title: "No conversations yet",
              message: "Open a friend profile and start a chat.",
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(chatsProvider),
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, index) {
                final chat = list[index];

                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  title: Text(chat.userName),
                  subtitle: Text(chat.lastMessage),
                  trailing: chat.unread
                      ? const Icon(
                          Icons.mark_chat_unread,
                          color: AppColors.primary,
                        )
                      : null,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          userId: chat.userId,
                          userName: chat.userName,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
