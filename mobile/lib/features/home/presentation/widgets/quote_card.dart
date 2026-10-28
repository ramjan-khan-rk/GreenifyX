import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';

class QuoteCard extends StatelessWidget {
  const QuoteCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Text(
            "A greener tomorrow starts with you",
            textAlign: TextAlign.center,
            style: AppTextStyles.title.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            "${BrandCopy.tagline}. Every verified green action earns Eco Points and brings your community with you.",
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              height: 1.4,
              color: AppColors.subtitle,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
