import 'package:flutter/material.dart';

import '../../../../core/widgets/app_card.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class KarmaCard extends StatelessWidget {
  const KarmaCard({super.key});

  @override
  Widget build(BuildContext context) {

    return AppCard(

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Text(
            "Your Karma",
            style: AppTextStyles.title,
          ),

          const SizedBox(height: 20),

          Row(

            mainAxisAlignment: MainAxisAlignment.spaceAround,

            children: const [

              _Item(
                icon: Icons.star,
                value: "1",
                title: "Level",
              ),

              _Item(
                icon: Icons.eco,
                value: "0",
                title: "Karma",
              ),

              _Item(
                icon: Icons.local_fire_department,
                value: "0",
                title: "Streak",
              ),

            ],

          )

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

        Icon(
          icon,
          color: AppColors.primary,
          size: 32,
        ),

        const SizedBox(height: 8),

        Text(
          value,
          style: AppTextStyles.title,
        ),

        Text(
          title,
          style: AppTextStyles.subtitle,
        )

      ],

    );

  }
}