import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/i18n/app_locale.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/friendly_error.dart';
import '../assistant/assistant_screen.dart';
import '../battles/battles_screen.dart';
import '../events/events_screen.dart' show EventsScreen;
import '../post/domain/eco_activity.dart';
import '../post/presentation/screens/create_post_screen.dart';
import '../social/social_api.dart';

/// Small card for Home: today's AI tip with a tap-through to the full companion.
class CompanionCard extends StatefulWidget {
  const CompanionCard({super.key});

  @override
  State<CompanionCard> createState() => _CompanionCardState();
}

class _CompanionCardState extends State<CompanionCard> {
  Json? _d;

  @override
  void initState() {
    super.initState();
    SocialApi.companion().then((d) {
      if (mounted) setState(() => _d = d);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final daily = d?["daily"] == null ? null : Json.from(d!["daily"] as Map);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Material(
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanionScreen())),
          child: Ink(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF7F53AC), Color(0xFF647DEE)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: AppColors.surface24, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr("Your eco companion"), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  const SizedBox(height: 3),
                  Text(
                    d == null ? tr("Planning your day…") : (d["message"]?.toString() ?? ""),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, height: 1.35),
                  ),
                  if (daily != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.surface24, borderRadius: BorderRadius.circular(12)),
                      child: Text("${tr("Today")}: ${AppLocale.isArabic && (daily["nameAr"] ?? "").toString().isNotEmpty ? daily["nameAr"] : daily["name"]} · +${daily["points"]}",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                  ],
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Personal plan: daily action, weekly goal, challenge and content ideas.
class CompanionScreen extends StatefulWidget {
  const CompanionScreen({super.key});

  @override
  State<CompanionScreen> createState() => _CompanionScreenState();
}

class _CompanionScreenState extends State<CompanionScreen> {
  Json? _d;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await SocialApi.companion();
      if (mounted) setState(() => _d = d);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _acceptGoal(Json g) async {
    try {
      await SocialApi.setGoal((g["points"] as num).toInt(), (g["actions"] as num).toInt());
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr("Goal set. You've got this! 💪"))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Scaffold(
      appBar: AppBar(title: Text(tr("Eco companion"))),
      body: d == null
          ? Center(child: _error != null ? TextButton(onPressed: _load, child: Text(_error!)) : const CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(colors: [Color(0xFF7F53AC), Color(0xFF647DEE)]),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 30),
                    const SizedBox(height: 10),
                    Text(d["message"]?.toString() ?? "", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, height: 1.35)),
                    const SizedBox(height: 14),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _Pill("⭐ ${(d["stats"] as Map)["pointsThisWeek"]} ${tr("this week")}"),
                      _Pill("🔥 ${(d["stats"] as Map)["streak"]} ${tr("day streak")}"),
                      _Pill("📸 ${(d["stats"] as Map)["postsThisWeek"]} ${tr("posts")}"),
                    ]),
                  ]),
                ),
                if (d["daily"] != null) _daily(Json.from(d["daily"] as Map)),
                _goal(d),
                if (d["challenge"] != null) _challenge(Json.from(d["challenge"] as Map)),
                _Card(
                  icon: Icons.lightbulb_rounded,
                  color: AppColors.sun,
                  title: tr("Content idea"),
                  body: tr(d["contentIdea"]?.toString() ?? ""),
                  action: tr("Create post"),
                  onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostScreen())),
                ),
                if (d["nearby"] != null)
                  _Card(
                    icon: Icons.event_rounded,
                    color: const Color(0xFF0083B0),
                    title: tr("Happening near you"),
                    body: "${(d["nearby"] as Map)["title"]}\n${DateFormat("EEE d MMM").format(DateTime.parse((d["nearby"] as Map)["when"].toString()).toLocal())} · ${(d["nearby"] as Map)["where"] ?? ""}",
                    action: tr("See events"),
                    onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EventsScreen())),
                  ),
                _Card(
                  icon: Icons.forum_rounded,
                  color: AppColors.eco,
                  title: tr("Ask me anything"),
                  body: tr("Where do I recycle batteries? What can I plant in summer? How do I join a beach clean-up?"),
                  action: tr("Chat with AI"),
                  onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssistantScreen())),
                ),
              ]),
            ),
    );
  }

  Widget _daily(Json a) => _Card(
        icon: activityIcon(a["icon"]?.toString() ?? "eco"),
        color: laneColor(a["lane"]?.toString() ?? "Planet"),
        title: tr("Today's action"),
        body: "${AppLocale.isArabic && (a["nameAr"] ?? "").toString().isNotEmpty ? a["nameAr"] : a["name"]} · +${a["points"]} ${tr("Eco Points")}\n${a["line"] ?? ""}",
        action: tr("I did it — post it"),
        onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostScreen())),
      );

  Widget _goal(Json d) {
    final goal = d["goal"] == null ? null : Json.from(d["goal"] as Map);
    final sug = Json.from(d["suggestedGoal"] as Map);
    if (goal == null) {
      return _Card(
        icon: Icons.flag_rounded,
        color: AppColors.joy,
        title: tr("Set this week's goal"),
        body: "${sug["points"]} ${tr("Eco Points")} · ${sug["actions"]} ${tr("actions")}",
        action: tr("Accept goal"),
        onAction: () => _acceptGoal(sug),
      );
    }
    final p = ((goal["progressPoints"] as num) / (goal["points"] as num)).clamp(0, 1).toDouble();
    final a = ((goal["progressActions"] as num) / (goal["actions"] as num)).clamp(0, 1).toDouble();
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.flag_rounded, color: AppColors.joy),
          const SizedBox(width: 8),
          Text(tr("Weekly goal"), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const Spacer(),
          if (p >= 1 && a >= 1) const Text("🎉", style: TextStyle(fontSize: 20)),
        ]),
        const SizedBox(height: 14),
        Text("${goal["progressPoints"]} / ${goal["points"]} ${tr("Eco Points")}"),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: p, minHeight: 10, color: AppColors.joy, backgroundColor: AppColors.border)),
        const SizedBox(height: 12),
        Text("${goal["progressActions"]} / ${goal["actions"]} ${tr("actions")}"),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: a, minHeight: 10, color: AppColors.eco, backgroundColor: AppColors.border)),
      ]),
    );
  }

  Widget _challenge(Json c) => _Card(
        icon: Icons.sports_kabaddi_rounded,
        color: const Color(0xFFE8384F),
        title: tr("Friendly challenge"),
        body: c["text"]?.toString() ?? "",
        action: tr("See battles"),
        onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BattlesScreen())),
      );
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill(this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: AppColors.surface24, borderRadius: BorderRadius.circular(14)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
      );
}

class _Card extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;
  const _Card({required this.icon, required this.color, required this.title, required this.body, required this.action, required this.onAction});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          ]),
          const SizedBox(height: 10),
          Text(body, style: const TextStyle(height: 1.45, fontSize: 14.5)),
          const SizedBox(height: 12),
          Align(alignment: AlignmentDirectional.centerStart, child: FilledButton.tonal(onPressed: onAction, child: Text(action))),
        ]),
      );
}
