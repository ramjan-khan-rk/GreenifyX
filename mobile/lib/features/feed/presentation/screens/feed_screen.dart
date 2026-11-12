import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/app_locale.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/friendly_error.dart';
import '../../../../core/widgets/app_status.dart';
import '../../../../core/widgets/brand_icons.dart';
import '../../../../core/widgets/count_badge.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../../notifications/application/providers/notification_provider.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../post/presentation/screens/create_post_screen.dart';
import '../../application/providers/feed_provider.dart';
import '../widgets/post_card.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider);
    final meId = ref.watch(authProvider).user?.id ?? "";
    final unread = ref.watch(unreadNotificationCountProvider);

    Future<void> create() async {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostScreen()));
      ref.read(feedProvider.notifier).refresh();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4EFEA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 18,
        title: Text(tr("Moments"), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.5)),
        actions: [
          IconButton(
            tooltip: tr("New post"),
            onPressed: create,
            icon: const Icon(Icons.add_box_outlined, size: 27),
          ),
          IconButton(
            tooltip: tr("Updates"),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
            icon: CountBadge(count: unread, child: const Icon(Icons.favorite_border_rounded, size: 27)),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: feed.when(
        data: (page) {
          final posts = page.posts;
          if (posts.isEmpty) {
            return AppEmptyState(
              icon: BrandGlyph.post,
              title: tr("No posts yet"),
              message: tr("Share your first eco moment. Points land after a friend verifies it."),
              actionLabel: tr("Share a moment"),
              onAction: create,
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => ref.read(feedProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              itemCount: posts.length + (page.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= posts.length) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: OutlinedButton(
                      onPressed: () => ref.read(feedProvider.notifier).loadMore(),
                      child: Text(tr("Load more")),
                    ),
                  );
                }
                return PostCard(key: ValueKey(posts[index].id), post: posts[index], meId: meId);
              },
            ),
          );
        },
        loading: () => const AppLoading(),
        error: (e, _) => AppErrorState(
          message: friendlyError(e, fallback: "Could not load moments."),
          onRetry: () => ref.invalidate(feedProvider),
        ),
      ),
    );
  }
}
