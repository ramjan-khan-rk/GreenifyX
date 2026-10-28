import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class BrandGlyph {
  const BrandGlyph._();

  static const home = Icons.home_rounded;
  static const friends = Icons.groups_rounded;
  static const challenges = Icons.emoji_events_rounded;
  static const leaderboard = Icons.leaderboard_rounded;
  static const profile = Icons.person_rounded;
  static const post = Icons.add_box_rounded;
  static const verified = Icons.verified_rounded;
  static const ecoPoints = Icons.monetization_on_rounded;
  static const recycle = Icons.recycling_rounded;
  static const settings = Icons.settings_rounded;
  static const chat = Icons.chat_bubble_rounded;
  static const updates = Icons.notifications_rounded;
}

class BrandIconBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const BrandIconBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: tint, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.subtitle.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.forest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BrandJourneyCard extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  final VoidCallback onTap;

  const BrandJourneyCard({
    super.key,
    required this.title,
    required this.body,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(title, style: AppTextStyles.title.copyWith(fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              body,
              style: AppTextStyles.subtitle.copyWith(height: 1.35, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
