import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/app_locale.dart';
import '../../../../core/services/session_user.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/friendly_error.dart';
import '../../../../core/widgets/app_status.dart';
import '../../../../core/widgets/brand_icons.dart';
import '../../../../core/widgets/count_badge.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../../notifications/application/providers/notification_provider.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../post/presentation/screens/create_post_screen.dart';
import '../../../social/foryou_feed.dart';
import '../../../social/reels_screen.dart';
import '../../../social/stories.dart';
import '../../../social/trending_screens.dart';
import '../../../live/live_screens.dart';
import '../../../sponsored/sponsored.dart';
import '../../application/providers/feed_provider.dart';
import '../widgets/post_card.dart';

/// Moments: stories on top, then "For you" (AI ranked) or "Friends" (latest).
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _storiesA = GlobalKey<StoriesBarState>();
  final _storiesB = GlobalKey<StoriesBarState>();

  @override
  Widget build(BuildContext context) {
    final meId = ref.watch(authProvider).user?.id ?? SessionUser.id;
    final unread = ref.watch(unreadNotificationCountProvider);

    Future<void> create() async {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostScreen()));
      ref.read(feedProvider.notifier).refresh();
    }

    Widget stories(GlobalKey<StoriesBarState> key, {bool sponsored = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(children: [
            StoriesBar(key: key, meId: meId, myName: SessionUser.name, myImage: SessionUser.profileImage),
            if (sponsored) const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: SponsoredStrip()),
          ]),
        );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          surfaceTintColor: AppColors.surface,
          titleSpacing: 18,
          title: Text(tr("Moments"), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.5)),
          actions: [
            IconButton(
              tooltip: tr("Reels"),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReelsScreen(meId: meId))),
              icon: const Icon(Icons.slow_motion_video_rounded, size: 27),
            ),
            IconButton(
              tooltip: tr("Live"),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveListScreen())),
              icon: const Icon(Icons.sensors_rounded, size: 26),
            ),
            IconButton(
              tooltip: tr("Trending"),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrendingScreen(meId: meId))),
              icon: const Icon(Icons.tag_rounded, size: 26),
            ),
            IconButton(tooltip: tr("New post"), onPressed: create, icon: const Icon(Icons.add_box_outlined, size: 27)),
            IconButton(
              tooltip: tr("Updates"),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
              icon: CountBadge(count: unread, child: const Icon(Icons.favorite_border_rounded, size: 27)),
            ),
            const SizedBox(width: 6),
          ],
          bottom: TabBar(
            labelColor: AppColors.ink,
            unselectedLabelColor: AppColors.subtitle,
            indicatorColor: AppColors.joy,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            tabs: [Tab(text: tr("For you")), Tab(text: tr("Friends"))],
          ),
        ),
        body: TabBarView(children: [
          ForYouFeed(meId: meId, header: stories(_storiesA, sponsored: true)),
          _FriendsFeed(meId: meId, header: stories(_storiesB), onCreate: create),
        ]),
      ),
    );
  }
}

class _FriendsFeed extends ConsumerWidget {
  final String meId;
  final Widget header;
  final VoidCallback onCreate;
  const _FriendsFeed({required this.meId, required this.header, required this.onCreate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider);
    return feed.when(
      data: (page) {
        final posts = page.posts;
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => ref.read(feedProvider.notifier).refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: posts.length + 1 + (page.hasMore ? 1 : 0) + (posts.isEmpty ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == 0) return header;
              if (posts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: AppEmptyState(
                    icon: BrandGlyph.post,
                    title: tr("No posts yet"),
                    message: tr("Share your first eco moment. Points land after a friend verifies it."),
                    actionLabel: tr("Share a moment"),
                    onAction: onCreate,
                  ),
                );
              }
              final i = index - 1;
              if (i >= posts.length) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: OutlinedButton(onPressed: () => ref.read(feedProvider.notifier).loadMore(), child: Text(tr("Load more"))),
                );
              }
              return PostCard(key: ValueKey(posts[i].id), post: posts[i], meId: meId);
            },
          ),
        );
      },
      loading: () => const AppLoading(),
      error: (e, _) => AppErrorState(message: friendlyError(e, fallback: "Could not load moments."), onRetry: () => ref.invalidate(feedProvider)),
    );
  }
}
