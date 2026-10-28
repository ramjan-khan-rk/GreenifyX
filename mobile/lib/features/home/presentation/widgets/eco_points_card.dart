import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/brand_icons.dart';

class EcoPointsCard extends StatelessWidget {
  final int ecoPoints;
  final int level;
  final int streak;

  const EcoPointsCard({
    super.key,
    required this.ecoPoints,
    required this.level,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(BrandGlyph.ecoPoints, color: AppColors.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text("Your Eco Points", style: AppTextStyles.title),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "From friend-verified posts and challenge wins",
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Item(
                icon: Icons.star_rounded,
                value: "$level",
                title: "Level",
                color: AppColors.navy,
              ),
              _Item(
                icon: BrandGlyph.ecoPoints,
                value: "$ecoPoints",
                title: "Eco Points",
                color: AppColors.accent,
              ),
              _Item(
                icon: Icons.local_fire_department_rounded,
                value: "$streak",
                title: "Streak",
                color: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String value;
  final String title;
  final Color color;

  const _Item({
    required this.icon,
    required this.value,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: 8),
        Text(value, style: AppTextStyles.title),
        Text(title, style: AppTextStyles.subtitle.copyWith(fontSize: 12)),
      ],
    );
  }
}
