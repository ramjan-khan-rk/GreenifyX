import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/widgets/app_status.dart';
import '../campaign/presentation/screens/campaign_detail_screen.dart';
import '../campaign/presentation/widgets/campaign_visuals.dart';
import '../issues/presentation/issue_widgets.dart';
import 'package:greenifyx/core/i18n/app_locale.dart';

/// One pin on the map, normalised across campaigns, reports and places.
class MapPin {
  final String id;
  final String layer; // campaign | issue | place
  final String title;
  final String subtitle;
  final String category;
  final LatLng point;
  final bool official;
  final List<String> details;

  const MapPin({
    required this.id,
    required this.layer,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.point,
    this.official = false,
    this.details = const [],
  });
}

final mapPinsProvider = FutureProvider<List<MapPin>>((ref) async {
  final res = await ApiService.dio.get("/map");
  final data = Map<String, dynamic>.from(res.data as Map);
  LatLng at(dynamic loc) => LatLng((loc["lat"] as num).toDouble(), (loc["lng"] as num).toDouble());
  final pins = <MapPin>[];
  for (final c in (data["campaigns"] as List? ?? const []).whereType<Map>()) {
    final phase = c["phase"]?.toString() ?? "";
    pins.add(MapPin(
      id: c["_id"].toString(),
      layer: "campaign",
      title: c["title"]?.toString() ?? "",
      subtitle: "${c["locationName"]} · ${c["emirate"]}",
      category: c["category"]?.toString() ?? "",
      point: at(c["location"]),
      details: [
        switch (phase) {
          "live" => "Happening now",
          "upcoming" => "Upcoming",
          "completed" => "Completed",
          _ => "Ended",
        },
        "+${c["pointsPerParticipant"]} Eco Points",
        if (phase == "live" || phase == "upcoming") "${c["spotsLeft"]} spots left",
        if ((c["verifiedOutput"] as num? ?? 0) > 0) "${c["verifiedOutput"]} ${c["outputUnit"]} verified",
      ],
    ));
  }
  for (final r in (data["issues"] as List? ?? const []).whereType<Map>()) {
    final landmark = r["landmark"]?.toString() ?? "";
    pins.add(MapPin(
      id: r["_id"].toString(),
      layer: "issue",
      title: r["category"]?.toString() ?? "Reported problem",
      subtitle: [if (landmark.isNotEmpty) landmark, r["emirate"]?.toString() ?? ""].where((s) => s.isNotEmpty).join(" · "),
      category: r["category"]?.toString() ?? "",
      point: at(r["location"]),
      details: [
        switch (r["status"]) {
          "under_review" => "Under review",
          "forwarded" => "Shared with partner",
          _ => "Reported",
        },
        if ((r["confirmations"] as num? ?? 0) > 0) "${r["confirmations"]} residents confirmed",
      ],
    ));
  }
  for (final p in (data["places"] as List? ?? const []).whereType<Map>()) {
    pins.add(MapPin(
      id: p["_id"].toString(),
      layer: "place",
      title: p["name"]?.toString() ?? "",
      subtitle: [p["type"], p["emirate"]].where((s) => s != null && s.toString().isNotEmpty).join(" · "),
      category: p["type"]?.toString() ?? "",
      point: at(p["location"]),
      official: p["verified"] == true,
      details: [
        if ((p["hours"]?.toString() ?? "").isNotEmpty) p["hours"].toString(),
        if ((p["acceptedMaterials"] as List? ?? const []).isNotEmpty) "Accepts ${(p["acceptedMaterials"] as List).join(", ")}",
      ],
    ));
  }
  return pins;
});

const _layers = [
  ("campaign", "Campaigns", Icons.forest_rounded, AppColors.eco),
  ("place", "Recycle & refill", Icons.recycling_rounded, Color(0xFF4A78B5)),
  ("issue", "Reported issues", Icons.report_gmailerrorred_rounded, AppColors.primary),
];

IconData _pinIcon(MapPin p) {
  if (p.layer == "campaign") return categoryStyle(p.category).icon;
  if (p.layer == "issue") return issueIcon(p.category);
  return switch (p.category) {
    "Water Refill" => Icons.water_drop_rounded,
    "E-waste Drop-off" => Icons.devices_other_rounded,
    "Recycling Bin" => Icons.delete_outline_rounded,
    _ => Icons.recycling_rounded,
  };
}

Color _pinColor(MapPin p) => _layers.firstWhere((l) => l.$1 == p.layer).$4;

class EcoMapScreen extends ConsumerStatefulWidget {
  const EcoMapScreen({super.key});

  @override
  ConsumerState<EcoMapScreen> createState() => _EcoMapScreenState();
}

class _EcoMapScreenState extends ConsumerState<EcoMapScreen> {
  final _map = MapController();
  final Set<String> _visible = {"campaign", "place", "issue"};
  MapPin? _selected;
  LatLng? _me;

  static const _uae = LatLng(24.75, 55.0);

  Future<void> _locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 15)),
      );
      final me = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() => _me = me);
      _map.move(me, 12);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr("Could not find your location"))));
      }
    }
  }

  Future<void> _directions(MapPin p) async {
    final uri = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=${p.point.latitude},${p.point.longitude}");
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final pins = ref.watch(mapPinsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr("Smart Eco Map"), style: AppTextStyles.title),
          Text(tr("Campaigns, recycling and refill points across the UAE"), style: AppTextStyles.tagline),
        ]),
      ),
      body: pins.when(
        loading: () => const AppLoading(),
        error: (e, _) => AppErrorState(
          message: friendlyError(e, fallback: "Could not load the map."),
          onRetry: () => ref.invalidate(mapPinsProvider),
        ),
        data: (all) {
          final shown = all.where((p) => _visible.contains(p.layer)).toList();
          return Stack(children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: _uae,
                initialZoom: 7.2,
                minZoom: 5,
                maxZoom: 18,
                onTap: (_, _) => setState(() => _selected = null),
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: "com.greenifyx.app",
                ),
                MarkerLayer(markers: [
                  if (_me != null)
                    Marker(
                      point: _me!,
                      width: 22,
                      height: 22,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2F80ED),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [BoxShadow(color: Color(0x552F80ED), blurRadius: 10, spreadRadius: 4)],
                        ),
                      ),
                    ),
                  for (final p in shown)
                    Marker(
                      point: p.point,
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selected = p);
                          _map.move(p.point, _map.camera.zoom < 11 ? 11 : _map.camera.zoom);
                        },
                        child: _PinBadge(pin: p, selected: _selected?.id == p.id),
                      ),
                    ),
                ]),
              ],
            ),
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final (key, label, icon, color) in _layers)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        avatar: Icon(icon, size: 18, color: _visible.contains(key) ? Colors.white : color),
                        label: Text("$label (${all.where((p) => p.layer == key).length})"),
                        selected: _visible.contains(key),
                        showCheckmark: false,
                        selectedColor: color,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: _visible.contains(key) ? Colors.white : AppColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                        side: BorderSide(color: color.withValues(alpha: 0.5)),
                        onSelected: (on) => setState(() {
                          on ? _visible.add(key) : _visible.remove(key);
                          if (_selected != null && !_visible.contains(_selected!.layer)) _selected = null;
                        }),
                      ),
                    ),
                ]),
              ),
            ),
            Positioned(
              right: 12,
              bottom: _selected == null ? 28 : 210,
              child: FloatingActionButton.small(
                heroTag: "locate",
                onPressed: _locate,
                backgroundColor: Colors.white,
                foregroundColor: AppColors.ink,
                child: const Icon(Icons.my_location_rounded),
              ),
            ),
            const Positioned(
              left: 8,
              bottom: 4,
              child: Text("© OpenStreetMap contributors", style: TextStyle(fontSize: 10, color: Colors.black54)),
            ),
            if (_selected != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 20,
                child: _PinCard(
                  pin: _selected!,
                  onClose: () => setState(() => _selected = null),
                  onDirections: () => _directions(_selected!),
                  onOpen: _selected!.layer == "campaign"
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => CampaignDetailScreen(campaignId: _selected!.id)),
                          )
                      : null,
                ),
              ),
          ]);
        },
      ),
    );
  }
}

class _PinBadge extends StatelessWidget {
  final MapPin pin;
  final bool selected;
  const _PinBadge({required this.pin, required this.selected});

  @override
  Widget build(BuildContext context) {
    final color = _pinColor(pin);
    return AnimatedScale(
      scale: selected ? 1.2 : 1,
      duration: const Duration(milliseconds: 150),
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          alignment: Alignment.center,
          child: Icon(_pinIcon(pin), color: Colors.white, size: 20),
        ),
        if (pin.official)
          const Positioned(
            right: -2,
            top: -2,
            child: CircleAvatar(
              radius: 8,
              backgroundColor: Colors.white,
              child: Icon(Icons.verified_rounded, size: 14, color: AppColors.eco),
            ),
          ),
      ]),
    );
  }
}

class _PinCard extends StatelessWidget {
  final MapPin pin;
  final VoidCallback onClose;
  final VoidCallback onDirections;
  final VoidCallback? onOpen;
  const _PinCard({required this.pin, required this.onClose, required this.onDirections, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final color = _pinColor(pin);
    return Material(
      elevation: 8,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(20),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(_pinIcon(pin), color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(pin.title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink)),
                const SizedBox(height: 2),
                Text(pin.subtitle, style: TextStyle(color: AppColors.subtitle, fontSize: 12.5)),
              ]),
            ),
            IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded), visualDensity: VisualDensity.compact),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (pin.layer == "place")
              _Tag(pin.official ? "Official partner" : "Community listed", pin.official ? AppColors.eco : AppColors.subtitle),
            for (final d in pin.details) _Tag(d, color),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onDirections,
                icon: const Icon(Icons.directions_rounded, size: 18),
                label: Text(tr("Directions")),
              ),
            ),
            if (onOpen != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(onPressed: onOpen, child: Text(tr("View campaign"))),
              ),
            ],
          ]),
        ]),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}
