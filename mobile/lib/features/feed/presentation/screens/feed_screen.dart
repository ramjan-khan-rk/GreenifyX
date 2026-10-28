import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/app_status.dart';
import '../../../../core/widgets/count_badge.dart';
import '../../../../core/widgets/points_status_chip.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../../comment/presentation/widgets/comment_bottom_sheet.dart';
import '../../../notifications/application/providers/notification_provider.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../profile/application/providers/my_profile_provider.dart';
import '../../application/providers/feed_provider.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider);
    final meId = ref.watch(authProvider).user?.id ?? "";
    final unread = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Explore", style: AppTextStyles.title),
        actions: [
          IconButton(
            tooltip: "Updates",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationsScreen(),
                ),
              );
            },
            icon: CountBadge(
              count: unread,
              child: const Icon(Icons.notifications_none_outlined),
            ),
          ),
        ],
      ),
      body: feed.when(
        data: (page) {
          final posts = page.posts;
          if (posts.isEmpty) {
            return const AppEmptyState(
              icon: Icons.public_outlined,
              title: "No posts yet",
              message:
                  "Share a green action from the + button. Eco Points land after a friend verifies it.",
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => ref.read(feedProvider.notifier).refresh(),
            child: ListView.builder(
              itemCount: posts.length + (page.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= posts.length) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: TextButton(
                      onPressed: () =>
                          ref.read(feedProvider.notifier).loadMore(),
                      child: const Text("Load more"),
                    ),
                  );
                }
                final post = posts[index];

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: UserAvatar(
                          imageUrl: post.profileImage,
                          semanticLabel: "${post.name} photo",
                        ),
                        title: Text(post.name, style: AppTextStyles.body),
                        subtitle: Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            post.activity,
                            style: AppTextStyles.subtitle.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: resolveMediaUrl(post.image) ?? "",
                          width: double.infinity,
                          height: 280,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Container(
                            height: 280,
                            color: AppColors.border,
                          ),
                          errorWidget: (_, _, _) => Container(
                            height: 280,
                            alignment: Alignment.center,
                            color: AppColors.border,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                      if (post.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(post.description, style: AppTextStyles.body),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: PointsStatusChip(
                          ecoPoints: post.ecoPoints,
                          isVerified: post.isVerified,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OverflowBar(
                        alignment: MainAxisAlignment.start,
                        children: [
                          TextButton.icon(
                            onPressed: () async {
                              try {
                                await ref
                                    .read(feedRepositoryProvider)
                                    .toggleLike(post.id);
                                await ref.read(feedProvider.notifier).refresh();
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString())),
                                  );
                                }
                              }
                            },
                            icon: Icon(
                              post.isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: post.isLiked ? AppColors.error : null,
                            ),
                            label: Text("${post.likes}"),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) => CommentBottomSheet(
                                  postId: post.id,
                                ),
                              );
                            },
                            icon: const Icon(Icons.comment_outlined),
                            label: Text("${post.comments}"),
                          ),
                          if (!post.isVerified &&
                              post.userId.isNotEmpty &&
                              post.userId != meId)
                            TextButton.icon(
                              onPressed: () async {
                                try {
                                  await ref
                                      .read(feedRepositoryProvider)
                                      .verifyPost(post.id);
                                  await ref.read(feedProvider.notifier).refresh();
                                  ref.invalidate(myProfileProvider);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Verified. Eco Points awarded to your friend.",
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(e.toString())),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.verified_outlined),
                              label: const Text("Verify"),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
        loading: () => const AppLoading(),
        error: (e, _) => AppErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(feedProvider),
        ),
      ),
    );
  }
}
