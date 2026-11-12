import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/chat_launcher.dart';
import '../../../../core/utils/friendly_error.dart';
import '../../../../core/widgets/app_status.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../friends/application/providers/friend_provider.dart';
import '../../application/providers/chats_provider.dart';
import '../../domain/models/chat_model.dart';
import 'package:greenifyx/core/i18n/app_locale.dart';

String _when(DateTime t) {
  final now = DateTime.now();
  if (t.year == now.year && t.month == now.month && t.day == now.day) return DateFormat("h:mm a").format(t);
  final y = now.subtract(const Duration(days: 1));
  if (t.year == y.year && t.month == y.month && t.day == y.day) return "Yesterday";
  if (now.difference(t).inDays < 7) return DateFormat("EEE").format(t);
  return DateFormat("d MMM").format(t);
}

class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  String _q = "";

  @override
  Widget build(BuildContext context) {
    final chats = ref.watch(chatsProvider);
    final friends = ref.watch(friendsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr("Messages"), style: AppTextStyles.title),
          Text(tr("Chat, voice notes and calls with friends"), style: AppTextStyles.tagline),
        ]),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: tr("New message"),
        onPressed: () => _pickFriend(context),
        child: const Icon(Icons.edit_rounded),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(chatsProvider);
          ref.invalidate(friendsProvider);
        },
        child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: tr("Search"),
                prefixIcon: Icon(Icons.search_rounded),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          friends.maybeWhen(
            data: (list) => list.isEmpty
                ? const SizedBox.shrink()
                : SizedBox(
                    height: 96,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (final f in list)
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => openChat(context, userId: f.id, name: f.name, profileImage: f.profileImage),
                            child: SizedBox(
                              width: 72,
                              child: Column(children: [
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(colors: [AppColors.joy, AppColors.sun]),
                                  ),
                                  child: CircleAvatar(
                                    radius: 26,
                                    backgroundColor: Colors.white,
                                    child: UserAvatar(imageUrl: f.profileImage, radius: 24),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(f.name.split(" ").first,
                                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ]),
                            ),
                          ),
                      ],
                    ),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          chats.when(
            loading: () => const Padding(padding: EdgeInsets.all(40), child: AppLoading()),
            error: (e, _) => AppErrorState(message: friendlyError(e), onRetry: () => ref.invalidate(chatsProvider)),
            data: (list) {
              final shown = _q.isEmpty ? list : list.where((c) => c.userName.toLowerCase().contains(_q)).toList();
              if (shown.isEmpty) {
                return Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: AppEmptyState(
                    icon: Icons.chat_bubble_rounded,
                    title: tr("No conversations yet"),
                    message: tr("Tap a friend above or the pencil button to start chatting."),
                  ),
                );
              }
              return Column(children: [for (final c in shown) _ChatRow(chat: c)]);
            },
          ),
        ]),
      ),
    );
  }

  void _pickFriend(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => Consumer(builder: (context, ref, _) {
        final friends = ref.watch(friendsProvider);
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.6,
            child: friends.when(
              loading: () => const AppLoading(),
              error: (e, _) => Center(child: Text(friendlyError(e))),
              data: (list) => list.isEmpty
                  ? AppEmptyState(icon: Icons.group_add_rounded, title: tr("No friends yet"), message: tr("Add friends to start chatting."))
                  : ListView(children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: Text(tr("New message"), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      ),
                      for (final f in list)
                        ListTile(
                          leading: UserAvatar(imageUrl: f.profileImage),
                          title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                              tooltip: tr("Voice call"),
                              icon: const Icon(Icons.call_rounded, color: AppColors.eco),
                              onPressed: () {
                                Navigator.pop(context);
                                startCall(context, userId: f.id, name: f.name, video: false);
                              },
                            ),
                            IconButton(
                              tooltip: tr("Video call"),
                              icon: const Icon(Icons.videocam_rounded, color: AppColors.eco),
                              onPressed: () {
                                Navigator.pop(context);
                                startCall(context, userId: f.id, name: f.name, video: true);
                              },
                            ),
                          ]),
                          onTap: () {
                            Navigator.pop(context);
                            openChat(context, userId: f.id, name: f.name, profileImage: f.profileImage);
                          },
                        ),
                    ]),
            ),
          ),
        );
      }),
    );
  }
}

class _ChatRow extends ConsumerWidget {
  final ChatModel chat;
  const _ChatRow({required this.chat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () async {
        await openChat(context, userId: chat.userId, name: chat.userName, profileImage: chat.profileImage);
        ref.invalidate(chatsProvider);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          UserAvatar(imageUrl: chat.profileImage, name: chat.userName, radius: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(chat.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: chat.unread ? FontWeight.w800 : FontWeight.w700, fontSize: 16, color: AppColors.ink)),
                ),
                Text(_when(chat.time),
                    style: TextStyle(
                        fontSize: 12,
                        color: chat.unread ? AppColors.primary : AppColors.subtitle,
                        fontWeight: chat.unread ? FontWeight.w800 : FontWeight.w500)),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                Expanded(
                  child: Text(
                    "${chat.lastFromMe ? "You: " : ""}${chat.lastMessage.isEmpty ? "Say hello" : chat.lastMessage}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: chat.unread ? AppColors.ink : AppColors.subtitle,
                      fontWeight: chat.unread ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
                if (chat.unread)
                  Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
              ]),
            ]),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: "Call ${chat.userName}",
            icon: const Icon(Icons.call_rounded, color: AppColors.eco),
            onPressed: () => startCall(context, userId: chat.userId, name: chat.userName, video: false),
          ),
        ]),
      ),
    );
  }
}
