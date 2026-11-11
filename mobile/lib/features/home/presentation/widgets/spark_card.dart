import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class SparkCard extends StatelessWidget {
  final VoidCallback onShare;

  const SparkCard({super.key, required this.onShare});

  static const lines = [
    "What good thing happened today?",
    "Tell it while the feeling is still warm.",
    "A person, a creature, the planet, or just you.",
    "Small stories are the ones people stay for.",
  ];

  @override
  Widget build(BuildContext context) {
    final line = lines[DateTime.now().day % lines.length];

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF3A2E55), Color(0xFFE36A4A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today",
            style: AppTextStyles.subtitle.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            line,
            style: AppTextStyles.title.copyWith(color: Colors.white, fontSize: 22),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onShare,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.ink,
            ),
            child: const Text("Share a moment"),
          ),
        ],
      ),
    );
  }
}
