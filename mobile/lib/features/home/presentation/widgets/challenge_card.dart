import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';

class ChallengeCard extends StatelessWidget {
  final VoidCallback? onStart;

  const ChallengeCard({super.key, this.onStart});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Challenge",
            style: AppTextStyles.title,
          ),
          const SizedBox(height: 12),
          Text(
            "Plant a Tree",
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 8),
          Text(
            "+50 Eco Points",
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: 20),
          AppButton(
            text: "Start Challenge",
            onPressed: onStart ?? () {},
          ),
        ],
      ),
    );
  }
}
