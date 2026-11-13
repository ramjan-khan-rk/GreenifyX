import 'package:flutter/material.dart';

import '../../../core/i18n/app_locale.dart';
import '../../../core/services/api_service.dart';
import 'deeds.dart';

/// An eco action a member can post about (managed by admins).
class EcoActivity {
  final String key;
  final String name;
  final String nameAr;
  final String lane;
  final String line;
  final String icon;
  final int points;
  final double co2Kg;
  final List<String> keywords;

  const EcoActivity({
    required this.key,
    required this.name,
    this.nameAr = "",
    required this.lane,
    this.line = "",
    this.icon = "eco",
    this.points = 10,
    this.co2Kg = 0,
    this.keywords = const [],
  });

  String get label => AppLocale.isArabic && nameAr.isNotEmpty ? nameAr : name;

  factory EcoActivity.fromJson(Map<String, dynamic> j) => EcoActivity(
        key: j["key"]?.toString() ?? "",
        name: j["name"]?.toString() ?? "",
        nameAr: j["nameAr"]?.toString() ?? "",
        lane: j["lane"]?.toString() ?? "Planet",
        line: j["line"]?.toString() ?? "",
        icon: j["icon"]?.toString() ?? "eco",
        points: (j["points"] as num?)?.toInt() ?? 10,
        co2Kg: (j["co2Kg"] as num?)?.toDouble() ?? 0,
        keywords: (j["keywords"] as List? ?? const []).map((e) => e.toString()).toList(),
      );

  bool matches(String q) {
    final words = q.toLowerCase().split(RegExp(r"\s+")).where((w) => w.isNotEmpty);
    final hay = [name, nameAr, line, ...keywords].join(" ").toLowerCase();
    return words.every(hay.contains);
  }
}

/// Built-in fallback used when the server list can't be loaded.
final fallbackActivities = [
  for (final d in deeds) EcoActivity(key: d.name, name: d.name, lane: d.lane, line: d.line, icon: "eco", points: 10),
];

class EcoActivityApi {
  static List<EcoActivity>? _cache;

  static Future<List<EcoActivity>> load({bool refresh = false}) async {
    if (_cache != null && !refresh) return _cache!;
    try {
      final r = await ApiService.dio.get("/activities");
      final list = (r.data["activities"] as List).map((e) => EcoActivity.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      if (list.isNotEmpty) _cache = list;
      return list.isEmpty ? fallbackActivities : list;
    } catch (_) {
      return _cache ?? fallbackActivities;
    }
  }
}

/// Material icon for an activity's icon name (set by admins).
IconData activityIcon(String name) => switch (name) {
      "park" => Icons.park_rounded,
      "forest" => Icons.forest_rounded,
      "water" => Icons.water_rounded,
      "water_drop" => Icons.water_drop_rounded,
      "yard" => Icons.yard_rounded,
      "compost" => Icons.compost_rounded,
      "recycling" => Icons.recycling_rounded,
      "devices_other" => Icons.devices_other_rounded,
      "shopping_bag" => Icons.shopping_bag_rounded,
      "autorenew" => Icons.autorenew_rounded,
      "restaurant" => Icons.restaurant_rounded,
      "cleaning_services" => Icons.cleaning_services_rounded,
      "beach_access" => Icons.beach_access_rounded,
      "landscape" => Icons.landscape_rounded,
      "scuba_diving" => Icons.scuba_diving_rounded,
      "pedal_bike" => Icons.pedal_bike_rounded,
      "directions_walk" => Icons.directions_walk_rounded,
      "directions_subway" => Icons.directions_subway_rounded,
      "groups" => Icons.groups_rounded,
      "bolt" => Icons.bolt_rounded,
      "solar_power" => Icons.solar_power_rounded,
      "volunteer_activism" => Icons.volunteer_activism_rounded,
      "dinner_dining" => Icons.dinner_dining_rounded,
      "checkroom" => Icons.checkroom_rounded,
      "school" => Icons.school_rounded,
      "pets" => Icons.pets_rounded,
      "flutter_dash" => Icons.flutter_dash_rounded,
      "favorite" => Icons.favorite_rounded,
      "emoji_events" => Icons.emoji_events_rounded,
      _ => Icons.eco_rounded,
    };

/// Brand colour per lane.
Color laneColor(String lane) => switch (lane) {
      "Humanity" => const Color(0xFFE36A4A),
      "Wildlife" => const Color(0xFF7F53AC),
      "Stories" => const Color(0xFFF2B544),
      _ => const Color(0xFF1F8A70),
    };
