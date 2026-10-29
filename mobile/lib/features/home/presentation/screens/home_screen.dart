import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_status.dart';
import '../../../../core/widgets/brand_icons.dart';
import '../../../../core/widgets/count_badge.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../chat/presentation/screens/chats_screen.dart';
import '../../../feed/presentation/screens/feed_screen.dart';
import '../../../friends/presentation/screens/friends_screen.dart';
import '../../../notifications/application/providers/notification_provider.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../post/presentation/screens/create_post_screen.dart';
import '../../../profile/application/providers/my_profile_provider.dart';
import '../../../profile/presentation/screens/complete_profile_screen.dart';
import '../widgets/eco_points_card.dart';
import '../widgets/quote_card.dart';
import '../../../challenge/presentation/screens/challenge_screen.dart';
import 'leaderboard_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);
    final unread = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: profile.when(
          loading: () => const AppLoading(),
          error: (e, _) => AppErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(myProfileProvider),
          ),
          data: (user) {
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => ref.invalidate(myProfileProvider),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  Row(
                    children: [
                      const BrandMark(size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              BrandCopy.name,
                              style: AppTextStyles.title.copyWith(fontSize: 22),
                            ),
                            Text(BrandCopy.tagline, style: AppTextStyles.tagline),
                          ],
                        ),
                      ),
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
                          child: const Icon(
                            BrandGlyph.updates,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      UserAvatar(
                        imageUrl: user.profileImage,
                        radius: 26,
                        semanticLabel: "${user.name} photo",
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Welcome back", style: AppTextStyles.subtitle),
                            Text(
                              user.name.isEmpty ? "GreenifyX member" : user.name,
                              style: AppTextStyles.title.copyWith(fontSize: 20),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  EcoPointsCard(
                    ecoPoints: user.ecoPoints,
                    level: user.level,
                    streak: user.streak,
                  ),
                  const SizedBox(height: 20),
                  Text("Your journey", style: AppTextStyles.title.copyWith(fontSize: 18)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 188,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        BrandJourneyCard(
                          title: "Take Action",
                          body:
                              "Plant trees, recycle, save water and make a difference — every day.",
                          icon: BrandGlyph.recycle,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CreatePostScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        BrandJourneyCard(
                          title: "Earn Eco Points",
                          body:
                              "Complete verified actions and earn Eco Points. Be a greener hero!",
                          icon: BrandGlyph.ecoPoints,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FeedScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        BrandJourneyCard(
                          title: "Connect & Grow",
                          body:
                              "Make friends, join challenges and climb the leaderboard together.",
                          icon: BrandGlyph.friends,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FriendsScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text("Quick actions", style: AppTextStyles.title.copyWith(fontSize: 18)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 12,
                    children: [
                      BrandIconBadge(
                        icon: BrandGlyph.post,
                        label: "Post",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CreatePostScreen(),
                            ),
                          );
                        },
                      ),
                      BrandIconBadge(
                        icon: BrandGlyph.verified,
                        label: "Verified",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FeedScreen(),
                            ),
                          );
                        },
                      ),
                      BrandIconBadge(
                        icon: BrandGlyph.ecoPoints,
                        label: "Eco Points",
                        color: AppColors.accent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LeaderboardScreen(),
                            ),
                          );
                        },
                      ),
                      BrandIconBadge(
                        icon: BrandGlyph.recycle,
                        label: "Recycle",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ChallengeScreen(),
                            ),
                          );
                        },
                      ),
                      BrandIconBadge(
                        icon: BrandGlyph.settings,
                        label: "Settings",
                        color: AppColors.navy,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CompleteProfileScreen(),
                            ),
                          );
                        },
                      ),
                      BrandIconBadge(
                        icon: BrandGlyph.chat,
                        label: "Chat",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ChatsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const QuoteCard(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
