import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/utils/chat_launcher.dart';
import '../../application/providers/friend_provider.dart';
import '../../domain/models/friend_model.dart';

class FriendProfileScreen extends ConsumerWidget {
  final FriendModel friend;

  const FriendProfileScreen({
    super.key,
    required this.friend,
  });

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String body,
    required Future<void> Function() action,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(title),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await action();
    ref.invalidate(friendsProvider);
    ref.invalidate(requestsProvider);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(friend.name, style: AppTextStyles.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            UserAvatar(
              imageUrl: friend.profileImage,
              radius: 55,
              semanticLabel: "${friend.name} photo",
            ),
            const SizedBox(height: 20),
            Text(
              friend.name,
              style: AppTextStyles.title.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 8),
            if (friend.bio.isNotEmpty) Text(friend.bio, textAlign: TextAlign.center, style: AppTextStyles.subtitle),
            const SizedBox(height: 20),
            Row(children: [
              _ProfileAction(
                icon: Icons.chat_bubble_rounded,
                label: "Message",
                primary: true,
                onTap: () => openChat(context, userId: friend.id, name: friend.name, profileImage: friend.profileImage),
              ),
              const SizedBox(width: 10),
              _ProfileAction(
                icon: Icons.call_rounded,
                label: "Call",
                onTap: () => startCall(context, userId: friend.id, name: friend.name, video: false),
              ),
              const SizedBox(width: 10),
              _ProfileAction(
                icon: Icons.videocam_rounded,
                label: "Video",
                onTap: () => startCall(context, userId: friend.id, name: friend.name, video: true),
              ),
            ]),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.monetization_on_rounded, color: AppColors.accent),
                      title: const Text("Eco Points"),
                      trailing: Text(friend.ecoPoints.toString()),
                    ),
                    ListTile(
                      leading: const Icon(Icons.star),
                      title: const Text("Level"),
                      trailing: Text(friend.level.toString()),
                    ),
                    ListTile(
                      leading: const Icon(Icons.local_fire_department),
                      title: const Text("Streak"),
                      trailing: Text(friend.streak.toString()),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _confirm(
                  context,
                  ref,
                  title: "Unfriend",
                  body: "Remove ${friend.name} from your friends?",
                  action: () =>
                      ref.read(friendRepositoryProvider).unfriend(friend.id),
                ),
                child: const Text("Unfriend"),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                ),
                onPressed: () => _confirm(
                  context,
                  ref,
                  title: "Block",
                  body: "Block ${friend.name}? They won't be able to send requests.",
                  action: () =>
                      ref.read(friendRepositoryProvider).blockUser(friend.id),
                ),
                child: const Text("Block"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;
  const _ProfileAction({required this.icon, required this.label, required this.onTap, this.primary = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: primary ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: primary ? null : Border.all(color: AppColors.border),
            ),
            child: Column(children: [
              Icon(icon, color: primary ? Colors.white : AppColors.primary),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: primary ? Colors.white : AppColors.ink)),
            ]),
          ),
        ),
      ),
    );
  }
}
