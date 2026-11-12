import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

const _reasons = [
  ("Not an eco action", Icons.eco_outlined),
  ("Misleading", Icons.help_outline_rounded),
  ("Inappropriate", Icons.visibility_off_outlined),
  ("Spam", Icons.report_gmailerrorred_rounded),
  ("Other", Icons.more_horiz_rounded),
];

/// Bottom sheet that returns the chosen report reason, or null.
Future<String?> showReportPostSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.card,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text("Report this post", style: AppTextStyles.title),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                "Our team reviews every report. The author is not told who reported.",
                style: AppTextStyles.subtitle,
              ),
            ),
            for (final (label, icon) in _reasons)
              ListTile(
                leading: Icon(icon, color: AppColors.navy),
                title: Text(label, style: AppTextStyles.body),
                onTap: () => Navigator.of(context).pop(label),
              ),
          ],
        ),
      ),
    ),
  );
}
