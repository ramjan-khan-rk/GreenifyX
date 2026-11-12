import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/friendly_error.dart';

typedef Json = Map<String, dynamic>;

const _materials = {
  "plastic": ("Plastic", Icons.local_drink_rounded, Color(0xFF3A7BD5)),
  "paper": ("Paper", Icons.description_rounded, Color(0xFFB08968)),
  "glass": ("Glass", Icons.wine_bar_rounded, Color(0xFF11998E)),
  "metal": ("Metal", Icons.hardware_rounded, Color(0xFF6E6578)),
  "e-waste": ("E-waste", Icons.devices_other_rounded, Color(0xFF7F53AC)),
  "textile": ("Textile", Icons.checkroom_rounded, Color(0xFFE36A4A)),
  "cooking-oil": ("Cooking oil", Icons.opacity_rounded, Color(0xFFF2B544)),
};

const _emirates = ["Abu Dhabi", "Dubai", "Sharjah", "Ajman", "Umm Al Quwain", "Ras Al Khaimah", "Fujairah"];

class PickupScreen extends StatefulWidget {
  const PickupScreen({super.key});

  @override
  State<PickupScreen> createState() => _PickupScreenState();
}

class _PickupScreenState extends State<PickupScreen> {
  bool _loading = true;
  List<Json> _pickups = [];
  num _collectedKg = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ApiService.dio.get("/pickups/mine");
      if (!mounted) return;
      setState(() {
        _pickups = (r.data["pickups"] as List).map((e) => Json.from(e as Map)).toList();
        _collectedKg = (r.data["stats"]?["collectedKg"] as num?) ?? 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _cancel(Json p) async {
    try {
      await ApiService.dio.post("/pickups/${p["_id"]}/cancel");
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _new() async {
    final created = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const _NewPickupScreen()));
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Recycling pickup")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _new,
        icon: const Icon(Icons.local_shipping_rounded),
        label: const Text("Book a pickup"),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(colors: [Color(0xFF11998E), Color(0xFF38EF7D)]),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("Doorstep recycling", style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text("We collect it, weigh it and credit 10 Eco Points per kg.",
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), height: 1.4)),
                  const SizedBox(height: 12),
                  Text("${_collectedKg.toStringAsFixed(1)} kg recycled so far",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ]),
              ),
              const Icon(Icons.recycling_rounded, color: Colors.white, size: 64),
            ]),
          ),
          const SizedBox(height: 20),
          const Text("Your pickups", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (_loading) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
          if (!_loading && _pickups.isEmpty)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: Text("No pickups yet. Book your first one!", style: TextStyle(color: AppColors.subtitle))),
            ),
          for (final p in _pickups) _PickupTile(p: p, onCancel: () => _cancel(p)),
        ]),
      ),
    );
  }
}

class _PickupTile extends StatelessWidget {
  final Json p;
  final VoidCallback onCancel;
  const _PickupTile({required this.p, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final status = p["status"]?.toString() ?? "requested";
    final color = {
          "requested": AppColors.sun,
          "scheduled": const Color(0xFF3A7BD5),
          "collected": AppColors.eco,
          "cancelled": AppColors.error,
        }[status] ??
        AppColors.subtitle;
    final date = DateTime.tryParse((p["scheduledFor"] ?? p["preferredDate"] ?? "").toString())?.toLocal();
    final mats = (p["materials"] as List? ?? []).map((m) => _materials[m]?.$1 ?? m.toString()).join(", ");
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(mats, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
            child: Text(status.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.event_rounded, size: 16, color: AppColors.subtitle),
          const SizedBox(width: 6),
          Text(date == null ? "-" : "${DateFormat("EEE d MMM").format(date)} · ${p["timeSlot"] ?? ""}"),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.place_rounded, size: 16, color: AppColors.subtitle),
          const SizedBox(width: 6),
          Expanded(child: Text("${p["address"] ?? ""}${(p["emirate"] ?? "").toString().isEmpty ? "" : ", ${p["emirate"]}"}", maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        if (status == "collected") ...[
          const SizedBox(height: 8),
          Text("${p["collectedKg"]} kg collected · +${p["pointsAwarded"] ?? 0} Eco Points",
              style: const TextStyle(color: AppColors.eco, fontWeight: FontWeight.w800)),
        ],
        if ((p["adminNote"] ?? "").toString().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(p["adminNote"], style: const TextStyle(color: AppColors.subtitle, fontSize: 13)),
        ],
        if (status == "requested" || status == "scheduled")
          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: onCancel, child: const Text("Cancel pickup"))),
      ]),
    );
  }
}

class _NewPickupScreen extends StatefulWidget {
  const _NewPickupScreen();

  @override
  State<_NewPickupScreen> createState() => _NewPickupScreenState();
}

class _NewPickupScreenState extends State<_NewPickupScreen> {
  final _selected = <String>{};
  final _address = TextEditingController();
  final _notes = TextEditingController();
  double _kg = 5;
  String _emirate = "Dubai";
  String _slot = "morning";
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  Position? _pos;
  bool _saving = false;

  Future<void> _locate() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final p = await Geolocator.getCurrentPosition();
      if (mounted) setState(() => _pos = p);
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (_selected.isEmpty) return _snack("Choose what you're recycling");
    if (_address.text.trim().length < 5) return _snack("Add your pickup address");
    setState(() => _saving = true);
    try {
      await ApiService.dio.post("/pickups", data: {
        "materials": _selected.toList(),
        "estimatedKg": _kg,
        "address": _address.text.trim(),
        "emirate": _emirate,
        "preferredDate": DateTime(_date.year, _date.month, _date.day, 12).toIso8601String(),
        "timeSlot": _slot,
        "notes": _notes.text.trim(),
        if (_pos != null) "location": {"lat": _pos!.latitude, "lng": _pos!.longitude},
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pickup booked! We'll confirm the time soon.")));
      Navigator.pop(context, true);
    } catch (e) {
      _snack(friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Book a pickup")),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 30), children: [
        const Text("What are you recycling?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in _materials.entries)
            FilterChip(
              avatar: Icon(m.value.$2, size: 18, color: _selected.contains(m.key) ? Colors.white : m.value.$3),
              label: Text(m.value.$1),
              selected: _selected.contains(m.key),
              selectedColor: m.value.$3,
              checkmarkColor: Colors.white,
              showCheckmark: false,
              labelStyle: TextStyle(color: _selected.contains(m.key) ? Colors.white : AppColors.ink, fontWeight: FontWeight.w700),
              onSelected: (v) => setState(() => v ? _selected.add(m.key) : _selected.remove(m.key)),
            ),
        ]),
        const SizedBox(height: 22),
        Text("Estimated weight: ${_kg.round()} kg", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        Slider(value: _kg, min: 1, max: 50, divisions: 49, label: "${_kg.round()} kg", onChanged: (v) => setState(() => _kg = v)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _emirate,
          decoration: const InputDecoration(labelText: "Emirate"),
          items: [for (final e in _emirates) DropdownMenuItem(value: e, child: Text(e))],
          onChanged: (v) => setState(() => _emirate = v ?? _emirate),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _address,
          decoration: InputDecoration(
            labelText: "Address",
            hintText: "Building, street, area",
            suffixIcon: IconButton(
              tooltip: "Use my location",
              onPressed: _locate,
              icon: Icon(_pos == null ? Icons.my_location_rounded : Icons.check_circle_rounded, color: _pos == null ? null : AppColors.eco),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_rounded),
          title: const Text("Pickup date"),
          subtitle: Text(DateFormat("EEEE, d MMMM").format(_date)),
          trailing: const Icon(Icons.edit_calendar_rounded),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 30)),
            );
            if (d != null) setState(() => _date = d);
          },
        ),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: "morning", label: Text("Morning"), icon: Icon(Icons.wb_twilight_rounded)),
            ButtonSegment(value: "afternoon", label: Text("Afternoon"), icon: Icon(Icons.wb_sunny_rounded)),
            ButtonSegment(value: "evening", label: Text("Evening"), icon: Icon(Icons.nights_stay_rounded)),
          ],
          selected: {_slot},
          onSelectionChanged: (s) => setState(() => _slot = s.first),
        ),
        const SizedBox(height: 12),
        TextField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: "Notes for the driver (optional)")),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: _saving ? null : _submit,
          icon: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.local_shipping_rounded),
          label: const Text("Book pickup"),
        ),
      ]),
    );
  }
}
