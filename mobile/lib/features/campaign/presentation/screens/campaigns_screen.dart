import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/friendly_error.dart';
import '../../../../core/widgets/app_status.dart';
import '../../application/campaign_providers.dart';
import '../widgets/campaign_visuals.dart';
import 'campaign_detail_screen.dart';
import '../../../map/eco_map_screen.dart';

class CampaignsScreen extends ConsumerWidget {
  const CampaignsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Campaigns", style: AppTextStyles.title),
              Text("Verified environmental action across the UAE", style: AppTextStyles.tagline),
            ],
          ),
          actions: [
            IconButton(
              tooltip: "Smart Eco Map",
              icon: const Icon(Icons.map_rounded),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EcoMapScreen())),
            ),
          ],
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.subtitle,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: TextStyle(fontWeight: FontWeight.w800),
            tabs: [
              Tab(text: "Join now"),
              Tab(text: "My campaigns"),
              Tab(text: "Past"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _CampaignList(filter: "open"),
            _CampaignList(filter: "mine"),
            _CampaignList(filter: "past"),
          ],
        ),
      ),
    );
  }
}

class _CampaignList extends ConsumerWidget {
  final String filter;
  const _CampaignList({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(campaignsProvider(filter));
    return async.when(
      loading: () => const AppLoading(),
      error: (e, _) => AppErrorState(
        message: friendlyError(e, fallback: "Could not load campaigns."),
        onRetry: () => ref.invalidate(campaignsProvider(filter)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return switch (filter) {
            "mine" => const AppEmptyState(
                icon: Icons.volunteer_activism_rounded,
                title: "You haven't joined yet",
                message: "Join a campaign near you. Eco Points are credited once a field verifier confirms your participation.",
              ),
            "past" => const AppEmptyState(
                icon: Icons.history_rounded,
                title: "No past campaigns",
                message: "Finished campaigns and their verified impact will show here.",
              ),
            _ => const AppEmptyState(
                icon: Icons.forest_rounded,
                title: "No open campaigns right now",
                message: "New tree planting, beach clean-ups and recycling drives are added every week.",
              ),
          };
        }
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.invalidate(campaignsProvider(filter)),
          child: ListView(
            padding: const EdgeInsets.only(top: 16, bottom: 24),
            children: [
              if (filter == "open") const _HowItWorks(),
              for (final c in items)
                CampaignCard(
                  campaign: c,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CampaignDetailScreen(campaignId: c.id)),
                    );
                    ref.invalidate(campaignsProvider(filter));
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    Widget step(IconData icon, String title, String text) => Expanded(
          child: Column(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.sun, size: 20),
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(height: 2),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11.5, height: 1.3)),
          ]),
        );
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [AppColors.ink, Color(0xFF3A3256)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        step(Icons.how_to_reg_rounded, "Join", "Pick an approved campaign"),
        step(Icons.place_rounded, "Show up", "Take part on site"),
        step(Icons.verified_user_rounded, "Verified", "A field verifier confirms"),
        step(Icons.stars_rounded, "Earn", "Eco Points are credited"),
      ]),
    );
  }
}
