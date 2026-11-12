import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/issue_model.dart';
import 'package:greenifyx/core/i18n/app_locale.dart';

const issueCategories = [
  ("Illegal Dumping", Icons.delete_forever_rounded),
  ("Overflowing Bin", Icons.delete_outline_rounded),
  ("Littering", Icons.local_drink_rounded),
  ("Polluted Area", Icons.water_damage_rounded),
  ("Damaged Facility", Icons.build_circle_rounded),
  ("Other", Icons.report_rounded),
];

IconData issueIcon(String category) =>
    issueCategories.firstWhere((c) => c.$1 == category, orElse: () => issueCategories.last).$2;

Color issueStatusColor(String status) => switch (status) {
      "submitted" => AppColors.primary,
      "under_review" => const Color(0xFFB07A00),
      "forwarded" => const Color(0xFF4A78B5),
      "resolved" => AppColors.eco,
      _ => AppColors.subtitle,
    };

final _when = DateFormat("d MMM, h:mm a");

class IssueCard extends StatelessWidget {
  final IssueReport report;
  final VoidCallback? onConfirm;
  final bool busy;

  const IssueCard({super.key, required this.report, this.onConfirm, this.busy = false});

  @override
  Widget build(BuildContext context) {
    final r = report;
    final color = issueStatusColor(r.status);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (r.photos.isNotEmpty)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(fit: StackFit.expand, children: [
              Image.network(r.photos.first, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: AppColors.blush)),
              Positioned(
                left: 10,
                top: 10,
                child: _Pill(icon: issueIcon(r.category), text: r.category, bg: Colors.white, fg: AppColors.ink),
              ),
              Positioned(
                right: 10,
                top: 10,
                child: _Pill(text: r.statusLabel, bg: color, fg: Colors.white),
              ),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              r.landmark.isNotEmpty ? r.landmark : "Pinned location",
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: AppColors.ink),
            ),
            const SizedBox(height: 2),
            Text(
              [if (r.emirate.isNotEmpty) r.emirate, if (r.distanceM != null) "${(r.distanceM! / 1000).toStringAsFixed(1)} km away", _when.format(r.createdAt)]
                  .join(" · "),
              style: const TextStyle(color: AppColors.subtitle, fontSize: 12.5),
            ),
            if (r.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(r.description, style: const TextStyle(height: 1.45, color: AppColors.ink)),
            ],
            if (r.isMine) ...[
              const SizedBox(height: 12),
              IssueTimeline(steps: r.history),
              if (r.pointsCredited > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text("+${r.pointsCredited} Eco Points earned for this report",
                      style: const TextStyle(color: AppColors.eco, fontWeight: FontWeight.w800)),
                ),
            ] else ...[
              const SizedBox(height: 12),
              Row(children: [
                Icon(Icons.groups_rounded, size: 18, color: AppColors.subtitle.withValues(alpha: 0.9)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    r.confirmations == 0 ? "Be the first to confirm" : "${r.confirmations} resident${r.confirmations == 1 ? '' : 's'} confirmed",
                    style: const TextStyle(fontSize: 13, color: AppColors.subtitle),
                  ),
                ),
                if (onConfirm != null)
                  r.confirmedByMe
                      ? Text(tr("You confirmed"), style: TextStyle(color: AppColors.eco, fontWeight: FontWeight.w800, fontSize: 13))
                      : OutlinedButton.icon(
                          onPressed: busy ? null : onConfirm,
                          icon: const Icon(Icons.visibility_rounded, size: 18),
                          label: Text(tr("I see this too")),
                        ),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }
}

class IssueTimeline extends StatelessWidget {
  final List<IssueStep> steps;
  const IssueTimeline({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (var i = 0; i < steps.length; i++)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(children: [
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(top: 3),
              decoration: BoxDecoration(
                color: issueStatusColor(steps[i].status),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
            if (i < steps.length - 1) Container(width: 2, height: 30, color: AppColors.border),
          ]),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(steps[i].label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.ink)),
                  const SizedBox(width: 8),
                  Text(_when.format(steps[i].at), style: const TextStyle(fontSize: 11.5, color: AppColors.subtitle)),
                ]),
                if (steps[i].note.isNotEmpty)
                  Text(steps[i].note, style: const TextStyle(fontSize: 12.5, color: AppColors.subtitle, height: 1.35)),
              ]),
            ),
          ),
        ]),
    ]);
  }
}

class _Pill extends StatelessWidget {
  final IconData? icon;
  final String text;
  final Color bg;
  final Color fg;
  const _Pill({this.icon, required this.text, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
        Text(text, style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}
