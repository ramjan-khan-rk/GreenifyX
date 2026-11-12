import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_status.dart';
import '../../../../core/widgets/brand_icons.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../application/providers/friend_provider.dart';
import 'friend_profile_screen.dart';
import 'search_friends_screen.dart';
import '../../../../core/utils/chat_launcher.dart';

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsProvider);
    final requests = ref.watch(requestsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Friends", style: AppTextStyles.title),
            Text("Connect & Grow", style: AppTextStyles.tagline),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Find friends",
            icon: const Icon(BrandGlyph.friends, color: AppColors.primary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SearchFriendsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(friendsProvider);
          ref.invalidate(requestsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text("Requests", style: AppTextStyles.title.copyWith(fontSize: 18)),
            ),
            requests.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: AppLoading(),
              ),
              error: (e, s) => const Padding(
                padding: EdgeInsets.all(16),
                child: Text("Couldn't load requests. Pull to retry."),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      "No pending requests. Find people with the add icon.",
                    ),
                  );
                }

                return Column(
                  children: list
                      .map(
                        (user) => ListTile(
                          leading: UserAvatar(
                            imageUrl: user.profileImage,
                            semanticLabel: "${user.name} photo",
                          ),
                          title: Text(user.name),
                          trailing: SizedBox(
                            width: 168,
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 36),
                                      padding: EdgeInsets.zero,
                                    ),
                                    onPressed: () async {
                                      await ref
                                          .read(friendRepositoryProvider)
                                          .rejectRequest(user.id);
                                      ref.invalidate(friendsProvider);
                                      ref.invalidate(requestsProvider);
                                    },
                                    child: const Text("Decline"),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: const Size(0, 36),
                                      padding: EdgeInsets.zero,
                                    ),
                                    onPressed: () async {
                                      await ref
                                          .read(friendRepositoryProvider)
                                          .acceptRequest(user.id);
                                      ref.invalidate(friendsProvider);
                                      ref.invalidate(requestsProvider);
                                    },
                                    child: const Text("Accept"),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text("My friends", style: AppTextStyles.title.copyWith(fontSize: 18)),
            ),
            friends.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: AppLoading(),
              ),
              error: (e, s) => const Padding(
                padding: EdgeInsets.all(16),
                child: Text("Couldn't load friends. Pull to retry."),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      "No friends yet. Search and send a request to get started.",
                    ),
                  );
                }

                return Column(
                  children: list
                      .map(
                        (friend) => ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: UserAvatar(
                            imageUrl: friend.profileImage,
                            radius: 24,
                            semanticLabel: "${friend.name} photo",
                          ),
                          title: Text(friend.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text("Level ${friend.level} · ${friend.ecoPoints} Eco Points"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _RoundAction(
                                icon: Icons.chat_bubble_rounded,
                                tooltip: "Message",
                                onTap: () => openChat(context, userId: friend.id, name: friend.name, profileImage: friend.profileImage),
                              ),
                              _RoundAction(
                                icon: Icons.call_rounded,
                                tooltip: "Voice call",
                                onTap: () => startCall(context, userId: friend.id, name: friend.name, video: false),
                              ),
                              _RoundAction(
                                icon: Icons.videocam_rounded,
                                tooltip: "Video call",
                                onTap: () => startCall(context, userId: friend.id, name: friend.name, video: true),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FriendProfileScreen(friend: friend),
                              ),
                            );
                          },
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _RoundAction({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: IconButton.filledTonal(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(backgroundColor: AppColors.primary.withValues(alpha: 0.1), foregroundColor: AppColors.primary),
        onPressed: onTap,
        icon: Icon(icon, size: 20),
      ),
    );
  }
}
