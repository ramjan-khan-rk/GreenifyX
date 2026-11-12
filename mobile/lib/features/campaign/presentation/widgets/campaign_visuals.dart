import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/media_url.dart';
import '../../domain/campaign_model.dart';
import 'package:greenifyx/core/i18n/app_locale.dart';

class CategoryStyle {
  final IconData icon;
  final Color from;
  final Color to;
  const CategoryStyle(this.icon, this.from, this.to);
}

CategoryStyle categoryStyle(String category) {
  switch (category) {
    case 'Tree Plantation':
      return const CategoryStyle(Icons.park_rounded, Color(0xFF1F8A70), Color(0xFF0F5A47));
    case 'Mangrove Restoration':
      return const CategoryStyle(Icons.forest_rounded, Color(0xFF2A9D8F), Color(0xFF1B5E66));
    case 'Beach Cleaning':
      return const CategoryStyle(Icons.beach_access_rounded, Color(0xFF4A90C2), Color(0xFF2B5C8A));
    case 'Public Area Cleaning':
      return const CategoryStyle(Icons.cleaning_services_rounded, Color(0xFF8A5CC2), Color(0xFF5B3A8C));
    case 'Recycling':
      return const CategoryStyle(Icons.recycling_rounded, Color(0xFF3FA76B), Color(0xFF1F6B43));
    case 'Water Conservation':
      return const CategoryStyle(Icons.water_drop_rounded, Color(0xFF3B82C4), Color(0xFF1D4F82));
    case 'Community Gardening':
      return const CategoryStyle(Icons.yard_rounded, Color(0xFF7FA33A), Color(0xFF4E6B1E));
    case 'Awareness Programme':
      return const CategoryStyle(Icons.campaign_rounded, Color(0xFFE36A4A), Color(0xFFA9452C));
    default:
      return const CategoryStyle(Icons.eco_rounded, AppColors.eco, Color(0xFF0F5A47));
  }
}

final _day = DateFormat('d MMM');
final _dayYear = DateFormat('d MMM yyyy');

String campaignDates(CampaignModel c) {
  final sameDay = c.startDate.year == c.endDate.year && c.startDate.month == c.endDate.month && c.startDate.day == c.endDate.day;
  if (sameDay) return _dayYear.format(c.startDate);
  return '${_day.format(c.startDate)} – ${_dayYear.format(c.endDate)}';
}

({String label, Color color}) phaseBadge(CampaignModel c) => switch (c.phase) {
      'live' => (label: tr('Happening now'), color: AppColors.eco),
      'upcoming' => (label: tr('Upcoming'), color: AppColors.sun),
      'ended' => (label: tr('Ended'), color: AppColors.subtitle),
      'completed' => (label: tr('Completed'), color: const Color(0xFF4A78B5)),
      'cancelled' => (label: tr('Cancelled'), color: AppColors.error),
      _ => (label: c.phase, color: AppColors.subtitle),
    };

/// Category gradient with a large watermark icon, or the campaign photo.
class CampaignCover extends StatelessWidget {
  final CampaignModel campaign;
  final double height;
  final Widget? child;
  final BorderRadius? radius;

  const CampaignCover({super.key, required this.campaign, this.height = 150, this.child, this.radius});

  @override
  Widget build(BuildContext context) {
    final style = categoryStyle(campaign.category);
    final image = resolveMediaUrl(campaign.coverImage);
    return ClipRRect(
      borderRadius: radius ?? BorderRadius.zero,
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [style.from, style.to], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
            ),
            if (image != null)
              Image.network(image, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink())
            else ...[
              Positioned(
                right: -20,
                bottom: -30,
                child: Icon(style.icon, size: height * 1.1, color: Colors.white.withValues(alpha: 0.14)),
              ),
              Positioned(
                left: -40,
                top: -50,
                child: Container(
                  width: height * 1.1,
                  height: height * 1.1,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06)),
                ),
              ),
            ],
            // Legibility scrim for text laid over the cover.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0x33000000)],
                ),
              ),
            ),
            ?child,
          ],
        ),
      ),
    );
  }
}

class GlassChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? dot;

  const GlassChip(this.label, {super.key, this.icon, this.dot});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.94), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dot != null) ...[
          Container(width: 7, height: 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 6),
        ],
        if (icon != null) ...[
          Icon(icon, size: 13, color: AppColors.ink),
          const SizedBox(width: 4),
        ],
        Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
      ]),
    );
  }
}

class ProgressMeter extends StatelessWidget {
  final String label;
  final String value;
  final double progress;
  final Color color;

  const ProgressMeter({super.key, required this.label, required this.value, required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.subtitle, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 7,
          backgroundColor: AppColors.blush,
          color: color,
        ),
      ),
    ]);
  }
}

class CampaignCard extends StatelessWidget {
  final CampaignModel campaign;
  final VoidCallback onTap;

  const CampaignCard({super.key, required this.campaign, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = campaign;
    final badge = phaseBadge(c);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CampaignCover(
              campaign: c,
              height: 132,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      GlassChip(c.category),
                      const Spacer(),
                      GlassChip(badge.label, dot: badge.color),
                    ]),
                    const Spacer(),
                    if (c.joined)
                      GlassChip(
                        c.myStatus == 'verified' ? 'Verified · points earned' : "You're in",
                        icon: c.myStatus == 'verified' ? Icons.verified_rounded : Icons.check_circle_rounded,
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink, height: 1.2)),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.place_rounded, size: 15, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(c.locationName,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.subtitle)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.event_rounded, size: 15, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(campaignDates(c), style: const TextStyle(fontSize: 13, color: AppColors.subtitle)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.sun.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                      child: Text('+${c.pointsPerParticipant} pts',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF8A5A00))),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  ProgressMeter(
                    label: tr('Volunteers'),
                    value: '${c.participantCount} / ${c.targetParticipants}',
                    progress: c.participantProgress,
                    color: AppColors.primary,
                  ),
                  if (c.targetOutput > 0) ...[
                    const SizedBox(height: 10),
                    ProgressMeter(
                      label: 'Verified ${c.outputUnit}',
                      value: '${c.verifiedOutput} / ${c.targetOutput}',
                      progress: c.outputProgress,
                      color: AppColors.eco,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
