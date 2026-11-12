import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/i18n/app_locale.dart';
import '../../core/services/session_user.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/widgets/user_avatar.dart';
import '../events/events_screen.dart';
import '../feed/domain/models/feed_model.dart';
import '../feed/presentation/widgets/post_card.dart';
import '../post/domain/eco_activity.dart';
import '../post/presentation/screens/create_post_screen.dart';
import '../social/social_api.dart';
import 'group_chat_screen.dart';

const _cats = ["Neighbourhood", "Beach & Ocean", "Trees & Gardens", "Zero Waste", "Cycling & Transport", "Wildlife", "Schools & Youth", "Energy", "Other"];
const _emirates = ["Abu Dhabi", "Dubai", "Sharjah", "Ajman", "Umm Al Quwain", "Ras Al Khaimah", "Fujairah"];

IconData categoryIcon(String c) => switch (c) {
      "Beach & Ocean" => Icons.beach_access_rounded,
      "Trees & Gardens" => Icons.park_rounded,
      "Zero Waste" => Icons.recycling_rounded,
      "Cycling & Transport" => Icons.pedal_bike_rounded,
      "Wildlife" => Icons.pets_rounded,
      "Schools & Youth" => Icons.school_rounded,
      "Energy" => Icons.bolt_rounded,
      "Neighbourhood" => Icons.holiday_village_rounded,
      _ => Icons.groups_rounded,
    };

/// Discover and join communities, or create your own.
class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> {
  List<Json>? _items;
  String? _cat;
  String _q = "";
  bool _mine = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await SocialApi.communities(category: _cat, q: _q.isEmpty ? null : _q, mine: _mine);
      if (mounted) setState(() => _items = maps(r["communities"]));
    } catch (e) {
      if (mounted) {
        setState(() => _items = []);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  Future<void> _create() async {
    final made = await showModalBottomSheet<Json>(context: context, isScrollControlled: true, builder: (_) => const _CreateCommunitySheet());
    if (made != null && mounted) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => CommunityDetailScreen(id: made["_id"].toString())));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr("Communities")),
        actions: [
          IconButton(
            tooltip: tr("Creator analytics"),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatorAnalyticsScreen())),
            icon: const Icon(Icons.insights_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.add_rounded), label: Text(tr("Create"))),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
          TextField(
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: tr("Search communities")),
            onSubmitted: (v) {
              _q = v.trim();
              _load();
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(tr("Joined")),
                  selected: _mine,
                  onSelected: (v) {
                    setState(() => _mine = v);
                    _load();
                  },
                ),
              ),
              for (final c in [null, ..._cats])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c == null ? tr("All") : tr(c)),
                    selected: _cat == c,
                    onSelected: (_) {
                      setState(() => _cat = c);
                      _load();
                    },
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 14),
          if (_items == null) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
          if (_items != null && _items!.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(children: [
                const Icon(Icons.groups_rounded, size: 56, color: AppColors.subtitle),
                const SizedBox(height: 10),
                Text(tr("No communities here yet. Start the first one!"), textAlign: TextAlign.center),
              ]),
            ),
          for (final c in _items ?? <Json>[])
            _CommunityTile(c: c, onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => CommunityDetailScreen(id: c["_id"].toString())));
              _load();
            }),
        ]),
      ),
    );
  }
}

class _CommunityTile extends StatelessWidget {
  final Json c;
  final VoidCallback onTap;
  const _CommunityTile({required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cover = (c["coverImage"] ?? "").toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Row(children: [
            SizedBox(
              width: 92,
              height: 92,
              child: cover.isEmpty
                  ? Container(
                      decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.eco, Color(0xFF4CC9A0)])),
                      child: Icon(categoryIcon(c["category"].toString()), color: Colors.white, size: 36),
                    )
                  : CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c["name"]?.toString() ?? "", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                  const SizedBox(height: 2),
                  Text("${tr(c["category"].toString())}${(c["emirate"] ?? "").toString().isEmpty ? "" : " · ${c["emirate"]}"}",
                      style: const TextStyle(color: AppColors.subtitle, fontSize: 12.5)),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.people_alt_rounded, size: 15, color: AppColors.subtitle),
                    const SizedBox(width: 4),
                    Text("${c["members"]}", style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                    if (((c["activeChallenges"] as num?) ?? 0) > 0) ...[
                      const SizedBox(width: 12),
                      const Icon(Icons.flag_rounded, size: 15, color: AppColors.joy),
                      const SizedBox(width: 4),
                      Text("${c["activeChallenges"]} ${tr("live")}", style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.joy)),
                    ],
                  ]),
                ]),
              ),
            ),
            if (c["isMember"] == true) const Padding(padding: EdgeInsets.only(right: 14), child: Icon(Icons.check_circle_rounded, color: AppColors.eco)),
          ]),
        ),
      ),
    );
  }
}

class _CreateCommunitySheet extends StatefulWidget {
  const _CreateCommunitySheet();

  @override
  State<_CreateCommunitySheet> createState() => _CreateCommunitySheetState();
}

class _CreateCommunitySheetState extends State<_CreateCommunitySheet> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  String _cat = "Neighbourhood";
  String _emirate = "Dubai";
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final c = await SocialApi.createCommunity({"name": _name.text.trim(), "description": _desc.text.trim(), "category": _cat, "emirate": _emirate});
      if (mounted) Navigator.pop(context, c);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr("Start a community"), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        TextField(controller: _name, decoration: InputDecoration(labelText: tr("Community name"))),
        const SizedBox(height: 12),
        TextField(controller: _desc, maxLines: 3, decoration: InputDecoration(labelText: tr("What is it about?"))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _cat,
              isExpanded: true,
              decoration: InputDecoration(labelText: tr("Category")),
              items: [for (final c in _cats) DropdownMenuItem(value: c, child: Text(tr(c)))],
              onChanged: (v) => setState(() => _cat = v ?? _cat),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _emirate,
              isExpanded: true,
              decoration: InputDecoration(labelText: tr("Emirate")),
              items: [for (final e in _emirates) DropdownMenuItem(value: e, child: Text(e))],
              onChanged: (v) => setState(() => _emirate = v ?? _emirate),
            ),
          ),
        ]),
        const SizedBox(height: 18),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? "…" : tr("Create community"))),
      ]),
    );
  }
}

/// One community: join, chat, post, challenges, events, members.
class CommunityDetailScreen extends StatefulWidget {
  final String id;
  const CommunityDetailScreen({super.key, required this.id});

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  Json? _c;
  List<Json> _posts = [];
  List<Json> _events = [];
  List<Json> _challenges = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await SocialApi.community(widget.id);
      if (!mounted) return;
      setState(() {
        _c = Json.from(r["community"] as Map);
        _posts = maps(r["posts"]);
        _events = maps(r["events"]);
        _challenges = maps(r["challenges"]);
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _join() async {
    try {
      await SocialApi.joinCommunity(widget.id);
      _load();
    } catch (e) {
      _snack(friendlyError(e));
    }
  }

  Future<void> _hostChallenge() async {
    final activities = await EcoActivityApi.load();
    if (!mounted) return;
    final ok = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => _HostChallengeSheet(id: widget.id, activities: activities));
    if (ok == true) _load();
  }

  Future<void> _hostEvent() async {
    final ok = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => _HostEventSheet(id: widget.id));
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (_error != null) return Scaffold(appBar: AppBar(), body: Center(child: TextButton(onPressed: _load, child: Text(_error!))));
    if (c == null) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    final member = c["isMember"] == true;
    final manage = c["canManage"] == true;
    final cover = (c["coverImage"] ?? "").toString();
    final meId = SessionUser.id;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (_, _) => [
            SliverAppBar(
              pinned: true,
              expandedHeight: 230,
              foregroundColor: Colors.white,
              backgroundColor: AppColors.eco,
              actions: [
                if (manage)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    onSelected: (v) => v == "challenge" ? _hostChallenge() : _hostEvent(),
                    itemBuilder: (_) => [
                      PopupMenuItem(value: "challenge", child: Text(tr("Host a challenge"))),
                      PopupMenuItem(value: "event", child: Text(tr("Organise an event"))),
                    ],
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(fit: StackFit.expand, children: [
                  if (cover.isNotEmpty)
                    CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover)
                  else
                    Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0E5A3A), AppColors.eco, Color(0xFF4CC9A0)]))),
                  const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black26, Colors.black54]))),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 62,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(categoryIcon(c["category"].toString()), color: AppColors.sun, size: 18),
                        const SizedBox(width: 6),
                        Text(tr(c["category"].toString()), style: const TextStyle(color: AppColors.sun, fontWeight: FontWeight.w800)),
                      ]),
                      const SizedBox(height: 4),
                      Text(c["name"].toString(), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                      Text("${c["members"]} ${tr("members")}${(c["emirate"] ?? "").toString().isEmpty ? "" : " · ${c["emirate"]}"}",
                          style: const TextStyle(color: Colors.white70)),
                    ]),
                  ),
                ]),
              ),
              bottom: TabBar(
                isScrollable: true,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: AppColors.sun,
                tabs: [Tab(text: tr("Posts")), Tab(text: tr("Challenges")), Tab(text: tr("Events")), Tab(text: tr("About"))],
              ),
            ),
          ],
          body: TabBarView(children: [
            RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.only(top: 8, bottom: 90), children: [
                if (_posts.isEmpty) Padding(padding: const EdgeInsets.all(40), child: Center(child: Text(tr("No posts yet"), style: const TextStyle(color: AppColors.subtitle)))),
                for (final p in _posts) PostCard(key: ValueKey(p["_id"]), post: FeedModel.fromJson(p), meId: meId),
              ]),
            ),
            ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 90), children: [
              if (_challenges.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(children: [
                    Text(tr("No challenges yet"), style: const TextStyle(color: AppColors.subtitle)),
                    if (manage) TextButton(onPressed: _hostChallenge, child: Text(tr("Host a challenge"))),
                  ]),
                ),
              for (final ch in _challenges) _ChallengeCard(ch: ch, member: member, communityId: widget.id, onChanged: _load),
            ]),
            ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 90), children: [
              if (_events.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(children: [
                    Text(tr("No upcoming events"), style: const TextStyle(color: AppColors.subtitle)),
                    if (manage) TextButton(onPressed: _hostEvent, child: Text(tr("Organise an event"))),
                  ]),
                ),
              for (final e in _events)
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: AppColors.blush, child: Icon(Icons.event_rounded, color: AppColors.joy)),
                    title: Text(e["title"].toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text("${DateFormat("EEE d MMM, h:mm a").format(DateTime.parse(e["startsAt"].toString()).toLocal())} · ${e["venue"] ?? ""}"),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => EventDetailScreen(event: {...e, "attendeeCount": (e["attendees"] as List?)?.length ?? 0, "going": (e["attendees"] as List?)?.contains(meId) == true})),
                    ),
                  ),
                ),
            ]),
            ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 90), children: [
              if ((c["description"] ?? "").toString().isNotEmpty) Text(c["description"].toString(), style: const TextStyle(fontSize: 15, height: 1.5)),
              const SizedBox(height: 16),
              Text(tr("Host"), style: const TextStyle(fontWeight: FontWeight.w800)),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: UserAvatar(imageUrl: (c["owner"] as Map?)?["profileImage"]?.toString(), name: (c["owner"] as Map?)?["name"]?.toString()),
                title: Text((c["owner"] as Map?)?["name"]?.toString() ?? ""),
              ),
              Text(tr("Members"), style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Wrap(spacing: 10, runSpacing: 10, children: [
                for (final m in maps(c["memberPreview"]))
                  SizedBox(
                    width: 64,
                    child: Column(children: [
                      UserAvatar(imageUrl: m["profileImage"]?.toString(), name: m["name"]?.toString(), radius: 24),
                      Text(m["name"].toString().split(" ").first, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5)),
                    ]),
                  ),
              ]),
            ]),
          ]),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: member
                ? Row(children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupChatScreen(communityId: widget.id, name: c["name"].toString()))),
                        icon: const Icon(Icons.forum_rounded),
                        label: Text(tr("Group chat")),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => CreatePostScreen(communityId: widget.id)));
                          _load();
                        },
                        icon: const Icon(Icons.add_a_photo_rounded),
                        label: Text(tr("Post here")),
                      ),
                    ),
                    if (!manage) IconButton(tooltip: tr("Leave"), onPressed: _join, icon: const Icon(Icons.logout_rounded)),
                  ])
                : FilledButton.icon(onPressed: _join, icon: const Icon(Icons.group_add_rounded), label: Text(tr("Join community"))),
          ),
        ),
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final Json ch;
  final bool member;
  final String communityId;
  final VoidCallback onChanged;
  const _ChallengeCard({required this.ch, required this.member, required this.communityId, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final target = (ch["target"] as num).toInt();
    final mine = (ch["myProgress"] as num?)?.toInt() ?? 0;
    final ends = DateTime.tryParse(ch["endsAt"].toString())?.toLocal();
    final ended = ends != null && ends.isBefore(DateTime.now());
    final left = ends?.difference(DateTime.now());
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.flag_rounded, color: AppColors.joy),
          const SizedBox(width: 8),
          Expanded(child: Text(ch["title"].toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          Text("+${ch["rewardPoints"]}", style: const TextStyle(color: AppColors.eco, fontWeight: FontWeight.w800)),
        ]),
        if ((ch["description"] ?? "").toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(ch["description"].toString())),
        const SizedBox(height: 8),
        Text(
          "${target}× ${(ch["activity"] ?? "").toString().isEmpty ? tr("any eco action") : ch["activity"]} · ${ch["participants"]} ${tr("joined")} · ${ended ? tr("Ended") : left!.inDays > 0 ? "${left.inDays}d ${tr("left")}" : "${left.inHours}h ${tr("left")}"}",
          style: const TextStyle(color: AppColors.subtitle, fontSize: 12.5),
        ),
        if (ch["joined"] == true) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: (mine / target).clamp(0, 1).toDouble(), minHeight: 8, color: AppColors.eco, backgroundColor: AppColors.border),
          ),
          const SizedBox(height: 6),
          Text(ch["completed"] == true ? "✅ ${tr("Completed")}" : "$mine / $target", style: const TextStyle(fontWeight: FontWeight.w700)),
        ] else if (member && !ended) ...[
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () async {
              try {
                await SocialApi.joinChallenge(communityId, ch["_id"].toString());
                onChanged();
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
              }
            },
            child: Text(tr("Join challenge")),
          ),
        ],
      ]),
    );
  }
}

class _HostChallengeSheet extends StatefulWidget {
  final String id;
  final List<EcoActivity> activities;
  const _HostChallengeSheet({required this.id, required this.activities});

  @override
  State<_HostChallengeSheet> createState() => _HostChallengeSheetState();
}

class _HostChallengeSheetState extends State<_HostChallengeSheet> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String _activity = "";
  double _target = 5;
  double _days = 7;
  double _reward = 50;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr("Host a challenge"), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TextField(controller: _title, decoration: InputDecoration(labelText: tr("Title"), hintText: tr("e.g. Plastic-free week"))),
          const SizedBox(height: 12),
          TextField(controller: _desc, maxLines: 2, decoration: InputDecoration(labelText: tr("Details (optional)"))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _activity,
            isExpanded: true,
            decoration: InputDecoration(labelText: tr("Counts which activity?")),
            items: [
              DropdownMenuItem(value: "", child: Text(tr("Any eco action"))),
              for (final a in widget.activities) DropdownMenuItem(value: a.name, child: Text(a.label)),
            ],
            onChanged: (v) => setState(() => _activity = v ?? ""),
          ),
          const SizedBox(height: 10),
          Text("${tr("Target")}: ${_target.round()} ${tr("posts")}"),
          Slider(value: _target, min: 1, max: 30, divisions: 29, onChanged: (v) => setState(() => _target = v)),
          Text("${tr("Duration")}: ${_days.round()} ${tr("days")}"),
          Slider(value: _days, min: 1, max: 30, divisions: 29, onChanged: (v) => setState(() => _days = v)),
          Text("${tr("Reward")}: ${_reward.round()} ${tr("Eco Points")}"),
          Slider(value: _reward, min: 0, max: 200, divisions: 20, onChanged: (v) => setState(() => _reward = v)),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    try {
                      await SocialApi.hostChallenge(widget.id, {
                        "title": _title.text.trim(),
                        "description": _desc.text.trim(),
                        "activity": _activity,
                        "target": _target.round(),
                        "days": _days.round(),
                        "rewardPoints": _reward.round(),
                      });
                      if (context.mounted) Navigator.pop(context, true);
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                    } finally {
                      if (mounted) setState(() => _saving = false);
                    }
                  },
            child: Text(tr("Launch challenge")),
          ),
        ]),
      ),
    );
  }
}

class _HostEventSheet extends StatefulWidget {
  final String id;
  const _HostEventSheet({required this.id});

  @override
  State<_HostEventSheet> createState() => _HostEventSheetState();
}

class _HostEventSheetState extends State<_HostEventSheet> {
  final _title = TextEditingController();
  final _venue = TextEditingController();
  final _desc = TextEditingController();
  String _cat = "cleanup";
  DateTime _start = DateTime.now().add(const Duration(days: 3)).copyWith(hour: 8, minute: 0);
  double _hours = 2;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr("Organise an event"), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TextField(controller: _title, decoration: InputDecoration(labelText: tr("Title"))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _cat,
            decoration: InputDecoration(labelText: tr("Type")),
            items: [for (final c in const ["cleanup", "planting", "workshop", "talk", "market", "other"]) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: (v) => setState(() => _cat = v ?? _cat),
          ),
          const SizedBox(height: 12),
          TextField(controller: _venue, decoration: InputDecoration(labelText: tr("Venue"))),
          const SizedBox(height: 6),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_rounded),
            title: Text(DateFormat("EEE d MMM, h:mm a").format(_start)),
            trailing: const Icon(Icons.edit_calendar_rounded),
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _start, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 180)));
              if (d == null || !context.mounted) return;
              final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_start));
              if (t != null) setState(() => _start = DateTime(d.year, d.month, d.day, t.hour, t.minute));
            },
          ),
          Text("${tr("Duration")}: ${_hours.round()}h"),
          Slider(value: _hours, min: 1, max: 8, divisions: 7, onChanged: (v) => setState(() => _hours = v)),
          TextField(controller: _desc, maxLines: 3, decoration: InputDecoration(labelText: tr("Details (optional)"))),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    try {
                      await SocialApi.hostEvent(widget.id, {
                        "title": _title.text.trim(),
                        "category": _cat,
                        "venue": _venue.text.trim(),
                        "description": _desc.text.trim(),
                        "startsAt": _start.toUtc().toIso8601String(),
                        "hours": _hours.round(),
                      });
                      if (context.mounted) Navigator.pop(context, true);
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                    } finally {
                      if (mounted) setState(() => _saving = false);
                    }
                  },
            child: Text(tr("Publish event")),
          ),
        ]),
      ),
    );
  }
}

/// Last 30 days for the creator: reach, engagement, top posts.
class CreatorAnalyticsScreen extends StatefulWidget {
  const CreatorAnalyticsScreen({super.key});

  @override
  State<CreatorAnalyticsScreen> createState() => _CreatorAnalyticsScreenState();
}

class _CreatorAnalyticsScreenState extends State<CreatorAnalyticsScreen> {
  Json? _d;

  @override
  void initState() {
    super.initState();
    SocialApi.analytics().then((d) {
      if (mounted) setState(() => _d = d);
    }).catchError((e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final s = Json.from((d?["summary"] ?? {}) as Map);
    final daily = maps(d?["daily"]);
    final maxLikes = daily.fold<num>(1, (m, x) => (x["likes"] as num) > m ? x["likes"] as num : m);
    Widget kpi(String label, Object? v, IconData icon, Color c) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: c),
            const SizedBox(height: 10),
            Text("${v ?? 0}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(color: AppColors.subtitle, fontSize: 12.5)),
          ]),
        );
    return Scaffold(
      appBar: AppBar(title: Text(tr("Creator analytics"))),
      body: d == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Text(tr("Last 30 days"), style: const TextStyle(color: AppColors.subtitle, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.5,
                children: [
                  kpi(tr("Followers"), "${s["followers"]} (+${s["newFollowers"]})", Icons.people_alt_rounded, AppColors.joy),
                  kpi(tr("Views"), s["views30d"], Icons.visibility_rounded, const Color(0xFF3A7BD5)),
                  kpi(tr("Likes"), s["likes30d"], Icons.favorite_rounded, const Color(0xFFE8384F)),
                  kpi(tr("Comments"), s["comments30d"], Icons.mode_comment_rounded, AppColors.eco),
                  kpi(tr("Story views"), s["storyViews"], Icons.amp_stories_rounded, const Color(0xFF7F53AC)),
                  kpi(tr("Engagement"), "${s["engagementRate"]}%", Icons.trending_up_rounded, AppColors.sun),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr("Likes per day"), style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 110,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      for (final x in daily)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1.5),
                            child: Container(
                              height: 4 + 100 * ((x["likes"] as num) / maxLikes),
                              decoration: BoxDecoration(color: AppColors.joy.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(3)),
                            ),
                          ),
                        ),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 18),
              Text(tr("Top posts"), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              for (final p in maps(d["topPosts"]))
                ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  leading: const Icon(Icons.photo_rounded),
                  title: Text(p["activity"].toString()),
                  trailing: Text("❤ ${p["likes"]} · 👁 ${p["views"]}"),
                ),
              if (maps(d["communities"]).isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(tr("Your communities"), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                for (final c in maps(d["communities"])) ListTile(title: Text(c["name"].toString()), trailing: Text("${c["members"]} ${tr("members")}")),
              ],
            ]),
    );
  }
}
