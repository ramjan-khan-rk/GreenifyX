import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';

class QuoteCard extends StatelessWidget {
  const QuoteCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Text(
        "Every verified green action earns Eco Points and brings your community with you.",
        textAlign: TextAlign.center,
        style: AppTextStyles.body.copyWith(height: 1.4),
      ),
    );
  }
}
