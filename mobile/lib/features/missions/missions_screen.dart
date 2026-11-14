import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../core/i18n/app_locale.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/widgets/user_avatar.dart';
import '../post/domain/eco_activity.dart';
import '../post/presentation/screens/create_post_screen.dart';

typedef Json = Map<String, dynamic>;

Future<Position?> _here() async {
  try {
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return null;
    return await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 10)));
  } catch (_) {
    return null;
  }
}

/// Missions near you and this week's neighbourhood and emirate leagues.
class MissionsScreen extends StatefulWidget {
  const MissionsScreen({super.key});

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  List<Json>? _missions;
  Json? _leagues;
  List<Json> _zones = const [];
  String? _homeZone;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _toast(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Future<void> _load() async {
    final pos = await _here();
    try {
      final r = await Future.wait([
        ApiService.dio.get("/missions", queryParameters: {if (pos != null) "lat": pos.latitude, if (pos != null) "lng": pos.longitude}),
        ApiService.dio.get("/leagues"),
        ApiService.dio.get("/zones"),
        EcoActivityApi.load(),
      ]);
      if (!mounted) return;
      setState(() {
        _missions = ((r[0] as dynamic).data["missions"] as List).map((e) => Json.from(e as Map)).toList();
        _leagues = Json.from((r[1] as dynamic).data as Map);
        _zones = ((r[2] as dynamic).data["zones"] as List).map((e) => Json.from(e as Map)).toList();
        _homeZone = (r[2] as dynamic).data["homeZone"]?.toString();
      });
    } catch (e) {
      if (mounted) {
        setState(() => _missions = []);
        _toast(friendlyError(e));
      }
    }
  }

  Future<void> _setZone() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
          child: ListView(shrinkWrap: true, children: [
            ListTile(leading: const Icon(Icons.my_location_rounded), title: Text(tr("Use my location")), onTap: () => Navigator.pop(context, "__here")),
            const Divider(),
            for (final z in _zones)
              ListTile(
                title: Text(z["name"].toString()),
                subtitle: Text(tr(z["emirate"]?.toString() ?? "")),
                trailing: _homeZone == z["_id"] ? const Icon(Icons.check_circle_rounded, color: AppColors.eco) : null,
                onTap: () => Navigator.pop(context, z["_id"].toString()),
              ),
          ]),
        ),
      ),
    );
    if (choice == null) return;
    try {
      Map<String, dynamic> body;
      if (choice == "__here") {
        final pos = await _here();
        if (pos == null) return _toast(tr("Turn on location or pick your neighbourhood"));
        body = {"lat": pos.latitude, "lng": pos.longitude};
      } else {
        body = {"zoneId": choice};
      }
      final r = await ApiService.dio.post("/zones/home", data: body);
      _toast("${tr("Your neighbourhood")}: ${r.data["zone"]["name"]}");
      _load();
    } catch (e) {
      _toast(friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final missions = _missions;
    final l = _leagues;
    final zoneName = _zones.where((z) => z["_id"] == _homeZone).map((z) => z["name"].toString()).firstOrNull;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr("Missions")),
          bottom: TabBar(tabs: [Tab(text: tr("Missions")), Tab(text: tr("Leagues"))]),
        ),
        body: missions == null
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: [
                RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 30), children: [
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.home_work_rounded, color: AppColors.eco),
                        title: Text(zoneName ?? tr("Set your neighbourhood"), style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(zoneName == null ? tr("See missions and leagues for your area") : tr("Your neighbourhood")),
                        trailing: TextButton(onPressed: _setZone, child: Text(zoneName == null ? tr("Set") : tr("Change"))),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (missions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 30),
                        child: Text(tr("No missions in your area right now. We'll notify you when one starts."), textAlign: TextAlign.center, style: TextStyle(color: AppColors.subtitle)),
                      ),
                    for (final m in missions) _MissionCard(m: m),
                  ]),
                ),
                RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 30), children: [
                    Text(tr("This week"), style: TextStyle(color: AppColors.subtitle, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(tr("Neighbourhoods"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    for (final z in (l?["zones"] as List? ?? []).take(15).map((e) => Json.from(e as Map)))
                      _LeagueRow(position: z["position"] as int, name: z["name"].toString(), sub: "${z["people"]} ${tr("people")}", points: z["points"] as num, mine: z["_id"] == _homeZone),
                    const SizedBox(height: 18),
                    Text(tr("Emirates"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    for (final e in (l?["emirates"] as List? ?? []).map((e) => Json.from(e as Map)))
                      _LeagueRow(position: e["position"] as int, name: tr(e["name"].toString()), sub: "${e["people"]} ${tr("people")}", points: e["points"] as num, mine: e["name"] == l?["emirate"]),
                    if ((l?["neighbours"] as List? ?? []).isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text("${tr("Top in")} ${zoneName ?? ""}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      for (final n in (l!["neighbours"] as List).map((e) => Json.from(e as Map)))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: UserAvatar(imageUrl: n["profileImage"]?.toString(), name: n["name"]?.toString(), radius: 18),
                          title: Text("${n["position"]}. ${n["name"]}"),
                          trailing: Text("${n["points"]}", style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.eco)),
                        ),
                    ],
                  ]),
                ),
              ]),
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  final Json m;
  const _MissionCard({required this.m});

  @override
  Widget build(BuildContext context) {
    final ends = DateTime.tryParse(m["endsAt"]?.toString() ?? "")?.toLocal();
    final target = (m["targetCount"] as num?)?.toInt() ?? 0;
    final done = (m["completions"] as num?)?.toInt() ?? 0;
    final activity = m["activity"]?.toString() ?? "";
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(activityIcon(m["activityIcon"]?.toString() ?? "eco"), color: AppColors.eco),
            const SizedBox(width: 8),
            Expanded(child: Text(m["title"].toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
            Text("+${m["bonusPoints"]}", style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.eco)),
          ]),
          if ((m["description"] ?? "").toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(m["description"].toString())),
          const SizedBox(height: 8),
          Text(
            [
              if (m["zone"] is Map) (m["zone"] as Map)["name"].toString() else if ((m["emirate"] ?? "").toString().isNotEmpty) tr(m["emirate"].toString()) else tr("All UAE"),
              if (activity.isNotEmpty) activityName(activity),
              if (ends != null) "${tr("Until")} ${DateFormat("d MMM, h:mm a").format(ends)}",
            ].join(" · "),
            style: TextStyle(color: AppColors.subtitle, fontSize: 12.5),
          ),
          if (target > 0) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: (done / target).clamp(0, 1).toDouble(), minHeight: 6, color: AppColors.eco, backgroundColor: AppColors.border),
            const SizedBox(height: 4),
            Text("$done / $target ${tr("done in the area")}", style: TextStyle(color: AppColors.subtitle, fontSize: 12)),
          ],
          const SizedBox(height: 10),
          if (m["done"] == true)
            Text("✅ ${tr("You completed this mission")}", style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.eco))
          else
            FilledButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreatePostScreen(missionId: m["_id"].toString(), presetActivity: activity.isEmpty ? null : activity))),
              icon: const Icon(Icons.add_a_photo_rounded),
              label: Text(tr("Do this mission")),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(tr("The bonus is paid when your post is verified."), style: TextStyle(color: AppColors.subtitle, fontSize: 11.5)),
          ),
        ]),
      ),
    );
  }
}

class _LeagueRow extends StatelessWidget {
  final int position;
  final String name;
  final String sub;
  final num points;
  final bool mine;
  const _LeagueRow({required this.position, required this.name, required this.sub, required this.points, required this.mine});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? AppColors.eco.withValues(alpha: 0.10) : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: mine ? AppColors.eco : AppColors.border),
        ),
        child: Row(children: [
          SizedBox(width: 30, child: Text(position <= 3 ? ["🥇", "🥈", "🥉"][position - 1] : "$position", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(sub, style: TextStyle(color: AppColors.subtitle, fontSize: 12)),
            ]),
          ),
          Text("$points", style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.eco)),
        ]),
      );
}
