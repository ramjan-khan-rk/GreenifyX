import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/widgets/app_status.dart';
import 'org_api.dart';
import 'org_dashboard_screen.dart';
import 'org_widgets.dart';
import 'register_org_screen.dart';
import 'package:greenifyx/core/i18n/app_locale.dart';

class TeamsScreen extends ConsumerWidget {
  const TeamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr("Teams"), style: AppTextStyles.title),
            Text(tr("Your company, school or community, together"), style: AppTextStyles.tagline),
          ]),
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.subtitle,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: TextStyle(fontWeight: FontWeight.w800),
            tabs: [Tab(text: "My teams"), Tab(text: "Leaderboard")],
          ),
        ),
        body: const TabBarView(children: [_MyTeams(), _Leaderboard()]),
      ),
    );
  }
}

class _MyTeams extends ConsumerWidget {
  const _MyTeams();

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final code = await showDialog<String>(context: context, builder: (_) => const _JoinDialog());
    if (code == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final org = await ref.read(orgApiProvider).join(code);
      ref.invalidate(myOrgsProvider);
      messenger.showSnackBar(SnackBar(content: Text("You joined ${org["name"]}")));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(myOrgsProvider).when(
          loading: () => const AppLoading(),
          error: (e, _) => AppErrorState(message: friendlyError(e), onRetry: () => ref.invalidate(myOrgsProvider)),
          data: (orgs) => RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(myOrgsProvider),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              if (orgs.isEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      colors: [AppColors.ink, Color(0xFF3A3256)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.groups_rounded, color: AppColors.sun, size: 34),
                    SizedBox(height: 10),
                    Text(tr("Make an impact as a team"), style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                    SizedBox(height: 6),
                    Text(
                      tr("Join your company, school or community with its code. Your verified actions count towards your team's impact."),
                      style: TextStyle(color: Color(0xCCFFFFFF), height: 1.45),
                    ),
                  ]),
                ),
              for (final o in orgs) _OrgTile(org: o),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(minimumSize: const Size(0, 50)),
                    onPressed: () => _join(context, ref),
                    icon: const Icon(Icons.key_rounded),
                    label: Text(tr("Join with code")),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
                    onPressed: () async {
                      final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const RegisterOrgScreen()));
                      if (ok == true) ref.invalidate(myOrgsProvider);
                    },
                    icon: const Icon(Icons.add_business_rounded),
                    label: Text(tr("Register")),
                  ),
                ),
              ]),
            ]),
          ),
        );
  }
}

class _OrgTile extends StatelessWidget {
  final Json org;
  const _OrgTile({required this.org});

  @override
  Widget build(BuildContext context) {
    final pending = org["status"] == "pending";
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.border)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
          child: Icon(orgIcon(org["type"]?.toString() ?? ""), color: AppColors.primary),
        ),
        title: Row(children: [
          Flexible(child: Text(org["name"]?.toString() ?? "", overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
          if (org["verified"] == true) ...[const SizedBox(width: 6), const Icon(Icons.verified_rounded, size: 18, color: AppColors.eco)],
        ]),
        subtitle: Text(
          pending ? "Awaiting verification · ${org["memberCount"]} members" : "${org["type"]} · ${org["memberCount"]} members",
          style: TextStyle(color: pending ? const Color(0xFFB07A00) : AppColors.subtitle),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrgDashboardScreen(orgId: org["_id"].toString()))),
      ),
    );
  }
}

class _Leaderboard extends ConsumerWidget {
  const _Leaderboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(orgLeaderboardProvider).when(
          loading: () => const AppLoading(),
          error: (e, _) => AppErrorState(message: friendlyError(e), onRetry: () => ref.invalidate(orgLeaderboardProvider)),
          data: (rows) => rows.isEmpty
              ? AppEmptyState(icon: Icons.emoji_events_rounded, title: tr("No teams yet"), message: tr("Verified organisations appear here."))
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async => ref.invalidate(orgLeaderboardProvider),
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        tr("Ranked by verified Eco Points per member over 90 days, so small and large teams compete fairly."),
                        style: TextStyle(color: AppColors.subtitle, fontSize: 13, height: 1.4),
                      ),
                    ),
                    for (var i = 0; i < rows.length; i++) _RankRow(rank: i + 1, row: rows[i]),
                  ]),
                ),
        );
  }
}

class _RankRow extends StatelessWidget {
  final int rank;
  final Json row;
  const _RankRow({required this.rank, required this.row});

  @override
  Widget build(BuildContext context) {
    final mine = row["isMine"] == true;
    final medal = switch (rank) {
      1 => AppColors.sun,
      2 => const Color(0xFFB8B8C8),
      3 => const Color(0xFFD08A5C),
      _ => AppColors.border,
    };
    final trees = (row["trees"] as num? ?? 0);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: mine ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mine ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: medal.withValues(alpha: rank <= 3 ? 0.3 : 1), shape: BoxShape.circle),
          child: Text("$rank", style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 12),
        Icon(orgIcon(row["type"]?.toString() ?? ""), color: AppColors.subtitle, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(row["name"]?.toString() ?? "", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(
              "${row["members"]} members · ${row["participations"]} verified actions${trees > 0 ? " · $trees trees" : ""}",
              style: const TextStyle(color: AppColors.subtitle, fontSize: 12.5),
            ),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(compactNumber(row["pointsPerMember"] as num?), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.eco)),
          Text(tr("pts / member"), style: TextStyle(color: AppColors.subtitle, fontSize: 11)),
        ]),
      ]),
    );
  }
}

class _JoinDialog extends StatefulWidget {
  const _JoinDialog();

  @override
  State<_JoinDialog> createState() => _JoinDialogState();
}

class _JoinDialogState extends State<_JoinDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr("Join a team")),
      content: TextField(
        controller: _c,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r"[A-Za-z0-9]"))],
        style: const TextStyle(fontSize: 22, letterSpacing: 6, fontWeight: FontWeight.w800),
        textAlign: TextAlign.center,
        decoration: InputDecoration(hintText: "ABC234", helperText: tr("Ask your team manager for the code")),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr("Cancel"))),
        FilledButton(
          onPressed: () {
            if (_c.text.trim().length == 6) Navigator.pop(context, _c.text.trim().toUpperCase());
          },
          child: Text(tr("Join")),
        ),
      ],
    );
  }
}
