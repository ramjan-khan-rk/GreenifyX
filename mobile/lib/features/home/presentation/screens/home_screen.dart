import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/app_status.dart';
import '../../../challenge/presentation/screens/challenge_screen.dart';
import '../../../challenge/presentation/screens/create_challenge_screen.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../profile/application/providers/my_profile_provider.dart';
import '../widgets/eco_points_card.dart';
import '../widgets/quote_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);

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
                      CircleAvatar(
                        radius: 28,
                        backgroundImage: user.profileImage.isNotEmpty
                            ? NetworkImage(
                                resolveMediaUrl(user.profileImage) ?? "",
                              )
                            : null,
                        child: user.profileImage.isEmpty
                            ? const Icon(Icons.person)
                            : null,
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
                        icon: const Icon(Icons.notifications_none_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  EcoPointsCard(
                    ecoPoints: user.ecoPoints,
                    level: user.level,
                    streak: user.streak,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.flag_outlined),
                      label: const Text("Open challenges"),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChallengeScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text("Start a new challenge"),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateChallengeScreen(),
                          ),
                        );
                      },
                    ),
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
