import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class PointsStatusChip extends StatelessWidget {
  final int ecoPoints;
  final bool isVerified;

  const PointsStatusChip({
    super.key,
    required this.ecoPoints,
    required this.isVerified,
  });

  static String label({required int ecoPoints, required bool isVerified}) {
    if (isVerified) {
      return "$ecoPoints Eco Points · verified";
    }
    return "$ecoPoints Eco Points · self-reported";
  }

  @override
  Widget build(BuildContext context) {
    final text = label(ecoPoints: ecoPoints, isVerified: isVerified);
    return Semantics(
      label: text,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isVerified
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: AppTextStyles.subtitle.copyWith(
            color: isVerified ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
