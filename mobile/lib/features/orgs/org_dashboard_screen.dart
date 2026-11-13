import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/widgets/app_status.dart';
import '../../core/widgets/user_avatar.dart';
import 'org_api.dart';
import 'org_widgets.dart';
import 'package:greenifyx/core/i18n/app_locale.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/api_service.dart';

class OrgDashboardScreen extends ConsumerWidget {
  final String orgId;
  const OrgDashboardScreen({super.key, required this.orgId});

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr("Leave this team?")),
        content: Text(tr("Your past verified actions stay in your own history.")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr("Stay"))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(tr("Leave"))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(orgApiProvider).leave(orgId);
      ref.invalidate(myOrgsProvider);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(tr("Team impact"), style: AppTextStyles.title),
        actions: [
          IconButton(
            tooltip: tr("ESG report"),
            icon: const Icon(Icons.assessment_rounded),
            onPressed: () async {
              try {
                final r = await ApiService.dio.get("/orgs/$orgId/esg");
                final url = r.data["shareUrl"].toString();
                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
              }
            },
          ),
        ],
      ),
      body: ref.watch(orgDashboardProvider(orgId)).when(
            loading: () => const AppLoading(),
            error: (e, _) => AppErrorState(message: friendlyError(e), onRetry: () => ref.invalidate(orgDashboardProvider(orgId))),
            data: (d) {
              final org = Json.from(d["organization"] as Map);
              final impact = Json.from(d["impact"] as Map);
              final members = (d["members"] as List? ?? const []).whereType<Map>().map((e) => Json.from(e)).toList();
              final sponsored = (impact["sponsored"] as List? ?? const []).whereType<Map>().map((e) => Json.from(e)).toList();
              final code = org["joinCode"]?.toString();
              final manager = org["myRole"] == "owner" || org["myRole"] == "manager";
              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async => ref.invalidate(orgDashboardProvider(orgId)),
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  Row(children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
                      child: Icon(orgIcon(org["type"]?.toString() ?? ""), color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Flexible(child: Text(org["name"]?.toString() ?? "", style: AppTextStyles.title)),
                          if (org["verified"] == true) ...[const SizedBox(width: 6), const Icon(Icons.verified_rounded, color: AppColors.eco)],
                        ]),
                        Text([org["type"], org["emirate"]].where((v) => (v?.toString() ?? "").isNotEmpty).join(" · "), style: AppTextStyles.subtitle),
                      ]),
                    ),
                  ]),
                  if (org["status"] == "pending") ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.sun.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
                      child: Text(
                        tr("Awaiting verification. You can invite members now; the trusted badge and leaderboard place appear once GreenifyX verifies you."),
                        style: TextStyle(height: 1.4, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const LinearGradient(colors: [AppColors.eco, Color(0xFF16664F)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("Last ${impact["days"]} days · verified only", style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                      const SizedBox(height: 12),
                      Row(children: [
                        _HeroStat(compactNumber(impact["points"] as num?), "Eco Points"),
                        _HeroStat(compactNumber(impact["participations"] as num?), "Verified actions"),
                        _HeroStat("${impact["activeMembers"]}/${impact["members"]}", "Active members"),
                      ]),
                      const SizedBox(height: 14),
                      Row(children: [
                        _HeroStat(compactNumber(impact["trees"] as num?), "Trees"),
                        _HeroStat("${compactNumber(impact["wasteKg"] as num?)} kg", "Waste collected"),
                        _HeroStat("${compactNumber(impact["co2Kg"] as num?)} kg", "Est. CO₂"),
                      ]),
                    ]),
                  ),
                  if (manager && code != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                      child: Row(children: [
                        const Icon(Icons.key_rounded, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(tr("Invite code"), style: TextStyle(color: AppColors.subtitle, fontSize: 12.5)),
                            Text(code, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, letterSpacing: 4)),
                          ]),
                        ),
                        IconButton.filledTonal(
                          tooltip: tr("Copy"),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: code));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr("Code copied. Share it with your team."))));
                          },
                          icon: const Icon(Icons.copy_rounded),
                        ),
                      ]),
                    ),
                  ],
                  if (sponsored.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(tr("Our campaigns"), style: AppTextStyles.title.copyWith(fontSize: 17)),
                    const SizedBox(height: 8),
                    for (final c in sponsored)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                        child: Row(children: [
                          const Icon(Icons.forest_rounded, color: AppColors.eco),
                          const SizedBox(width: 10),
                          Expanded(child: Text(c["title"]?.toString() ?? "", style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                          Text("${c["verifiedOutput"]} ${c["outputUnit"]}", style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.eco)),
                        ]),
                      ),
                  ],
                  const SizedBox(height: 20),
                  Text(tr("Top members"), style: AppTextStyles.title.copyWith(fontSize: 17)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                    child: Column(children: [
                      for (final m in members)
                        ListTile(
                          leading: UserAvatar(imageUrl: m["profileImage"]?.toString(), name: m["name"]?.toString(), radius: 18),
                          title: Text(m["name"]?.toString() ?? "", style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: m["role"] == "member" ? null : Text(m["role"] == "owner" ? "Owner" : "Manager"),
                          trailing: Text("${m["periodPoints"]} pts", style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppColors.error),
                    onPressed: () => _leave(context, ref),
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(tr("Leave team")),
                  ),
                ]),
              );
            },
          ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;
  const _HeroStat(this.value, this.label);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
        ]),
      );
}
