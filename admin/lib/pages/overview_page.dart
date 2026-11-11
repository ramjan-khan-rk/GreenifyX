import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/admin_api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/loader.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Loader<Json>(
      load: Session.instance.api.stats,
      builder: (context, stats, reload) => _Overview(stats: stats, reload: reload),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.stats, required this.reload});
  final Json stats;
  final VoidCallback reload;

  @override
  Widget build(BuildContext context) {
    final k = Json.from(stats['kpis'] as Map);
    final series = Json.from(stats['series'] as Map);
    final signups = List<Json>.from((series['signups'] as List).map((e) => Json.from(e as Map)));
    final posts = List<Json>.from((series['posts'] as List).map((e) => Json.from(e as Map)));
    final byActivity = List<Json>.from((stats['byActivity'] as List).map((e) => Json.from(e as Map)));
    final topUsers = List<Json>.from((stats['topUsers'] as List).map((e) => Json.from(e as Map)));
    final recent = List<Json>.from((stats['recentPosts'] as List).map((e) => Json.from(e as Map)));

    final newNow = (k['newUsers7d'] as num?)?.toInt() ?? 0;
    final newPrev = (k['newUsersPrev7d'] as num?)?.toInt() ?? 0;
    final growth = newPrev == 0 ? null : (((newNow - newPrev) / newPrev) * 100).round();
    final reported = (k['reportedPosts'] as num?)?.toInt() ?? 0;
    final pendingReports = (k['reportsPending'] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Welcome back, ${Session.instance.adminName.split(' ').first}',
          subtitle: 'Community health and impact for the last 30 days · updated ${Fmt.ago(stats['generatedAt'])}',
          actions: [
            OutlinedButton.icon(onPressed: reload, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Refresh')),
          ],
        ),
        if (pendingReports > 0) ...[
          _Alert(
            text: '$pendingReports field verification ${pendingReports == 1 ? 'report is' : 'reports are'} waiting for approval.',
            action: 'Review evidence',
            onTap: () => context.go('/verification'),
          ),
          const SizedBox(height: 12),
        ],
        if (reported > 0) ...[
          _Alert(
            text: '$reported ${reported == 1 ? 'post is' : 'posts are'} waiting for review.',
            action: 'Open moderation',
            onTap: () => context.go('/moderation'),
          ),
          const SizedBox(height: 16),
        ],
        ResponsiveGrid(children: [
          KpiCard(
            label: 'Community members',
            value: Fmt.compact(k['totalUsers'] as num?),
            icon: Icons.people_alt_rounded,
            color: Brand.sky,
            caption: '${Fmt.number(newNow)} joined this week',
            delta: growth,
          ),
          KpiCard(
            label: 'Active this week',
            value: Fmt.compact(k['activeUsers7d'] as num?),
            icon: Icons.bolt_rounded,
            color: Brand.sun,
            caption: 'Posted at least one action',
          ),
          KpiCard(
            label: 'Verified eco actions',
            value: Fmt.compact(k['verifiedPosts'] as num?),
            icon: Icons.verified_rounded,
            color: Brand.eco,
            caption: '${k['verificationRate']}% of ${Fmt.number(k['totalPosts'] as num?)} posts',
          ),
          KpiCard(
            label: 'Est. CO₂ saved',
            value: Fmt.co2(k['co2SavedKg'] as num?),
            icon: Icons.co2_rounded,
            color: Brand.coral,
            caption: 'From verified actions',
          ),
        ]),
        const SizedBox(height: 16),
        _CampaignStrip(k: k),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 980;
          final trend = Panel(
            title: 'Growth & activity',
            trailing: const Text('Last 30 days', style: TextStyle(color: Brand.muted, fontSize: 13)),
            child: TrendChart(
              days: [for (final d in posts) d['date'] as String],
              series: [
                LineSeries(label: 'Posts', values: [for (final d in posts) d['count'] as num], color: Brand.coral),
                LineSeries(label: 'New members', values: [for (final d in signups) d['count'] as num], color: Brand.eco),
              ],
            ),
          );
          final activities = Panel(
            title: 'Top actions',
            child: byActivity.isEmpty
                ? const EmptyState(icon: Icons.eco_outlined, title: 'No posts yet')
                : BarList(
                    items: [
                      for (var i = 0; i < byActivity.length; i++)
                        BarItem(byActivity[i]['activity'] as String, byActivity[i]['count'] as num,
                            color: Brand.series[i % Brand.series.length]),
                    ],
                  ),
          );
          if (!wide) return Column(children: [trend, const SizedBox(height: 16), activities]);
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 3, child: trend),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: activities),
          ]);
        }),
        const SizedBox(height: 16),
        ResponsiveGrid(minWidth: 420, maxColumns: 2, children: [
          Panel(
            title: 'Top contributors',
            trailing: TextButton(onPressed: () => context.go('/users'), child: const Text('All users')),
            child: topUsers.isEmpty
                ? const EmptyState(icon: Icons.emoji_events_outlined, title: 'No contributors yet')
                : Column(children: [
                    for (var i = 0; i < topUsers.length; i++) _RankRow(rank: i + 1, user: topUsers[i]),
                  ]),
          ),
          Panel(
            title: 'Latest activity',
            child: recent.isEmpty
                ? const EmptyState(icon: Icons.history_rounded, title: 'Nothing posted yet')
                : Column(children: [for (final p in recent) _ActivityRow(post: p)]),
          ),
        ]),
        const SizedBox(height: 16),
        ResponsiveGrid(children: [
          KpiCard(label: 'Eco Points issued', value: Fmt.compact(k['ecoPointsIssued'] as num?), icon: Icons.stars_rounded, color: Brand.sun),
          KpiCard(label: 'Active challenges', value: Fmt.number(k['challengesActive'] as num?), icon: Icons.flag_rounded, color: Brand.sky),
          KpiCard(label: 'Challenges completed', value: Fmt.number(k['challengesCompleted'] as num?), icon: Icons.emoji_events_rounded, color: Brand.eco),
          KpiCard(label: 'Comments', value: Fmt.compact(k['totalComments'] as num?), icon: Icons.forum_rounded, color: Brand.coral),
        ]),
      ],
    );
  }
}

/// Operational strip for the campaign + field verification pipeline.
class _CampaignStrip extends StatelessWidget {
  const _CampaignStrip({required this.k});
  final Json k;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget stat(String value, String label, IconData icon) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Brand.sun, size: 20),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
              Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12.5)),
            ]),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: [Brand.ink, Brand.inkSoft], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Campaigns & field verification', style: t.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          const Spacer(),
          TextButton(
            onPressed: () => context.go('/campaigns'),
            style: TextButton.styleFrom(foregroundColor: Brand.sun),
            child: const Text('Open campaigns'),
          ),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 36, runSpacing: 14, children: [
          stat(Fmt.number(k['campaignsActive'] as num?), 'Active campaigns', Icons.forest_rounded),
          stat(Fmt.number(k['campaignParticipantsVerified'] as num?), 'Verified participants', Icons.how_to_reg_rounded),
          stat(Fmt.number(k['treesVerified'] as num?), 'Trees verified', Icons.park_rounded),
          stat('${Fmt.number(k['wasteKgVerified'] as num?)} kg', 'Waste collected', Icons.delete_sweep_rounded),
          stat(Fmt.number(k['reportsPending'] as num?), 'Reports to review', Icons.fact_check_rounded),
        ]),
      ]),
    );
  }
}

class _Alert extends StatelessWidget {
  const _Alert({required this.text, required this.action, required this.onTap});
  final String text;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Brand.sun.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Brand.sun.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        const Icon(Icons.flag_rounded, color: Color(0xFF9A6A00)),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700))),
        TextButton(onPressed: onTap, child: Text(action)),
      ]),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.user});
  final int rank;
  final Json user;

  @override
  Widget build(BuildContext context) {
    final medal = rank == 1 ? Brand.sun : rank == 2 ? const Color(0xFFB8B8C8) : rank == 3 ? const Color(0xFFD08A5C) : Brand.border;
    final name = (user['name'] as String?)?.isNotEmpty == true ? user['name'] as String : 'Unnamed';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: medal.withValues(alpha: rank <= 3 ? 0.25 : 1), shape: BoxShape.circle),
          child: Text('$rank', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
        ),
        const SizedBox(width: 12),
        Avatar(name: name, url: user['profileImage'] as String?),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text((user['emirate'] as String?)?.isNotEmpty == true ? user['emirate'] as String : 'Emirate not set',
                style: const TextStyle(color: Brand.muted, fontSize: 12)),
          ]),
        ),
        Text('${Fmt.number(user['ecoPoints'] as num?)} pts', style: const TextStyle(fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.post});
  final Json post;

  @override
  Widget build(BuildContext context) {
    final user = post['user'] is Map ? Json.from(post['user'] as Map) : const <String, dynamic>{};
    final name = (user['name'] as String?)?.isNotEmpty == true ? user['name'] as String : 'Someone';
    final verified = post['isVerified'] == true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Avatar(name: name, url: user['profileImage'] as String?),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.w700)),
              const TextSpan(text: ' logged '),
              TextSpan(text: post['activity'] as String? ?? 'an action', style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        StatusPill(verified ? 'Verified' : 'Pending', color: verified ? Brand.eco : Brand.muted),
        const SizedBox(width: 10),
        SizedBox(
          width: 64,
          child: Text(Fmt.ago(post['createdAt']),
              textAlign: TextAlign.right, style: const TextStyle(color: Brand.muted, fontSize: 12)),
        ),
      ]),
    );
  }
}
