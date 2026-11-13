import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/friendly_error.dart';
import '../../../../core/widgets/app_status.dart';
import '../../application/campaign_providers.dart';
import '../../domain/campaign_model.dart';
import '../widgets/campaign_visuals.dart';
import 'campaign_detail_screen.dart' show PeopleRow;
import 'submit_report_screen.dart';
import 'package:greenifyx/core/i18n/app_locale.dart';

class VerifierHomeScreen extends ConsumerWidget {
  const VerifierHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr("Field verification"), style: AppTextStyles.title),
              Text(tr("Authorised verifier"), style: AppTextStyles.tagline),
            ],
          ),
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.subtitle,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: TextStyle(fontWeight: FontWeight.w800),
            tabs: [Tab(text: "Assignments"), Tab(text: "My reports")],
          ),
        ),
        body: const TabBarView(children: [_Assignments(), _Reports()]),
      ),
    );
  }
}

class _Assignments extends ConsumerWidget {
  const _Assignments();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(verifierCampaignsProvider);
    return async.when(
      loading: () => const AppLoading(),
      error: (e, _) => AppErrorState(
        message: friendlyError(e, fallback: "Could not load your assignments."),
        onRetry: () => ref.invalidate(verifierCampaignsProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return AppEmptyState(
            icon: Icons.assignment_rounded,
            title: tr("No assignments yet"),
            message: tr("When an admin assigns you to a campaign, it appears here with the site location and attendee list."),
          );
        }
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.invalidate(verifierCampaignsProvider),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [for (final c in items) _AssignmentCard(c: c)],
          ),
        );
      },
    );
  }
}

class _AssignmentCard extends ConsumerWidget {
  final CampaignModel c;
  const _AssignmentCard({required this.c});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badge = phaseBadge(c);
    final waiting = c.participants.where((p) => p.status == "joined").length;
    final canCheckSurvival = c.isPlanting && c.verifiedOutput > 0 && (c.phase == "ended" || c.phase == "completed");
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CampaignCover(
          campaign: c,
          height: 96,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GlassChip(c.category),
              const Spacer(),
              GlassChip(badge.label, dot: badge.color),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 6),
            Text("${c.locationName} · ${campaignDates(c)}", style: TextStyle(color: AppColors.subtitle, fontSize: 13)),
            const SizedBox(height: 12),
            Row(children: [
              PeopleRow(people: c.participants),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "${c.participants.length} registered · $waiting awaiting check-in",
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
            if (c.myReports > 0) ...[
              const SizedBox(height: 10),
              Text(
                "${c.myReports} report${c.myReports == 1 ? '' : 's'} submitted"
                "${c.myPendingReports > 0 ? ' · ${c.myPendingReports} awaiting admin review' : ''}",
                style: const TextStyle(color: AppColors.eco, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
            if (c.survivalChecks.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                "Survival: ${c.survivalChecks.map((s) => "${s.days}d ${s.surviving}/${c.verifiedOutput}").join(" · ")}",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink),
              ),
            ],
            if (canCheckSurvival) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final done = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => SubmitReportScreen(campaign: c, survival: true)),
                    );
                    if (done == true) {
                      ref.invalidate(verifierCampaignsProvider);
                      ref.invalidate(verifierReportsProvider);
                    }
                  },
                  icon: const Icon(Icons.park_rounded),
                  label: Text(tr("Tree survival check")),
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final done = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => SubmitReportScreen(campaign: c)),
                  );
                  if (done == true) {
                    ref.invalidate(verifierCampaignsProvider);
                    ref.invalidate(verifierReportsProvider);
                  }
                },
                icon: const Icon(Icons.add_a_photo_rounded),
                label: Text(tr("Submit field report")),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Reports extends ConsumerWidget {
  const _Reports();

  static final _fmt = DateFormat('d MMM, h:mm a');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(verifierReportsProvider);
    return async.when(
      loading: () => const AppLoading(),
      error: (e, _) => AppErrorState(
        message: friendlyError(e, fallback: "Could not load your reports."),
        onRetry: () => ref.invalidate(verifierReportsProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return AppEmptyState(
            icon: Icons.fact_check_rounded,
            title: tr("No reports yet"),
            message: tr("Reports you submit from the field and their review status show here."),
          );
        }
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.invalidate(verifierReportsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final r = items[i];
              final (label, color) = switch (r.status) {
                "approved" => ("Approved", AppColors.eco),
                "rejected" => ("Rejected", AppColors.error),
                _ => ("Awaiting review", const Color(0xFF8A5A00)),
              };
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(r.campaignTitle, style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    "${_fmt.format(r.submittedAt)} · ${r.attendeeCount} attendees · ${r.distanceM} m from site",
                    style: TextStyle(color: AppColors.subtitle, fontSize: 12.5),
                  ),
                  if (r.status == "rejected" && r.reviewNote.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text("Reason: ${r.reviewNote}", style: const TextStyle(color: AppColors.error, fontSize: 13)),
                  ],
                ]),
              );
            },
          ),
        );
      },
    );
  }
}
