import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../application/providers/challenge_provider.dart';
import '../../domain/models/challenge_model.dart';

class ChallengeCard extends ConsumerWidget {
  final ChallengeModel challenge;

  const ChallengeCard({
    super.key,
    required this.challenge,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.title,
                      style: AppTextStyles.title.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      challenge.activity,
                      style: AppTextStyles.subtitle,
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: challenge.status),
            ],
          ),
          if (challenge.description.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              challenge.description,
              style: AppTextStyles.body.copyWith(
                fontSize: 14,
                height: 1.4,
                color: AppColors.subtitle,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(
                icon: Icons.category_outlined,
                label: challenge.category,
              ),
              _MetaChip(
                icon: Icons.bolt_outlined,
                label: challenge.difficulty,
              ),
              _MetaChip(
                icon: Icons.schedule_outlined,
                label: challenge.remainingDays == 0
                    ? "Due today"
                    : "${challenge.remainingDays}d left",
              ),
              _MetaChip(
                icon: Icons.eco_outlined,
                label: "+${challenge.ecoReward} Eco Points",
                emphasize: true,
              ),
              const _MetaChip(
                icon: Icons.info_outline,
                label: "Self-reported (no evidence yet)",
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ProgressBlock(
            label: challenge.creatorName.isEmpty
                ? "You"
                : challenge.creatorName,
            progress: challenge.creatorProgress,
            target: challenge.target,
            ratio: challenge.creatorRatio,
            color: AppColors.primary,
          ),
          const SizedBox(height: 14),
          _ProgressBlock(
            label: challenge.friendName.isEmpty
                ? "Friend"
                : challenge.friendName,
            progress: challenge.friendProgress,
            target: challenge.target,
            ratio: challenge.friendRatio,
            color: AppColors.navy,
          ),
          const SizedBox(height: 18),
          _ActionRow(challenge: challenge),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;

    switch (status) {
      case "pending":
        color = AppColors.accent;
        label = "Pending";
        break;
      case "ongoing":
        color = AppColors.primary;
        label = "Active";
        break;
      case "completed":
        color = AppColors.sky;
        label = "Completed";
        break;
      case "rejected":
        color = AppColors.error;
        label = "Rejected";
        break;
      case "expired":
        color = AppColors.subtitle;
        label = "Expired";
        break;
      default:
        color = AppColors.subtitle;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool emphasize;

  const _MetaChip({
    required this.icon,
    required this.label,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = emphasize ? AppColors.primary : AppColors.subtitle;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: emphasize
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.mint.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBlock extends StatelessWidget {
  final String label;
  final int progress;
  final int target;
  final double ratio;
  final Color color;

  const _ProgressBlock({
    required this.label,
    required this.progress,
    required this.target,
    required this.ratio,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.subtitle.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ),
            Text(
              "$progress / $target",
              style: AppTextStyles.subtitle.copyWith(fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _ActionRow extends ConsumerWidget {
  final ChallengeModel challenge;

  const _ActionRow({required this.challenge});

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
    String successMessage,
  ) async {
    try {
      await action();
      ref.invalidate(challengesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(authProvider).user?.id;

    if (challenge.status == "pending") {
      if (currentUserId != null && currentUserId != challenge.friendId) {
        return const Text("Waiting for your friend to respond");
      }

      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _run(
                context,
                ref,
                () => ref
                    .read(challengeRepositoryProvider)
                    .rejectChallenge(challenge.id),
                "Challenge declined",
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: Color(0xFFFFCDD2)),
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text("Decline"),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _run(
                context,
                ref,
                () => ref
                    .read(challengeRepositoryProvider)
                    .acceptChallenge(challenge.id),
                "Challenge accepted",
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(46),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text("Accept"),
            ),
          ),
        ],
      );
    }

    if (challenge.status == "ongoing") {
      return SizedBox(
        width: double.infinity,
        height: 46,
        child: ElevatedButton.icon(
          onPressed: () => _run(
            context,
            ref,
            () => ref
                .read(challengeRepositoryProvider)
                .updateProgress(challenge.id),
            "Progress updated",
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text("Log progress (self-reported)"),
        ),
      );
    }

    if (challenge.status == "completed") {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          "Completed · +${challenge.ecoReward} Eco Points",
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.mint.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        challenge.status == "rejected"
            ? "This challenge was declined"
            : "This challenge is no longer active",
        textAlign: TextAlign.center,
        style: AppTextStyles.subtitle,
      ),
    );
  }
}
