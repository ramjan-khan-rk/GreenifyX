import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/i18n/app_locale.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/verified_tick.dart';

typedef Json = Map<String, dynamic>;
List<Json> _maps(dynamic v) => (v as List? ?? const []).map((e) => Json.from(e as Map)).toList();

const _emirates = ["Abu Dhabi", "Dubai", "Sharjah", "Ajman", "Umm Al Quwain", "Ras Al Khaimah", "Fujairah"];

/// First-run setup: topics, emirate, creators and communities, invite code.
class OnboardingScreen extends StatefulWidget {
  final Json? initial;
  const OnboardingScreen({super.key, this.initial});

  /// Show once for members who haven't finished it.
  static Future<void> maybeShow(BuildContext context) async {
    try {
      final r = await ApiService.dio.get("/onboarding");
      if (r.data["done"] == true || !context.mounted) return;
      await Navigator.push(context, MaterialPageRoute(fullscreenDialog: true, builder: (_) => OnboardingScreen(initial: Json.from(r.data as Map))));
    } catch (_) {}
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _step = 0;
  late Json _d = widget.initial ?? {};
  final Set<String> _topics = {};
  final Set<String> _follow = {};
  final Set<String> _join = {};
  String _emirate = "Dubai";
  final _code = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _topics.addAll((_d["interests"] as List? ?? []).map((e) => e.toString()));
    if (_d.isEmpty) {
      ApiService.dio.get("/onboarding").then((r) {
        if (mounted) setState(() => _d = Json.from(r.data as Map));
      });
    }
  }

  @override
  void dispose() {
    _page.dispose();
    _code.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < 3) {
      setState(() => _step++);
      _page.animateToPage(_step, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      final r = await ApiService.dio.post("/onboarding", data: {
        "interests": _topics.toList(),
        "emirate": _emirate,
        "follow": _follow.toList(),
        "join": _join.toList(),
        if (_code.text.trim().isNotEmpty) "referralCode": _code.text.trim(),
      });
      final ref = r.data["referral"];
      if (!mounted) return;
      if (ref is Map && ref["message"] != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref["message"].toString())));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _header(String title, String sub) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, height: 1.15, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Text(sub, style: TextStyle(color: AppColors.subtitle, fontSize: 15, height: 1.4)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final topics = _maps(_d["topics"]);
    final creators = _maps(_d["creators"]);
    final communities = _maps(_d["communities"]);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        automaticallyImplyLeading: false,
        title: Row(children: [
          for (var i = 0; i < 4; i++)
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 5,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(color: i <= _step ? AppColors.joy : AppColors.border, borderRadius: BorderRadius.circular(3)),
              ),
            ),
        ]),
        actions: [TextButton(onPressed: _saving ? null : _finish, child: Text(tr("Skip")))],
      ),
      body: PageView(controller: _page, physics: const NeverScrollableScrollPhysics(), children: [
        ListView(children: [
          _header(tr("What do you care about?"), tr("Pick a few. Your feed, companion and challenges will follow your interests.")),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(spacing: 10, runSpacing: 10, children: [
              for (final t in topics)
                FilterChip(
                  avatar: Text(t["emoji"].toString(), style: const TextStyle(fontSize: 18)),
                  label: Text(tr(t["label"].toString())),
                  selected: _topics.contains(t["key"]),
                  showCheckmark: false,
                  selectedColor: AppColors.blush,
                  side: BorderSide(color: _topics.contains(t["key"]) ? AppColors.joy : AppColors.border, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  onSelected: (v) => setState(() => v ? _topics.add(t["key"].toString()) : _topics.remove(t["key"])),
                ),
            ]),
          ),
        ]),
        ListView(children: [
          _header(tr("Where are you in the UAE?"), tr("We'll show campaigns, events and pickups near you.")),
          for (final e in _emirates)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              child: Material(
                color: _emirate == e ? AppColors.blush : const Color(0xFFF8F5F2),
                borderRadius: BorderRadius.circular(16),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: Icon(Icons.location_city_rounded, color: _emirate == e ? AppColors.joy : AppColors.subtitle),
                  title: Text(e, style: const TextStyle(fontWeight: FontWeight.w700)),
                  trailing: _emirate == e ? const Icon(Icons.check_circle_rounded, color: AppColors.joy) : null,
                  onTap: () => setState(() => _emirate = e),
                ),
              ),
            ),
        ]),
        ListView(children: [
          _header(tr("Follow creators & join communities"), tr("Start with people and groups doing great things.")),
          if (creators.isNotEmpty)
            SizedBox(
              height: 150,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
                for (final c in creators)
                  Container(
                    width: 120,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
                    child: Column(children: [
                      UserAvatar(imageUrl: c["profileImage"]?.toString(), name: c["name"]?.toString(), radius: 26),
                      const SizedBox(height: 6),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Flexible(child: Text(c["name"].toString().split(" ").first, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
                        VerifiedTick(c["verifiedBadge"]?.toString() ?? "", size: 13),
                      ]),
                      const Spacer(),
                      SizedBox(
                        height: 30,
                        child: _follow.contains(c["_id"])
                            ? OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 10)), onPressed: () => setState(() => _follow.remove(c["_id"])), child: Text(tr("Following"), style: const TextStyle(fontSize: 12)))
                            : FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 14)), onPressed: () => setState(() => _follow.add(c["_id"].toString())), child: Text(tr("Follow"), style: const TextStyle(fontSize: 12))),
                      ),
                    ]),
                  ),
              ]),
            ),
          const SizedBox(height: 10),
          for (final c in communities)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              child: CheckboxListTile(
                value: _join.contains(c["_id"]),
                onChanged: (v) => setState(() => v == true ? _join.add(c["_id"].toString()) : _join.remove(c["_id"])),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.border)),
                secondary: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: (c["coverImage"] ?? "").toString().isEmpty ? Container(color: AppColors.eco) : CachedNetworkImage(imageUrl: c["coverImage"].toString(), fit: BoxFit.cover),
                  ),
                ),
                title: Text(c["name"].toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text("${tr(c["category"].toString())} · ${c["members"]} ${tr("members")}"),
              ),
            ),
        ]),
        ListView(children: [
          _header(tr("Got an invite code?"), tr("Enter a friend's code — you'll both get bonus points after your first verified action.")),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.card_giftcard_rounded), hintText: tr("e.g. SARA482 (optional)")),
            ),
          ),
          const SizedBox(height: 30),
          const Center(child: Text("🌱", style: TextStyle(fontSize: 70))),
          const SizedBox(height: 10),
          Center(child: Text(tr("You're all set!"), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
        ]),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: _saving || (_step == 0 && _topics.isEmpty) ? null : _next,
            child: Text(_step < 3 ? (_step == 0 && _topics.isEmpty ? tr("Pick at least one") : tr("Continue")) : tr("Start my journey"), style: const TextStyle(fontSize: 16)),
          ),
        ),
      ),
    );
  }
}

/// Invite friends: personal code and link, progress and top inviters.
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  Json? _d;
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ApiService.dio.get("/referrals");
      if (mounted) setState(() => _d = Json.from(r.data as Map));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _claim() async {
    try {
      final r = await ApiService.dio.post("/referrals/claim", data: {"code": _code.text.trim()});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.data["message"].toString())));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Scaffold(
      appBar: AppBar(title: Text(tr("Invite friends"))),
      body: d == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), gradient: const LinearGradient(colors: [Color(0xFFE36A4A), Color(0xFFF2B544)])),
                child: Column(children: [
                  const Text("🎁", style: TextStyle(fontSize: 46)),
                  const SizedBox(height: 6),
                  Text("${tr("Give")} ${d["bonus"]}, ${tr("get")} ${d["bonus"]}", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(tr("When a friend joins with your code and completes their first verified action, you both earn Eco Points."),
                      textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, height: 1.4)),
                  const SizedBox(height: 18),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: d["code"].toString()));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr("Code copied"))));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(d["code"].toString(), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 3, color: AppColors.ink)),
                        const SizedBox(width: 10),
                        Icon(Icons.copy_rounded, color: AppColors.subtitle),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.inkFixed),
                    onPressed: () => SharePlus.instance.share(ShareParams(
                      text: "${tr("Join me on GreenifyX — the UAE's eco app! Use my code")} ${d["code"]} ${tr("and we both get bonus points")} 🌱\n${d["link"]}",
                    )),
                    icon: const Icon(Icons.ios_share_rounded),
                    label: Text(tr("Share invite")),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _Stat("${d["invited"]}", tr("Joined"))),
                const SizedBox(width: 10),
                Expanded(child: _Stat("${d["rewarded"]}", tr("Took action"))),
                const SizedBox(width: 10),
                Expanded(child: _Stat("+${d["pointsEarned"]}", tr("Points earned"))),
              ]),
              if (d["canEnterCode"] == true) ...[
                const SizedBox(height: 20),
                Text(tr("Got a friend's code?"), style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextField(controller: _code, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(hintText: tr("Enter code")))),
                  const SizedBox(width: 10),
                  FilledButton(onPressed: _claim, child: Text(tr("Apply"))),
                ]),
              ],
              if (_maps(d["leaders"]).isNotEmpty) ...[
                const SizedBox(height: 22),
                Text(tr("Top inviters"), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                for (final (i, l) in _maps(d["leaders"]).indexed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(backgroundColor: i == 0 ? AppColors.sun : AppColors.blush, child: Text("${i + 1}", style: const TextStyle(fontWeight: FontWeight.w900))),
                    title: Text(l["name"]?.toString() ?? ""),
                    trailing: Text("${l["invites"]} ${tr("invites")}", style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
              ],
            ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final String v;
  final String l;
  const _Stat(this.v, this.l);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
        child: Column(children: [
          Text(v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          Text(l, style: TextStyle(color: AppColors.subtitle, fontSize: 12.5)),
        ]),
      );
}

/// Home card: streak flame, freezes and buying another freeze.
class StreakCard extends StatefulWidget {
  const StreakCard({super.key});

  @override
  State<StreakCard> createState() => _StreakCardState();
}

class _StreakCardState extends State<StreakCard> {
  Json? _s;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ApiService.dio.get("/streak");
      if (mounted) setState(() => _s = Json.from(r.data as Map));
    } catch (_) {}
  }

  Future<void> _buy() async {
    try {
      await ApiService.dio.post("/streak/freeze");
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr("Streak freeze added ❄️"))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    if (s == null) return const SizedBox.shrink();
    final streak = (s["streak"] as num?)?.toInt() ?? 0;
    final atRisk = s["atRisk"] == true;
    final done = s["doneToday"] == true;
    final freezes = (s["freezes"] as num?)?.toInt() ?? 0;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: atRisk ? const Color(0xFFFFF1E6) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: atRisk ? Border.all(color: const Color(0xFFFF9F43), width: 1.5) : null,
      ),
      child: Row(children: [
        Text(streak > 0 ? "🔥" : "🌱", style: const TextStyle(fontSize: 38)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(streak > 0 ? "$streak ${tr("day streak")}" : tr("Start a streak today"), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            Text(
              done ? tr("Done for today — great job!") : atRisk ? tr("Post one verified action today to keep it!") : tr("One verified action a day builds your streak."),
              style: TextStyle(color: atRisk ? const Color(0xFFB85C00) : AppColors.subtitle, fontWeight: atRisk ? FontWeight.w700 : FontWeight.w500, fontSize: 12.5),
            ),
            const SizedBox(height: 6),
            Row(children: [
              for (var i = 0; i < 3; i++) Padding(padding: const EdgeInsets.only(right: 3), child: Text("❄️", style: TextStyle(fontSize: 15, color: i < freezes ? null : Colors.black12))),
              const SizedBox(width: 4),
              Text("$freezes ${tr("freezes")}", style: TextStyle(color: AppColors.subtitle, fontSize: 12)),
            ]),
          ]),
        ),
        if (freezes < 3) TextButton(onPressed: _buy, child: Text("+❄️ ${s["freezeCost"]} ${tr("pts")}")),
      ]),
    );
  }
}

/// Ask for a verified badge (creator, organisation, verifier or official).
class BadgeRequestScreen extends StatefulWidget {
  const BadgeRequestScreen({super.key});

  @override
  State<BadgeRequestScreen> createState() => _BadgeRequestScreenState();
}

class _BadgeRequestScreenState extends State<BadgeRequestScreen> {
  Json? _d;
  String _type = "creator";
  final _note = TextEditingController();
  final _links = TextEditingController();

  @override
  void initState() {
    super.initState();
    ApiService.dio.get("/badges/me").then((r) {
      if (mounted) setState(() => _d = Json.from(r.data as Map));
    });
  }

  Future<void> _send() async {
    try {
      final r = await ApiService.dio.post("/badges/request", data: {"type": _type, "note": _note.text.trim(), "links": _links.text.trim()});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.data["message"].toString())));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final badge = d?["verifiedBadge"]?.toString() ?? "";
    final req = d?["request"] is Map ? Json.from(d!["request"] as Map) : null;
    return Scaffold(
      appBar: AppBar(title: Text(tr("Get verified"))),
      body: d == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(20), children: [
              const Icon(Icons.verified_rounded, color: Color(0xFF1D9BF0), size: 64),
              const SizedBox(height: 10),
              if (badge.isNotEmpty)
                Text("${tr("You're verified as")} ${tr(badge)} ✔", textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))
              else if (req?["status"] == "pending")
                Text(tr("Your request is being reviewed. We'll notify you soon."), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))
              else ...[
                Text(tr("A verified badge shows people your account is authentic."), textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.4)),
                const SizedBox(height: 18),
                for (final t in const [
                  ("creator", "Creator", "10+ followers and 5+ posts"),
                  ("organisation", "Organisation", "A registered company, school or NGO"),
                  ("verifier", "Field verifier", "Authorised to verify campaigns"),
                  ("official", "Official", "Government or public entity"),
                ])
                  Card(
                    child: ListTile(
                      leading: Icon(_type == t.$1 ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: AppColors.joy),
                      title: Text(tr(t.$2), style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(tr(t.$3)),
                      onTap: () => setState(() => _type = t.$1),
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(controller: _note, maxLines: 3, decoration: InputDecoration(labelText: tr("Why should we verify you?"))),
                const SizedBox(height: 12),
                TextField(controller: _links, decoration: InputDecoration(labelText: tr("Links (website, Instagram, LinkedIn)"))),
                const SizedBox(height: 20),
                FilledButton(onPressed: _send, child: Text(tr("Send request"))),
              ],
            ]),
    );
  }
}
