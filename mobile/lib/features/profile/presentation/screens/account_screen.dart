import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_status.dart';
import '../../../../core/widgets/brand_icons.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../../chat/application/providers/chats_provider.dart';
import '../../../chat/presentation/screens/chats_screen.dart';
import '../../../feed/presentation/screens/feed_screen.dart';
import '../../../friends/application/providers/friend_provider.dart';
import '../../../friends/presentation/screens/friends_screen.dart';
import '../../../home/presentation/screens/leaderboard_screen.dart';
import '../../../home/presentation/widgets/eco_points_card.dart';
import '../../application/providers/my_profile_provider.dart';
import '../../application/providers/profile_provider.dart';
import 'edit_profile_screen.dart';
import '../../../campaign/presentation/screens/points_history_screen.dart';
import '../../../campaign/presentation/screens/verifier_home_screen.dart';
import '../../../challenge/presentation/screens/challenge_screen.dart';
import '../../../issues/presentation/issues_hub_screen.dart';
import '../../../map/eco_map_screen.dart';
import '../../../orgs/teams_screen.dart';
import '../../../../core/utils/friendly_error.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Profile", style: AppTextStyles.title),
            Text(BrandCopy.tagline, style: AppTextStyles.tagline),
          ],
        ),
      ),
      body: profile.when(
        loading: () => const AppLoading(),
        error: (e, _) => AppErrorState(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(myProfileProvider),
        ),
        data: (user) {
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(myProfileProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Center(
                  child: UserAvatar(
                    name: user.name,
                    imageUrl: user.profileImage,
                    radius: 52,
                    semanticLabel: "${user.name} photo",
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    user.name.isEmpty ? "Complete your profile" : user.name,
                    style: AppTextStyles.title.copyWith(fontSize: 24),
                  ),
                ),
                if (user.email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Center(child: Text(user.email, style: AppTextStyles.subtitle)),
                ],
                if (user.emirate.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(user.emirate, style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
                if (user.bio.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Center(child: Text(user.bio, style: AppTextStyles.body)),
                ],
                const SizedBox(height: 20),
                EcoPointsCard(
                  ecoPoints: user.ecoPoints,
                  level: user.level,
                  streak: user.streak,
                ),
                if (user.badges.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: user.badges
                        .map(
                          (badge) => Chip(
                            label: Text(_badgeLabel(badge)),
                            backgroundColor:
                                AppColors.mint.withValues(alpha: 0.7),
                            side: const BorderSide(color: AppColors.border),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 8),
                if (user.role == "verifier" || user.role == "admin")
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: AppColors.eco,
                    child: ListTile(
                      leading: const Icon(Icons.verified_user_rounded, color: Colors.white),
                      title: const Text(
                        "Field verification",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        "Your assignments and on-site reports",
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const VerifierHomeScreen()),
                        );
                      },
                    ),
                  ),
                _ProfileLink(
                  icon: Icons.stars_rounded,
                  title: "Eco Points",
                  subtitle: "Balance and full history",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PointsHistoryScreen()),
                    );
                  },
                ),
                _ProfileLink(
                  icon: Icons.groups_rounded,
                  title: "Teams",
                  subtitle: "Your company, school or community impact",
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const TeamsScreen()));
                  },
                ),
                _ProfileLink(
                  icon: Icons.map_rounded,
                  title: "Smart Eco Map",
                  subtitle: "Campaigns, recycling and refill points near you",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EcoMapScreen()),
                    );
                  },
                ),
                _ProfileLink(
                  icon: Icons.report_gmailerrorred_rounded,
                  title: "My environmental reports",
                  subtitle: "Track what you reported",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const IssuesHubScreen()),
                    );
                  },
                ),
                _ProfileLink(
                  icon: BrandGlyph.challenges,
                  title: "Challenges",
                  subtitle: "Friendly eco challenges",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChallengeScreen()),
                    );
                  },
                ),
                _ProfileLink(
                  icon: BrandGlyph.settings,
                  title: "Settings",
                  subtitle: "Name, photo, bio and emirate",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    );
                  },
                ),
                _ProfileLink(
                  icon: BrandGlyph.friends,
                  title: "Friends",
                  subtitle: "${user.friendsCount} connections",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FriendsScreen(),
                      ),
                    );
                  },
                ),
                _ProfileLink(
                  icon: BrandGlyph.leaderboard,
                  title: "Leaderboard",
                  subtitle: "Verified Eco Points ranking",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LeaderboardScreen(),
                      ),
                    );
                  },
                ),
                _ProfileLink(
                  icon: BrandGlyph.post,
                  title: "Posts",
                  subtitle: "Community feed and verify",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FeedScreen(),
                      ),
                    );
                  },
                ),
                _ProfileLink(
                  icon: BrandGlyph.chat,
                  title: "Chat",
                  subtitle: "Friends-only messages",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChatsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: Color(0xFFFFCDD2)),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () async {
                      await ref.read(profileProvider.notifier).logout();
                      await ref.read(authProvider.notifier).logout();
                      ref.invalidate(myProfileProvider);
                      ref.invalidate(friendsProvider);
                      ref.invalidate(requestsProvider);
                      ref.invalidate(chatsProvider);
                      if (context.mounted) {
                        context.go(AppRoutes.login);
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text("Log out"),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileLink extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: AppTextStyles.body),
        subtitle: Text(subtitle, style: AppTextStyles.subtitle),
        trailing: const Icon(Icons.chevron_right, color: AppColors.navy),
        onTap: onTap,
      ),
    );
  }
}

String _badgeLabel(String badge) {
  switch (badge) {
    case "first_verified":
      return "First verified";
    case "century":
      return "100 Eco Points";
    case "streak_3":
      return "3-day streak";
    case "week_streak":
      return "7-day streak";
    default:
      return badge;
  }
}
