import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/i18n/app_locale.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/widgets/user_avatar.dart';
import '../social/social_api.dart';

const _leagues = [
  ("friends", "Friends", Icons.people_alt_rounded),
  ("communities", "Communities", Icons.groups_rounded),
  ("schools", "Schools", Icons.school_rounded),
  ("universities", "Universities", Icons.account_balance_rounded),
  ("companies", "Companies", Icons.business_rounded),
  ("members", "All UAE", Icons.public_rounded),
];

const _badges = {
  "battle_champion": ("Weekly champion", Icons.emoji_events_rounded, Color(0xFFF2B544)),
  "battle_podium": ("Podium finish", Icons.military_tech_rounded, Color(0xFF9AA5B1)),
  "first_verified": ("First verified action", Icons.verified_rounded, Color(0xFF1F8A70)),
  "century": ("100 Eco Points", Icons.stars_rounded, Color(0xFFE36A4A)),
  "streak_3": ("3-day streak", Icons.local_fire_department_rounded, Color(0xFFFF9F43)),
  "week_streak": ("7-day streak", Icons.whatshot_rounded, Color(0xFFE8384F)),
};

/// Weekly battles: live rankings for friends, communities, schools and companies.
class BattlesScreen extends StatefulWidget {
  const BattlesScreen({super.key});

  @override
  State<BattlesScreen> createState() => _BattlesScreenState();
}

class _BattlesScreenState extends State<BattlesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: _leagues.length, vsync: this)..addListener(() {
      if (!_tabs.indexIsChanging) _load();
    });
  final Map<String, Json> _data = {};
  Timer? _live;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    // Live: refresh the open league every 30 seconds.
    _live = Timer.periodic(const Duration(seconds: 30), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _live?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  String get _league => _leagues[_tabs.index].$1;

  Future<void> _load({bool silent = false}) async {
    final l = _league;
    try {
      final d = await SocialApi.battle(l);
      if (mounted) {
        setState(() {
          _data[l] = d;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && !silent) setState(() => _error = friendlyError(e));
    }
  }

  String _countdown(String? iso) {
    final end = DateTime.tryParse(iso ?? "")?.toLocal();
    if (end == null) return "";
    final d = end.difference(DateTime.now());
    if (d.isNegative) return tr("Ending");
    return "${d.inDays}d ${d.inHours % 24}h ${d.inMinutes % 60}m";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1730),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1730),
        foregroundColor: Colors.white,
        title: Text(tr("Weekly Battles"), style: const TextStyle(color: Colors.white)),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: AppColors.sun,
          tabs: [for (final l in _leagues) Tab(icon: Icon(l.$3, size: 20), text: tr(l.$2))],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [for (final l in _leagues) _board(l.$1)]),
    );
  }

  Widget _board(String league) {
    final d = _data[league];
    if (d == null) {
      return Center(child: _error != null ? Text(_error!, style: const TextStyle(color: Colors.white70)) : const CircularProgressIndicator(color: Colors.white));
    }
    final rows = maps(d["standings"]);
    final mine = d["mine"] == null ? null : Json.from(d["mine"] as Map);
    final last = maps(d["lastWeek"]);
    final prizes = (d["prizes"] as List? ?? []).map((e) => (e as num).toInt()).toList();
    final podium = rows.take(3).toList();
    final perMember = ["schools", "universities", "companies"].contains(league);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 30), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(colors: [Color(0xFF7F53AC), Color(0xFFE36A4A)]),
          ),
          child: Row(children: [
            const Icon(Icons.timer_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("${d["week"]} · ${tr("ends in")} ${_countdown(d["endsAt"]?.toString())}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                Text(
                  league == "friends"
                      ? tr("Verified Eco Points earned this week. Beat your friends!")
                      : "${tr("Top 3 win")} +${prizes.isNotEmpty ? prizes[0] : 50} / +${prizes.length > 1 ? prizes[1] : 30} / +${prizes.length > 2 ? prizes[2] : 15} ${tr("points per member")}",
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF2ECC71), shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(tr("LIVE"), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        if (podium.isNotEmpty)
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: podium.length > 1 ? _Podium(row: podium[1], place: 2, height: 96) : const SizedBox()),
            Expanded(child: _Podium(row: podium[0], place: 1, height: 130)),
            Expanded(child: podium.length > 2 ? _Podium(row: podium[2], place: 3, height: 76) : const SizedBox()),
          ]),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(30),
            child: Text(league == "friends" ? tr("Add friends to start a battle") : tr("No teams in this league yet"), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
          ),
        const SizedBox(height: 16),
        if (mine != null && (mine["rank"] as num) > 3) _Row(row: mine, highlight: true, perMember: perMember),
        for (final r in rows.skip(3)) _Row(row: r, highlight: r["isMe"] == true, perMember: perMember),
        if (last.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(tr("Last week's champions"), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          for (final r in last) _Row(row: r, highlight: false, perMember: perMember),
        ],
        const SizedBox(height: 20),
        Text(tr("Your achievements"), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final e in _badges.entries)
            Opacity(
              opacity: (d["achievements"] as List? ?? []).contains(e.key) ? 1 : 0.3,
              child: Container(
                width: 104,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
                child: Column(children: [
                  Icon(e.value.$2, color: e.value.$3, size: 30),
                  const SizedBox(height: 6),
                  Text(tr(e.value.$1), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
        ]),
      ]),
    );
  }
}

class _Podium extends StatelessWidget {
  final Json row;
  final int place;
  final double height;
  const _Podium({required this.row, required this.place, required this.height});

  @override
  Widget build(BuildContext context) {
    final color = place == 1 ? AppColors.sun : place == 2 ? const Color(0xFFC0C7D0) : const Color(0xFFCD7F32);
    return Column(children: [
      if (place == 1) const Icon(Icons.emoji_events_rounded, color: AppColors.sun, size: 30),
      Container(
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 3)),
        child: UserAvatar(imageUrl: row["image"]?.toString(), name: row["name"]?.toString(), radius: place == 1 ? 32 : 26),
      ),
      const SizedBox(height: 6),
      Text(row["name"]?.toString() ?? "", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: row["isMe"] == true ? AppColors.sun : Colors.white, fontWeight: FontWeight.w800)),
      Text("${row["points"]}", style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Container(
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color, color.withValues(alpha: 0.35)]),
        ),
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.only(top: 8),
        child: Text("$place", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
      ),
    ]);
  }
}

class _Row extends StatelessWidget {
  final Json row;
  final bool highlight;
  final bool perMember;
  const _Row({required this.row, required this.highlight, required this.perMember});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: highlight ? AppColors.sun.withValues(alpha: 0.18) : Colors.white10,
          borderRadius: BorderRadius.circular(16),
          border: highlight ? Border.all(color: AppColors.sun) : null,
        ),
        child: Row(children: [
          SizedBox(width: 30, child: Text("${row["rank"]}", style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800))),
          UserAvatar(imageUrl: row["image"]?.toString(), name: row["name"]?.toString(), radius: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(row["name"]?.toString() ?? "", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              if ((row["members"] as num? ?? 1) > 1) Text("${row["members"]} ${tr("members")}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ]),
          ),
          Text("${row["points"]}${perMember ? " /${tr("member")}" : ""}", style: const TextStyle(color: AppColors.sun, fontWeight: FontWeight.w800)),
        ]),
      );
}
