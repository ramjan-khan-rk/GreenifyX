import 'package:flutter/material.dart';

import '../../core/i18n/app_locale.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/friendly_error.dart';

typedef Json = Map<String, dynamic>;

String tonnes(num? kg) => "${((kg ?? 0) / 1000).toStringAsFixed(1)} t";

/// Carbon footprint: 2-minute quiz, then a dashboard of verified savings.
class CarbonScreen extends StatefulWidget {
  const CarbonScreen({super.key});

  @override
  State<CarbonScreen> createState() => _CarbonScreenState();
}

class _CarbonScreenState extends State<CarbonScreen> {
  Json? _d;
  bool _quiz = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ApiService.dio.get("/carbon");
      if (!mounted) return;
      setState(() {
        _d = Json.from(r.data as Map);
        _quiz = _d!["footprint"] == null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr("Carbon footprint")),
        actions: [if (d != null && !_quiz) TextButton(onPressed: () => setState(() => _quiz = true), child: Text(tr("Retake")))],
      ),
      body: d == null
          ? Center(child: _error != null ? TextButton(onPressed: _load, child: Text(_error!)) : const CircularProgressIndicator())
          : _quiz
              ? _Quiz(initial: d["answers"] == null ? {} : Json.from(d["answers"] as Map), onDone: _load)
              : _Dashboard(d: d),
    );
  }
}

class _Dashboard extends StatelessWidget {
  final Json d;
  const _Dashboard({required this.d});

  @override
  Widget build(BuildContext context) {
    final f = Json.from(d["footprint"] as Map);
    final total = (f["totalKg"] as num).toDouble();
    final saved = (d["savedThisYearKg"] as num? ?? 0).toDouble();
    final bench = Json.from(d["benchmarks"] as Map);
    final parts = Json.from(f["parts"] as Map);
    final colors = {"transport": const Color(0xFF3A7BD5), "flights": const Color(0xFF7F53AC), "home": AppColors.sun, "food": AppColors.eco, "shopping": AppColors.joy};
    final icons = {"transport": Icons.directions_car_rounded, "flights": Icons.flight_rounded, "home": Icons.ac_unit_rounded, "food": Icons.restaurant_rounded, "shopping": Icons.shopping_bag_rounded};
    final maxPart = parts.values.fold<num>(1, (m, v) => (v as num) > m ? v : m);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), gradient: const LinearGradient(colors: [Color(0xFF0E5A3A), Color(0xFF1F8A70)])),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr("Your yearly footprint"), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(tonnes(total), style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900, height: 1)),
          Text("CO₂e", style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _Mini(tr("Saved this year"), tonnes(saved), "🌱")),
            Expanded(child: _Mini(tr("This month"), "${d["savedThisMonthKg"]} kg", "📅")),
            Expanded(child: _Mini(tr("Goal"), tonnes(d["targetKg"] as num?), "🎯")),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr("How you compare"), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 12),
          for (final b in [
            (tr("You"), total, AppColors.joy),
            (tr("UAE average lifestyle"), (bench["uaeAverageKg"] as num).toDouble(), AppColors.subtitle),
            (tr("1.5°C target"), (bench["parisTargetKg"] as num).toDouble(), AppColors.eco),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                SizedBox(width: 130, child: Text(b.$1, style: const TextStyle(fontWeight: FontWeight.w600))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: (b.$2 / 12000).clamp(0, 1), minHeight: 12, color: b.$3, backgroundColor: AppColors.border),
                  ),
                ),
                const SizedBox(width: 8),
                Text(tonnes(b.$2), style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr("Where it comes from"), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 12),
          for (final e in parts.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Icon(icons[e.key], color: colors[e.key], size: 22),
                const SizedBox(width: 10),
                SizedBox(width: 82, child: Text(tr(e.key[0].toUpperCase() + e.key.substring(1)))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: (e.value as num) / maxPart, minHeight: 10, color: colors[e.key], backgroundColor: AppColors.border),
                  ),
                ),
                const SizedBox(width: 8),
                Text(tonnes(e.value as num), style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 16),
      Text(tr("Your biggest wins"), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 8),
      for (final t in (d["tips"] as List? ?? []))
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.blush, borderRadius: BorderRadius.circular(18)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icons[(t as Map)["area"]] ?? Icons.eco_rounded, color: colors[t["area"]] ?? AppColors.eco),
            const SizedBox(width: 12),
            Expanded(child: Text(tr(t["tip"].toString()), style: const TextStyle(height: 1.4))),
          ]),
        ),
      const SizedBox(height: 6),
      Text(tr("Estimates for awareness, based on typical UAE factors. Savings come from your verified actions."),
          style: TextStyle(fontSize: 12, color: AppColors.subtitle)),
    ]);
  }
}

class _Mini extends StatelessWidget {
  final String label;
  final String value;
  final String emoji;
  const _Mini(this.label, this.value, this.emoji);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("$emoji $value", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
      ]);
}

class _Quiz extends StatefulWidget {
  final Json initial;
  final VoidCallback onDone;
  const _Quiz({required this.initial, required this.onDone});

  @override
  State<_Quiz> createState() => _QuizState();
}

class _QuizState extends State<_Quiz> {
  late final Json _a = {
    "carKmPerWeek": 150,
    "carType": "petrol",
    "metroTripsPerWeek": 2,
    "shortFlightsPerYear": 2,
    "longFlightsPerYear": 1,
    "acHoursPerDay": 10,
    "homeSize": "apartment",
    "householdSize": 3,
    "diet": "low-meat",
    "shopping": "average",
    "recycles": "sometimes",
    ...widget.initial,
  };
  bool _saving = false;

  Widget _slider(String key, String label, double max, {int div = 0, String unit = ""}) {
    final v = ((_a[key] as num?) ?? 0).toDouble().clamp(0, max).toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(tr(label), style: const TextStyle(fontWeight: FontWeight.w700))), Text("${v.round()}$unit", style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.joy))]),
        Slider(value: v, max: max, divisions: div > 0 ? div : max.round(), onChanged: (x) => setState(() => _a[key] = x.round())),
      ]),
    );
  }

  Widget _choice(String key, String label, Map<String, String> options) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr(label), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in options.entries) ChoiceChip(label: Text(tr(o.value)), selected: _a[key] == o.key, onSelected: (_) => setState(() => _a[key] = o.key)),
          ]),
        ]),
      );

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiService.dio.put("/carbon", data: {"answers": _a});
      widget.onDone();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
      Text(tr("Answer 11 quick questions to see your yearly CO₂ — about 2 minutes."), style: TextStyle(color: AppColors.subtitle, height: 1.4)),
      const SizedBox(height: 14),
      _choice("carType", "Your main car", {"petrol": "Petrol", "hybrid": "Hybrid", "electric": "Electric", "none": "No car"}),
      _slider("carKmPerWeek", "Car travel per week", 1000, div: 50, unit: " km"),
      _slider("metroTripsPerWeek", "Metro or bus trips per week", 30),
      _slider("shortFlightsPerYear", "Short flights per year (under 4h)", 20),
      _slider("longFlightsPerYear", "Long flights per year", 12),
      _choice("homeSize", "Your home", {"studio": "Studio", "apartment": "Apartment", "villa": "Villa"}),
      _slider("householdSize", "People at home", 10),
      _slider("acHoursPerDay", "AC hours per day", 24, unit: "h"),
      _choice("diet", "Your diet", {"vegan": "Vegan", "vegetarian": "Vegetarian", "low-meat": "Some meat", "meat-daily": "Meat daily"}),
      _choice("shopping", "New things you buy", {"minimal": "Very little", "average": "Average", "high": "A lot"}),
      _choice("recycles", "Do you recycle?", {"always": "Always", "sometimes": "Sometimes", "never": "Rarely"}),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: _saving ? null : _save,
        icon: const Icon(Icons.calculate_rounded),
        label: Text(tr("See my footprint")),
      ),
    ]);
  }
}
