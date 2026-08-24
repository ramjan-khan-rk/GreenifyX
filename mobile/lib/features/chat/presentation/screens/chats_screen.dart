import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/chats_provider.dart';
import 'chat_screen.dart';

class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(chatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Chats"),
      ),
      body: chats.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),

        error: (e, s) => Center(
          child: Text(e.toString()),
        ),

        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text("No chats yet"),
            );
          }

          return ListView.builder(
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
                        color: Colors.green,
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
          );
        },
      ),
    );
  }
}