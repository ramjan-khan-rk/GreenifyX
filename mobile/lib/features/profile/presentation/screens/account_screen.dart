import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_status.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../chat/application/providers/chats_provider.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../../friends/application/providers/friend_provider.dart';
import '../../../friends/presentation/screens/friends_screen.dart';
import '../../../home/presentation/screens/leaderboard_screen.dart';
import '../../../home/presentation/widgets/eco_points_card.dart';
import '../../application/providers/my_profile_provider.dart';
import '../../application/providers/profile_provider.dart';
import 'complete_profile_screen.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Profile", style: AppTextStyles.title),
      ),
      body: profile.when(
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
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Center(
                  child: UserAvatar(
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
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text("Edit profile"),
                  subtitle: const Text("Name, photo, and bio"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CompleteProfileScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.people_outline),
                  title: const Text("Friends"),
                  subtitle: Text("${user.friendsCount} connections"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FriendsScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.emoji_events_outlined),
                  title: const Text("Leaderboard"),
                  subtitle: const Text("Verified Eco Points ranking"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LeaderboardScreen(),
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
