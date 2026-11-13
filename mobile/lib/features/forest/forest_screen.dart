import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../core/i18n/app_locale.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/friendly_error.dart';

typedef Json = Map<String, dynamic>;

const _emoji = {"ghaf": "🌳", "mangrove": "🌿", "sidr": "🌲"};

/// My Forest: fund a real native tree with Eco Points and follow it as it grows.
class ForestScreen extends StatefulWidget {
  const ForestScreen({super.key});

  @override
  State<ForestScreen> createState() => _ForestScreenState();
}

class _ForestScreenState extends State<ForestScreen> {
  Json? _d;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _toast(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Future<void> _load() async {
    try {
      final r = await ApiService.dio.get("/forest");
      if (mounted) setState(() => _d = Json.from(r.data as Map));
    } catch (e) {
      if (mounted) _toast(friendlyError(e));
    }
  }

  Future<void> _plant() async {
    final species = (_d!["species"] as List).map((e) => Json.from(e as Map)).toList();
    final available = (_d!["available"] as num?)?.toInt() ?? 0;
    final picked = await showModalBottomSheet<Json>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
          Text(tr("Fund a real tree"), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text("${tr("You have")} $available ${tr("Eco Points")}", style: TextStyle(color: AppColors.subtitle)),
          const SizedBox(height: 12),
          for (final s in species)
            Card(
              child: ListTile(
                leading: Text(_emoji[s["key"]] ?? "🌳", style: const TextStyle(fontSize: 30)),
                title: Text(tr(s["name"].toString()), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text("${tr(s["blurb"].toString())}\n≈ ${s["co2KgPerYear"]} kg CO₂ ${tr("a year")}"),
                isThreeLine: true,
                trailing: FilledButton(
                  onPressed: available >= (s["cost"] as num) ? () => Navigator.pop(context, s) : null,
                  child: Text("${s["cost"]}"),
                ),
              ),
            ),
        ]),
      ),
    );
    if (picked == null) return;
    try {
      await ApiService.dio.post("/forest/plant", data: {"species": picked["key"]});
      _toast(tr("Thank you! We'll tell you when your tree is in the ground. 🌱"));
      _load();
    } catch (e) {
      _toast(friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final s = d == null ? null : Json.from(d["summary"] as Map);
    final trees = (d?["trees"] as List? ?? []).map((e) => Json.from(e as Map)).toList();
    return Scaffold(
      appBar: AppBar(title: Text(tr("My Forest"))),
      floatingActionButton: d == null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.eco,
              foregroundColor: Colors.white,
              onPressed: _plant,
              icon: const Icon(Icons.park_rounded),
              label: Text(tr("Fund a tree")),
            ),
      body: d == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(colors: [Color(0xFF0E3B2E), Color(0xFF56AB2F)])),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(trees.isEmpty ? "🌱" : List.filled(s!["trees"].clamp(1, 8) as int, "🌳").join(), style: const TextStyle(fontSize: 28)),
                    const SizedBox(height: 10),
                    Text("${s!["trees"]} ${tr("trees in your forest")}", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      "${s["planted"]} ${tr("planted")} · ${s["waiting"]} ${tr("waiting to be planted")} · ≈ ${s["co2KgPerYear"]} kg CO₂ ${tr("a year")}",
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                Text(
                  tr("Your Eco Points fund native trees planted by our UAE partners. Each tree gets a code, a location and photo updates."),
                  style: TextStyle(color: AppColors.subtitle, height: 1.4),
                ),
                const SizedBox(height: 14),
                if (trees.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 30),
                    child: Text(tr("No trees yet. Fund your first one!"), textAlign: TextAlign.center, style: TextStyle(color: AppColors.subtitle)),
                  ),
                for (final t in trees)
                  Card(
                    child: ListTile(
                      leading: Text(_emoji[t["species"]] ?? "🌳", style: const TextStyle(fontSize: 30)),
                      title: Text(t["nickname"]?.toString().isNotEmpty == true ? t["nickname"].toString() : "${tr(_name(t["species"]))} · ${t["code"]}",
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(t["status"] == "planted" ? "${tr("Planted")}${(t["place"] ?? "").toString().isEmpty ? "" : " · ${t["place"]}"}" : tr("Waiting to be planted")),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TreeScreen(id: t["_id"].toString()))),
                    ),
                  ),
              ]),
            ),
    );
  }
}

String _name(dynamic key) => switch (key) { "ghaf" => "Ghaf", "mangrove" => "Mangrove", "sidr" => "Sidr", _ => "Tree" };

/// One tree: where it is and photo updates from the planting partner.
class TreeScreen extends StatefulWidget {
  final String id;
  const TreeScreen({super.key, required this.id});

  @override
  State<TreeScreen> createState() => _TreeScreenState();
}

class _TreeScreenState extends State<TreeScreen> {
  Json? _t;
  String? _error;

  @override
  void initState() {
    super.initState();
    ApiService.dio.get("/forest/${widget.id}").then((r) {
      if (mounted) setState(() => _t = Json.from(r.data["tree"] as Map));
    }).catchError((Object e) {
      if (mounted) setState(() => _error = friendlyError(e));
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final loc = t?["location"] is Map ? Json.from(t!["location"] as Map) : null;
    final hasLoc = loc != null && loc["lat"] is num && loc["lng"] is num;
    final updates = (t?["updates"] as List? ?? []).map((e) => Json.from(e as Map)).toList().reversed.toList();
    final planted = DateTime.tryParse(t?["plantedAt"]?.toString() ?? "")?.toLocal();
    return Scaffold(
      appBar: AppBar(title: Text(t?["code"]?.toString() ?? tr("Tree"))),
      body: t == null
          ? Center(child: _error == null ? const CircularProgressIndicator() : Text(_error!))
          : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
              Row(children: [
                Text(_emoji[t["species"]] ?? "🌳", style: const TextStyle(fontSize: 44)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr(_name(t["species"])), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    Text(
                      planted != null
                          ? "${tr("Planted")} ${DateFormat("d MMM yyyy").format(planted)}${(t["partner"] ?? "").toString().isEmpty ? "" : " ${tr("by")} ${t["partner"]}"}"
                          : tr("Waiting to be planted. Plantings happen in the cooler months."),
                      style: TextStyle(color: AppColors.subtitle),
                    ),
                  ]),
                ),
              ]),
              const SizedBox(height: 16),
              if (hasLoc)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    height: 220,
                    child: FlutterMap(
                      options: MapOptions(initialCenter: LatLng((loc["lat"] as num).toDouble(), (loc["lng"] as num).toDouble()), initialZoom: 14),
                      children: [
                        TileLayer(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png", userAgentPackageName: "com.greenifyx.app"),
                        MarkerLayer(markers: [
                          Marker(
                            point: LatLng((loc["lat"] as num).toDouble(), (loc["lng"] as num).toDouble()),
                            width: 44,
                            height: 44,
                            child: const Text("🌳", style: TextStyle(fontSize: 34)),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              if ((t["place"] ?? "").toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text("📍 ${t["place"]}")),
              const SizedBox(height: 18),
              Text(tr("Updates"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (updates.isEmpty) Text(tr("Photos from the planting partner will appear here."), style: TextStyle(color: AppColors.subtitle)),
              for (final u in updates)
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if ((u["photoUrl"] ?? "").toString().isNotEmpty)
                      AspectRatio(aspectRatio: 4 / 3, child: CachedNetworkImage(imageUrl: u["photoUrl"].toString(), fit: BoxFit.cover)),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if ((u["note"] ?? "").toString().isNotEmpty) Text(u["note"].toString()),
                        Text(DateFormat("d MMM yyyy").format(DateTime.tryParse(u["at"]?.toString() ?? "")?.toLocal() ?? DateTime.now()),
                            style: TextStyle(color: AppColors.subtitle, fontSize: 12)),
                      ]),
                    ),
                  ]),
                ),
            ]),
    );
  }
}
