import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/i18n/app_locale.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/friendly_error.dart';

typedef Json = Map<String, dynamic>;

/// Reads steps and cycling workouts from Apple Health / Health Connect and sends daily totals.
class HealthSync {
  HealthSync._();

  static const _prefKey = "health_sync_on";
  static const _types = [HealthDataType.STEPS, HealthDataType.WORKOUT];
  static final _health = Health();
  static bool _configured = false;

  static bool get supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<bool> isOn() async {
    if (!supported) return false;
    final p = await SharedPreferences.getInstance();
    return p.getBool(_prefKey) ?? false;
  }

  static Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Ask for permission. Returns false if the member declined or Health Connect is missing.
  static Future<bool> connect() async {
    if (!supported) return false;
    await _configure();
    if (Platform.isAndroid && !await _health.isHealthConnectAvailable()) {
      await _health.installHealthConnect();
      return false;
    }
    final ok = await _health.requestAuthorization(_types, permissions: const [HealthDataAccess.READ, HealthDataAccess.READ]);
    final p = await SharedPreferences.getInstance();
    await p.setBool(_prefKey, ok);
    return ok;
  }

  static Future<void> disconnect() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_prefKey, false);
  }

  static String _stamp(DateTime d) =>
      "${d.year.toString().padLeft(4, "0")}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}";

  /// Read the last 7 days and sync them. Returns the server's reply.
  static Future<Json> sync() async {
    await _configure();
    // Days follow UAE time (UTC+4), matching the server.
    final nowUae = DateTime.now().toUtc().add(const Duration(hours: 4));
    final days = <Json>[];
    for (var i = 0; i < 7; i++) {
      final d = DateTime.utc(nowUae.year, nowUae.month, nowUae.day - i);
      final start = d.subtract(const Duration(hours: 4));
      final end = start.add(const Duration(days: 1));
      final steps = await _health.getTotalStepsInInterval(start.toLocal(), end.toLocal()) ?? 0;
      var meters = 0;
      try {
        final workouts = await _health.getHealthDataFromTypes(types: const [HealthDataType.WORKOUT], startTime: start.toLocal(), endTime: end.toLocal());
        for (final w in workouts) {
          final v = w.value;
          if (v is WorkoutHealthValue && v.workoutActivityType == HealthWorkoutActivityType.BIKING) {
            meters += v.totalDistance ?? 0;
          }
        }
      } catch (_) {
        // Workouts are optional; steps still sync.
      }
      days.add({"day": _stamp(d), "steps": steps, "cycleKm": meters / 1000});
    }
    final r = await ApiService.dio.post("/health/sync", data: {
      "source": Platform.isIOS ? "apple_health" : "health_connect",
      "days": days,
    });
    return Json.from(r.data as Map);
  }

  static bool _syncedThisLaunch = false;

  /// Quiet background sync once per app launch, if the member turned it on.
  static Future<void> syncIfOn() async {
    if (_syncedThisLaunch) return;
    _syncedThisLaunch = true;
    try {
      if (await isOn()) await sync();
    } catch (_) {}
  }
}

/// Connect Apple Health / Health Connect and see the last 7 days.
class HealthSyncScreen extends StatefulWidget {
  const HealthSyncScreen({super.key});

  @override
  State<HealthSyncScreen> createState() => _HealthSyncScreenState();
}

class _HealthSyncScreenState extends State<HealthSyncScreen> {
  bool _on = false;
  bool _busy = false;
  Json? _data;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final on = await HealthSync.isOn();
    try {
      final r = await ApiService.dio.get("/health");
      if (!mounted) return;
      setState(() {
        _on = on;
        _data = Json.from(r.data as Map);
      });
    } catch (e) {
      if (mounted) setState(() => _on = on);
    }
  }

  void _toast(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Future<void> _connect() async {
    setState(() => _busy = true);
    try {
      final ok = await HealthSync.connect();
      if (!ok) {
        _toast(tr("Permission not given. You can allow it in your phone's health settings."));
      } else {
        setState(() => _on = true);
        await _sync();
      }
    } catch (e) {
      _toast(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sync() async {
    setState(() => _busy = true);
    try {
      final d = await HealthSync.sync();
      if (!mounted) return;
      setState(() => _data = d);
      final earned = d["earned"] ?? 0;
      _toast(earned > 0 ? "+$earned ${tr("Eco Points from your activity")}" : tr("You're up to date"));
    } catch (e) {
      _toast(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = (_data?["days"] as List? ?? []).map((e) => Json.from(e as Map)).toList();
    final totals = _data?["totals"] is Map ? Json.from(_data!["totals"] as Map) : null;
    return Scaffold(
      appBar: AppBar(title: Text(tr("Health sync"))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(colors: [Color(0xFF11998E), Color(0xFF38EF7D)]),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("🚶 🚲", style: TextStyle(fontSize: 30)),
            const SizedBox(height: 8),
            Text(tr("Earn points just by moving"), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              tr("1 point per 2,000 steps and per 2 km cycled, up to 15 a day. We only read steps and cycling workouts."),
              style: const TextStyle(color: Colors.white, height: 1.4),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        if (!HealthSync.supported)
          Text(tr("Health sync works in the iPhone and Android app."), style: TextStyle(color: AppColors.subtitle))
        else if (!_on)
          FilledButton.icon(
            onPressed: _busy ? null : _connect,
            icon: const Icon(Icons.favorite_rounded),
            label: Text(Platform.isIOS ? tr("Connect Apple Health") : tr("Connect Health Connect")),
          )
        else
          Row(children: [
            Expanded(child: FilledButton.icon(onPressed: _busy ? null : _sync, icon: const Icon(Icons.sync_rounded), label: Text(tr("Sync now")))),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () async {
                      await HealthSync.disconnect();
                      setState(() => _on = false);
                    },
              child: Text(tr("Turn off")),
            ),
          ]),
        if (totals != null && days.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text(tr("Last 7 days"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text("${totals["steps"]} ${tr("steps")} · ${totals["cycleKm"]} km ${tr("cycled")} · +${totals["points"]} ${tr("points")}",
              style: TextStyle(color: AppColors.subtitle, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          for (final d in days)
            Card(
              child: ListTile(
                title: Text(d["day"].toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text("${d["steps"]} ${tr("steps")} · ${d["cycleKm"]} km"),
                trailing: Text("+${d["points"]}", style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.eco, fontSize: 16)),
              ),
            ),
        ],
      ]),
    );
  }
}
