import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_status.dart';
import '../../../../core/widgets/count_badge.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../notifications/application/providers/notification_provider.dart';
import '../../../challenge/presentation/screens/challenge_screen.dart';
import '../../../challenge/presentation/screens/create_challenge_screen.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../profile/application/providers/my_profile_provider.dart';
import '../widgets/eco_points_card.dart';
import '../widgets/quote_card.dart';
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                children: [
                  Row(
                    children: [
                      UserAvatar(
                        imageUrl: user.profileImage,
                        radius: 28,
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
                              style: AppTextStyles.title.copyWith(fontSize: 22),
                            ),
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
                          child: const Icon(Icons.notifications_none_outlined),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  EcoPointsCard(
                    ecoPoints: user.ecoPoints,
                    level: user.level,
                    streak: user.streak,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      "Community-verified Eco Points. English UI for this UAE pilot. Arabic and RTL are not included yet — they would need mirrored layouts, not a language toggle.",
                      style: AppTextStyles.subtitle.copyWith(height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text("Jump in", style: AppTextStyles.title.copyWith(fontSize: 18)),
                  const SizedBox(height: 10),
                  _HomeAction(
                    icon: Icons.emoji_events_outlined,
                    title: "Leaderboard",
                    subtitle: "See who leads in verified Eco Points",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LeaderboardScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _HomeAction(
                    icon: Icons.flag_outlined,
                    title: "Open challenges",
                    subtitle: "Compete with friends on shared goals",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ChallengeScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _HomeAction(
                    icon: Icons.add_circle_outline,
                    title: "Start a new challenge",
                    subtitle: "Invite a friend and earn Eco Points",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateChallengeScreen(),
                        ),
                      );
                    },
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

class _HomeAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HomeAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: AppTextStyles.body),
        subtitle: Text(subtitle, style: AppTextStyles.subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
