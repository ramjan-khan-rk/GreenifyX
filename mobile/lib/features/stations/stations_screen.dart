import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/i18n/app_locale.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/friendly_error.dart';
import '../checkin/scan_screen.dart';

typedef Json = Map<String, dynamic>;

const _statusLabel = {"active": "Open", "full": "Full", "out_of_service": "Out of service"};

Future<Position?> _here() async {
  try {
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return null;
    return await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)));
  } catch (_) {
    return null;
  }
}

/// Recycling stations near you, with live status, plus your drop-offs.
class StationsScreen extends StatefulWidget {
  const StationsScreen({super.key});

  @override
  State<StationsScreen> createState() => _StationsScreenState();
}

class _StationsScreenState extends State<StationsScreen> {
  List<Json>? _stations;
  Json? _mine;
  Position? _pos;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _pos = await _here();
    try {
      final results = await Future.wait([
        ApiService.dio.get("/stations", queryParameters: {if (_pos != null) "lat": _pos!.latitude, if (_pos != null) "lng": _pos!.longitude}),
        ApiService.dio.get("/stations/mine"),
      ]);
      if (!mounted) return;
      setState(() {
        _stations = (results[0].data["stations"] as List).map((e) => Json.from(e as Map)).toList();
        _mine = Json.from(results[1].data as Map);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _stations = []);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  Future<void> _report(Json s) async {
    final issue = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.delete_rounded), title: Text(tr("It's full")), onTap: () => Navigator.pop(context, "full")),
          ListTile(leading: const Icon(Icons.build_rounded), title: Text(tr("It's broken")), onTap: () => Navigator.pop(context, "broken")),
          ListTile(leading: const Icon(Icons.cleaning_services_rounded), title: Text(tr("It's dirty")), onTap: () => Navigator.pop(context, "dirty")),
        ]),
      ),
    );
    if (issue == null) return;
    try {
      final r = await ApiService.dio.post("/stations/${s["_id"]}/report", data: {"issue": issue});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(r.data["message"]?.toString() ?? "Thanks"))));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _stations;
    final totals = _mine?["totals"] is Map ? Json.from(_mine!["totals"] as Map) : null;
    final withLoc = (list ?? []).where((s) => s["location"] is Map && (s["location"] as Map)["lat"] is num).toList();
    return Scaffold(
      appBar: AppBar(title: Text(tr("Recycling stations")), actions: [
        IconButton(tooltip: tr("My check-ins"), icon: const Icon(Icons.history_rounded), onPressed: () => showHistorySheet(context, (_mine?["dropoffs"] as List? ?? []).map((e) => Json.from(e as Map)).toList())),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.eco,
        foregroundColor: Colors.white,
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen()));
          _load();
        },
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: Text(tr("Scan a station")),
      ),
      body: list == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
                if (totals != null)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), gradient: const LinearGradient(colors: [Color(0xFF1F8A70), Color(0xFF56AB2F)])),
                    child: Row(children: [
                      const Text("♻️", style: TextStyle(fontSize: 34)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text("${totals["kg"]} kg ${tr("recycled")}", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                          Text("${totals["dropoffs"]} ${tr("drop-offs")} · +${totals["points"]} ${tr("points")}", style: const TextStyle(color: Colors.white70)),
                        ]),
                      ),
                    ]),
                  ),
                const SizedBox(height: 12),
                Text(tr("Scan the QR on a station after you drop off. Points need you to be at the station."), style: TextStyle(color: AppColors.subtitle, height: 1.4)),
                if (withLoc.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      height: 200,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: _pos != null ? LatLng(_pos!.latitude, _pos!.longitude) : LatLng(((withLoc.first["location"] as Map)["lat"] as num).toDouble(), ((withLoc.first["location"] as Map)["lng"] as num).toDouble()),
                          initialZoom: 12,
                        ),
                        children: [
                          TileLayer(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png", userAgentPackageName: "com.greenifyx.app"),
                          MarkerLayer(markers: [
                            for (final s in withLoc)
                              Marker(
                                point: LatLng(((s["location"] as Map)["lat"] as num).toDouble(), ((s["location"] as Map)["lng"] as num).toDouble()),
                                width: 34,
                                height: 34,
                                child: Icon(Icons.recycling_rounded, color: s["status"] == "active" ? AppColors.eco : AppColors.error, size: 30),
                              ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text(tr("No stations yet. They'll appear here as partners add them."), textAlign: TextAlign.center, style: TextStyle(color: AppColors.subtitle)),
                  ),
                for (final s in list)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: (s["status"] == "active" ? AppColors.eco : AppColors.error).withValues(alpha: 0.12),
                        child: Icon(s["kind"] == "reverse_vending" ? Icons.local_drink_rounded : Icons.recycling_rounded, color: s["status"] == "active" ? AppColors.eco : AppColors.error),
                      ),
                      title: Text(s["name"].toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(
                        "${tr(_statusLabel[s["status"]] ?? s["status"].toString())}"
                        "${s["distanceM"] != null ? " · ${((s["distanceM"] as num) / 1000).toStringAsFixed(1)} km" : ""}"
                        "${(s["address"] ?? "").toString().isEmpty ? "" : "\n${s["address"]}"}",
                      ),
                      isThreeLine: (s["address"] ?? "").toString().isNotEmpty,
                      trailing: IconButton(tooltip: tr("Report a problem"), icon: const Icon(Icons.flag_outlined), onPressed: () => _report(s)),
                    ),
                  ),
              ]),
            ),
    );
  }
}

/// After scanning a station QR: what was dropped off.
Future<void> showDropoffSheet(BuildContext context, String code) async {
  await showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => _DropoffSheet(code: code));
}

class _DropoffSheet extends StatefulWidget {
  final String code;
  const _DropoffSheet({required this.code});

  @override
  State<_DropoffSheet> createState() => _DropoffSheetState();
}

class _DropoffSheetState extends State<_DropoffSheet> {
  static const _materials = {
    "plastic": ("🧴", "Plastic bottles"),
    "cans": ("🥫", "Cans"),
    "glass": ("🍾", "Glass"),
    "paper": ("📦", "Paper and cardboard"),
    "ewaste": ("📱", "Electronics"),
    "batteries": ("🔋", "Batteries"),
    "textiles": ("👕", "Clothes and textiles"),
    "mixed": ("♻️", "Mixed recyclables"),
  };
  String _material = "plastic";
  String _unit = "items";
  int _qty = 5;
  bool _sending = false;
  Json? _result;

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      final pos = await _here();
      final r = await ApiService.dio.post("/stations/dropoff", data: {
        "code": widget.code,
        "material": _material,
        "unit": _unit,
        "quantity": _qty,
        if (pos != null) "lat": pos.latitude,
        if (pos != null) "lng": pos.longitude,
      });
      if (mounted) setState(() => _result = Json.from(r.data as Map));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    if (r != null) {
      final pts = (r["points"] as num?)?.toInt() ?? 0;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.eco, size: 64),
            const SizedBox(height: 8),
            Text(pts > 0 ? "+$pts ${tr("Eco Points")}" : tr("Drop-off logged"), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text("≈ ${(r["dropoff"] as Map)["estimatedKg"]} kg · ${(r["station"] as Map)["name"]}", style: TextStyle(color: AppColors.subtitle)),
            if ((r["note"] ?? "").toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(tr(r["note"].toString()), textAlign: TextAlign.center)),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(context), child: Text(tr("Done"))),
          ]),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.viewInsetsOf(context).bottom + 18),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr("What did you drop off?"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in _materials.entries)
            ChoiceChip(label: Text("${m.value.$1} ${tr(m.value.$2)}"), selected: _material == m.key, onSelected: (_) => setState(() => _material = m.key)),
        ]),
        const SizedBox(height: 14),
        SegmentedButton<String>(
          segments: [ButtonSegment(value: "items", label: Text(tr("Items"))), ButtonSegment(value: "bags", label: Text(tr("Bags")))],
          selected: {_unit},
          onSelectionChanged: (s) => setState(() {
            _unit = s.first;
            _qty = _unit == "bags" ? 1 : 5;
          }),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton.outlined(onPressed: _qty > 1 ? () => setState(() => _qty--) : null, icon: const Icon(Icons.remove_rounded)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text("$_qty", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900))),
          IconButton.outlined(onPressed: _qty < (_unit == "bags" ? 10 : 500) ? () => setState(() => _qty++) : null, icon: const Icon(Icons.add_rounded)),
        ]),
        const SizedBox(height: 16),
        FilledButton(onPressed: _sending ? null : _send, child: Text(tr("Log drop-off"))),
      ]),
    );
  }
}

/// My recent recycling drop-offs and QR check-ins.
Future<void> showHistorySheet(BuildContext context, List<Json> dropoffs) async {
  List<Json> checkins = const [];
  try {
    final r = await ApiService.dio.get("/checkins/mine");
    checkins = (r.data["checkins"] as List).map((e) => Json.from(e as Map)).toList();
  } catch (_) {}
  if (!context.mounted) return;
  final rows = <(DateTime, String, String)>[
    for (final d in dropoffs)
      (DateTime.tryParse(d["createdAt"]?.toString() ?? "")?.toLocal() ?? DateTime.now(), "♻️ ${(d["station"] as Map?)?["name"] ?? tr("Station")}", "≈ ${d["estimatedKg"]} kg · +${d["points"]}"),
    for (final c in checkins)
      (DateTime.tryParse(c["createdAt"]?.toString() ?? "")?.toLocal() ?? DateTime.now(), "📍 ${(c["checkpoint"] as Map?)?["name"] ?? tr("Check-in")}", "+${c["points"] ?? 0}"),
  ]..sort((a, b) => b.$1.compareTo(a.$1));
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: rows.isEmpty
            ? Padding(padding: const EdgeInsets.all(24), child: Text(tr("No drop-offs or check-ins yet."), textAlign: TextAlign.center))
            : ListView(shrinkWrap: true, children: [
                for (final r in rows)
                  ListTile(
                    title: Text(r.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text("${r.$1.day}/${r.$1.month}/${r.$1.year} ${r.$1.hour.toString().padLeft(2, "0")}:${r.$1.minute.toString().padLeft(2, "0")}"),
                    trailing: Text(r.$3, style: const TextStyle(color: AppColors.eco, fontWeight: FontWeight.w800)),
                  ),
              ]),
      ),
    ),
  );
}
