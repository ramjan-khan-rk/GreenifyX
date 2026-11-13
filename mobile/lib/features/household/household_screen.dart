import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/i18n/app_locale.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/widgets/user_avatar.dart';

typedef Json = Map<String, dynamic>;

/// Household mode: family or flatmates pool their weekly Eco Points towards one goal.
class HouseholdScreen extends StatefulWidget {
  const HouseholdScreen({super.key});

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  Json? _h;
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _toast(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Future<void> _load() async {
    try {
      final r = await ApiService.dio.get("/household");
      if (!mounted) return;
      setState(() {
        _h = r.data["household"] is Map ? Json.from(r.data["household"] as Map) : null;
        _loaded = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loaded = true);
        _toast(friendlyError(e));
      }
    }
  }

  Future<void> _run(Future<dynamic> Function() call) async {
    setState(() => _busy = true);
    try {
      final r = await call();
      if (!mounted) return;
      final h = r.data["household"];
      setState(() => _h = h is Map ? Json.from(h) : null);
    } catch (e) {
      _toast(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _ask(String title, String label, {String initial = "", TextInputType? type}) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, autofocus: true, keyboardType: type, decoration: InputDecoration(labelText: label)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr("Cancel"))),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: Text(tr("OK"))),
        ],
      ),
    );
  }

  Future<void> _create() async {
    final name = await _ask(tr("Name your household"), tr("e.g. The Khans, Flat 1204"));
    if (name == null || name.isEmpty) return;
    await _run(() => ApiService.dio.post("/household", data: {"name": name}));
  }

  Future<void> _join() async {
    final code = await _ask(tr("Join a household"), tr("Code, like HOME-4KQ7"));
    if (code == null || code.isEmpty) return;
    await _run(() => ApiService.dio.post("/household/join", data: {"code": code}));
  }

  Future<void> _leave() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr("Leave this household?")),
        content: Text(tr("Your points stay yours. You can join again with the code.")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr("Stay"))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr("Leave"))),
        ],
      ),
    );
    if (yes != true) return;
    await _run(() => ApiService.dio.post("/household/leave"));
  }

  Future<void> _editGoal() async {
    final p = Json.from(_h!["progress"] as Map);
    final v = await _ask(tr("Weekly goal"), tr("Eco Points together each week"), initial: "${p["goal"]}", type: TextInputType.number);
    final goal = int.tryParse(v ?? "");
    if (goal == null) return;
    await _run(() => ApiService.dio.patch("/household", data: {"weeklyGoal": goal}));
  }

  @override
  Widget build(BuildContext context) {
    final h = _h;
    return Scaffold(
      appBar: AppBar(title: Text(tr("Household"))),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
                if (h == null) ..._empty() else ..._household(h),
              ]),
            ),
    );
  }

  List<Widget> _empty() => [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(colors: [Color(0xFFF2B544), Color(0xFFE36A4A)])),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("🏡", style: TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(tr("Go green together at home"), style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              tr("Family or flatmates pool their Eco Points each week. Hit your goal together and everyone gets a bonus."),
              style: const TextStyle(color: Colors.white, height: 1.4),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: _busy ? null : _create, icon: const Icon(Icons.add_home_rounded), label: Text(tr("Start a household"))),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: _busy ? null : _join, icon: const Icon(Icons.key_rounded), label: Text(tr("I have a code"))),
      ];

  List<Widget> _household(Json h) {
    final p = Json.from(h["progress"] as Map);
    final members = (h["members"] as List).map((e) => Json.from(e as Map)).toList();
    final isOwner = h["isOwner"] == true;
    return [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(colors: [Color(0xFFF2B544), Color(0xFFE36A4A)])),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text("🏡", style: TextStyle(fontSize: 30)),
            const SizedBox(width: 10),
            Expanded(child: Text(h["name"].toString(), style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 14),
          Text("${p["total"]} / ${p["goal"]} ${tr("points this week")}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (p["percent"] as num) / 100),
              duration: const Duration(milliseconds: 900),
              builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 12, backgroundColor: Colors.white24, color: Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            p["reached"] == true ? "🎉 ${tr("Goal reached! +")}${h["bonus"]} ${tr("Eco Points each")}" : "${tr("Hit the goal and everyone gets +")}${h["bonus"]} ${tr("Eco Points")}",
            style: const TextStyle(color: Colors.white),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      Card(
        child: ListTile(
          leading: const Icon(Icons.key_rounded),
          title: Text(h["code"].toString(), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          subtitle: Text("${members.length}/${h["maxMembers"]} ${tr("people")} · ${tr("Share the code to invite")}"),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              tooltip: tr("Copy"),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: h["code"].toString()));
                _toast(tr("Code copied"));
              },
              icon: const Icon(Icons.copy_rounded),
            ),
            IconButton(
              tooltip: tr("Share"),
              onPressed: () => SharePlus.instance.share(ShareParams(text: "${tr("Join our household on GreenifyX")} 🏡🌱 ${tr("Code")}: ${h["code"]}")),
              icon: const Icon(Icons.ios_share_rounded),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      Text(tr("This week"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      for (var i = 0; i < members.length; i++)
        Card(
          child: ListTile(
            leading: UserAvatar(imageUrl: members[i]["profileImage"]?.toString(), name: members[i]["name"]?.toString(), radius: 20),
            title: Text("${i == 0 && (members[i]["points"] as num) > 0 ? "👑 " : ""}${members[i]["name"]}", style: const TextStyle(fontWeight: FontWeight.w700)),
            trailing: Text("${members[i]["points"]}", style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.eco, fontSize: 16)),
          ),
        ),
      const SizedBox(height: 14),
      Row(children: [
        if (isOwner) Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : _editGoal, icon: const Icon(Icons.flag_rounded), label: Text(tr("Change goal")))),
        if (isOwner) const SizedBox(width: 10),
        Expanded(child: TextButton.icon(onPressed: _busy ? null : _leave, icon: const Icon(Icons.logout_rounded), label: Text(tr("Leave")))),
      ]),
    ];
  }
}
