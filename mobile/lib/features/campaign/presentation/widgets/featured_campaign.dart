import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../application/campaign_providers.dart';
import '../screens/campaign_detail_screen.dart';
import '../screens/campaigns_screen.dart';
import 'campaign_visuals.dart';
import 'package:greenifyx/core/i18n/app_locale.dart';

/// Home-screen highlight of the next open campaign. Hides itself when there is none.
class FeaturedCampaign extends ConsumerWidget {
  const FeaturedCampaign({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(campaignsProvider("open"));
    return open.maybeWhen(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        final featured = items.firstWhere((c) => c.phase == "live", orElse: () => items.first);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 22),
          Row(children: [
            Expanded(child: Text(tr("Campaigns near you"), style: AppTextStyles.title.copyWith(fontSize: 18))),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CampaignsScreen())),
              child: Text("See all ${items.length}"),
            ),
          ]),
          const SizedBox(height: 6),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CampaignDetailScreen(campaignId: featured.id)),
                );
                ref.invalidate(campaignsProvider("open"));
              },
              child: CampaignCover(
                campaign: featured,
                height: 170,
                radius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      GlassChip(phaseBadge(featured).label, dot: phaseBadge(featured).color),
                      const Spacer(),
                      GlassChip("+${featured.pointsPerParticipant} pts", icon: Icons.stars_rounded),
                    ]),
                    const Spacer(),
                    Text(featured.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, height: 1.15)),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.place_rounded, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text("${featured.emirate} · ${campaignDates(featured)}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
                      ),
                      Text(featured.joined ? "You're in" : "${featured.spotsLeft} spots left",
                          style: const TextStyle(color: AppColors.sun, fontWeight: FontWeight.w800, fontSize: 13)),
                    ]),
                  ]),
                ),
              ),
            ),
          ),
        ]);
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
