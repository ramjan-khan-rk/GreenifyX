import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_status.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../application/providers/leaderboard_provider.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(leaderboardProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Leaderboard", style: AppTextStyles.title),
      ),
      body: board.when(
        loading: () => const AppLoading(),
        error: (e, _) => AppErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(leaderboardProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const AppEmptyState(
              icon: Icons.emoji_events_outlined,
              title: "No rankings yet",
              message:
                  "Verified Eco Points will show here once friends confirm activities.",
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(leaderboardProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = list[index];
                final rank = index + 1;
                return Semantics(
                  label:
                      "Rank $rank, ${entry.name}, ${entry.ecoPoints} Eco Points",
                  child: ListTile(
                    tileColor: AppColors.card,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      child: Text(
                        "$rank",
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        UserAvatar(
                          imageUrl: entry.profileImage,
                          radius: 18,
                          semanticLabel: "${entry.name} photo",
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(entry.name, style: AppTextStyles.body),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(left: 46, top: 4),
                      child: Text(
                        "Level ${entry.level} · streak ${entry.streak}",
                        style: AppTextStyles.subtitle,
                      ),
                    ),
                    trailing: Text(
                      "${entry.ecoPoints}",
                      style: AppTextStyles.title.copyWith(fontSize: 18),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
