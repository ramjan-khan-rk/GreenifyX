import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';

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
          Text(
            "Your Eco Points",
            style: AppTextStyles.title,
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
              ),
              _Item(
                icon: Icons.eco,
                value: "$ecoPoints",
                title: "Eco Points",
              ),
              _Item(
                icon: Icons.local_fire_department_rounded,
                value: "$streak",
                title: "Streak",
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

  const _Item({
    required this.icon,
    required this.value,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 32),
        const SizedBox(height: 8),
        Text(value, style: AppTextStyles.title),
        Text(title, style: AppTextStyles.subtitle),
      ],
    );
  }
}
