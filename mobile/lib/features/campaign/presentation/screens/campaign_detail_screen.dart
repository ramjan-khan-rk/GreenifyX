import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/friendly_error.dart';
import '../../../../core/widgets/app_status.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../profile/application/providers/my_profile_provider.dart';
import '../../application/campaign_providers.dart';
import '../../domain/campaign_model.dart';
import '../widgets/campaign_visuals.dart';

class CampaignDetailScreen extends ConsumerStatefulWidget {
  final String campaignId;
  const CampaignDetailScreen({super.key, required this.campaignId});

  @override
  ConsumerState<CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends ConsumerState<CampaignDetailScreen> {
  bool _busy = false;

  Future<void> _toggleJoin(CampaignModel c) async {
    final messenger = ScaffoldMessenger.of(context);
    if (c.joined) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Leave this campaign?"),
          content: const Text("Your spot will be given to someone else."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Stay")),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Leave")),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _busy = true);
    try {
      final api = ref.read(campaignApiProvider);
      if (c.joined) {
        await api.leave(c.id);
        messenger.showSnackBar(const SnackBar(content: Text("You left the campaign")));
      } else {
        await api.join(c.id);
        messenger.showSnackBar(SnackBar(
          content: Text("You're in! See you at ${c.locationName}. Points are credited after field verification."),
        ));
      }
      ref.invalidate(campaignDetailProvider(c.id));
      ref.invalidate(campaignsProvider("open"));
      ref.invalidate(campaignsProvider("mine"));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _directions(CampaignModel c) async {
    final uri = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=${c.lat},${c.lng}");
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open maps")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(campaignDetailProvider(widget.campaignId));
    return Scaffold(
      backgroundColor: AppColors.background,
      body: async.when(
        loading: () => const AppLoading(),
        error: (e, _) => Scaffold(
          appBar: AppBar(),
          body: AppErrorState(
            message: friendlyError(e, fallback: "Could not load this campaign."),
            onRetry: () => ref.invalidate(campaignDetailProvider(widget.campaignId)),
          ),
        ),
        data: (c) => _body(c),
      ),
    );
  }

  Widget _body(CampaignModel c) {
    final badge = phaseBadge(c);
    final style = categoryStyle(c.category);
    return Stack(children: [
      CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 230,
          pinned: true,
          backgroundColor: style.to,
          foregroundColor: Colors.white,
          flexibleSpace: FlexibleSpaceBar(
            background: CampaignCover(
              campaign: c,
              height: 300,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(spacing: 8, children: [GlassChip(c.category), GlassChip(badge.label, dot: badge.color)]),
                      const Spacer(),
                      Text(c.title,
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, height: 1.15)),
                      const SizedBox(height: 4),
                      Text("by ${c.organiserName}", style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          sliver: SliverList.list(children: [
            if (c.myStatus != null) _StatusBanner(status: c.myStatus!, points: c.pointsPerParticipant),
            Row(children: [
              _Stat(value: "+${c.pointsPerParticipant}", label: "Eco Points", color: const Color(0xFF8A5A00)),
              const SizedBox(width: 10),
              _Stat(value: "${c.spotsLeft}", label: "Spots left", color: AppColors.primary),
              const SizedBox(width: 10),
              _Stat(value: "${c.verifiedOutput}", label: "Verified ${c.outputUnit}", color: AppColors.eco),
            ]),
            const SizedBox(height: 16),
            _Section(children: [
              ProgressMeter(
                label: "Volunteers",
                value: "${c.participantCount} / ${c.targetParticipants}",
                progress: c.participantProgress,
                color: AppColors.primary,
              ),
              if (c.targetOutput > 0) ...[
                const SizedBox(height: 12),
                ProgressMeter(
                  label: "Verified ${c.outputUnit}",
                  value: "${c.verifiedOutput} / ${c.targetOutput}",
                  progress: c.outputProgress,
                  color: AppColors.eco,
                ),
              ],
            ]),
            if (c.description.isNotEmpty) ...[
              const _Heading("About"),
              Text(c.description, style: const TextStyle(fontSize: 15, height: 1.55, color: AppColors.ink)),
            ],
            const _Heading("When & where"),
            _Section(children: [
              _InfoRow(icon: Icons.event_rounded, title: campaignDates(c), subtitle: "Arrive on time so the verifier can record you"),
              const Divider(height: 22),
              _InfoRow(icon: Icons.place_rounded, title: c.locationName, subtitle: c.emirate),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _directions(c),
                  icon: const Icon(Icons.directions_rounded),
                  label: const Text("Get directions"),
                ),
              ),
            ]),
            if (c.requirements.isNotEmpty) ...[
              const _Heading("What to bring"),
              _Section(children: [Text(c.requirements, style: const TextStyle(height: 1.5))]),
            ],
            const _Heading("Trust & verification"),
            _Section(children: [
              _InfoRow(
                icon: Icons.assignment_turned_in_rounded,
                title: c.permitReference.isNotEmpty ? "Permit on file" : "Permit pending",
                subtitle: c.permitReference.isNotEmpty ? "Reference ${c.permitReference}" : "The organiser is confirming site permission",
                color: c.permitReference.isNotEmpty ? AppColors.eco : AppColors.subtitle,
              ),
              const Divider(height: 22),
              _InfoRow(
                icon: Icons.verified_user_rounded,
                title: c.verifiers.isEmpty ? "Field verifier to be assigned" : "Authorised field verifier",
                subtitle: c.verifiers.isEmpty
                    ? "Participation is confirmed on site"
                    : c.verifiers.map((v) => v.name).join(", "),
                color: AppColors.eco,
              ),
              const Divider(height: 22),
              const _InfoRow(
                icon: Icons.gps_fixed_rounded,
                title: "GPS and photo evidence",
                subtitle: "Points are credited only after the on-site report is approved",
              ),
            ]),
            if (c.evidence.isNotEmpty) ...[
              const _Heading("Verified evidence"),
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: c.evidence.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Image.network(
                        c.evidence[i].url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(color: AppColors.blush),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ]),
      if (c.joined || c.canJoin)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4))],
            ),
            child: SizedBox(
              height: 52,
              child: c.joined
                  ? OutlinedButton(
                      onPressed: _busy || c.myStatus != "joined" ? null : () => _toggleJoin(c),
                      child: Text(c.myStatus == "joined" ? "Leave campaign" : "Attendance recorded"),
                    )
                  : ElevatedButton.icon(
                      onPressed: _busy ? null : () => _toggleJoin(c),
                      icon: _busy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.volunteer_activism_rounded),
                      label: Text("Join · earn ${c.pointsPerParticipant} Eco Points"),
                    ),
            ),
          ),
        ),
    ]);
  }
}

class _StatusBanner extends StatelessWidget {
  final String status;
  final int points;
  const _StatusBanner({required this.status, required this.points});

  @override
  Widget build(BuildContext context) {
    final (icon, color, text) = switch (status) {
      "verified" => (Icons.verified_rounded, AppColors.eco, "Your participation is verified. +$points Eco Points credited."),
      "attended" => (Icons.hourglass_top_rounded, const Color(0xFF8A5A00), "Attendance recorded. Points arrive once the report is approved."),
      _ => (Icons.check_circle_rounded, AppColors.primary, "You're registered. Show up on the day to be verified."),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, height: 1.35))),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _Stat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, color: AppColors.subtitle)),
        ]),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
        child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
      );
}

class _Section extends StatelessWidget {
  final List<Widget> children;
  const _Section({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  const _InfoRow({required this.icon, required this.title, required this.subtitle, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: AppColors.subtitle, fontSize: 13, height: 1.35)),
        ]),
      ),
    ]);
  }
}

/// Small avatar row used by verifier screens.
class PeopleRow extends StatelessWidget {
  final List<PersonRef> people;
  const PeopleRow({super.key, required this.people});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Stack(children: [
        for (var i = 0; i < people.length && i < 6; i++)
          Positioned(
            left: i * 22.0,
            child: Container(
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              child: UserAvatar(imageUrl: people[i].profileImage, radius: 14),
            ),
          ),
      ]),
    );
  }
}

/// Keeps the profile's points in sync after campaign actions.
void refreshPointsViews(WidgetRef ref) {
  ref.invalidate(myProfileProvider);
  ref.invalidate(myPointsProvider);
}
