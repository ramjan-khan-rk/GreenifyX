import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/i18n/app_locale.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/widgets/celebration.dart';

typedef Json = Map<String, dynamic>;

/// Keeps the home-screen widget (streak, points, habit streak) up to date.
class HomeWidgetSync {
  HomeWidgetSync._();

  static const appGroup = "group.com.ramjankhan.greenifyx";
  static bool _syncedThisLaunch = false;

  static bool get _supported => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> save(Json d) async {
    if (!_supported) return;
    try {
      await HomeWidget.setAppGroupId(appGroup);
      await HomeWidget.saveWidgetData<int>("gx_streak", (d["streak"] as num?)?.toInt() ?? 0);
      await HomeWidget.saveWidgetData<int>("gx_points", (d["points"] as num?)?.toInt() ?? 0);
      await HomeWidget.saveWidgetData<int>("gx_habit", (d["habitStreak"] as num?)?.toInt() ?? 0);
      await HomeWidget.saveWidgetData<String>("gx_label_streak", tr("day streak"));
      await HomeWidget.saveWidgetData<String>("gx_label_points", tr("Eco Points"));
      await HomeWidget.updateWidget(androidName: "GreenifyWidgetProvider", iOSName: "GreenifyWidget");
    } catch (_) {}
  }

  /// Once per app launch, from Home.
  static Future<void> refreshOnce() async {
    if (_syncedThisLaunch || !_supported) return;
    _syncedThisLaunch = true;
    try {
      final r = await ApiService.dio.get("/quicklog");
      await save(Json.from(r.data as Map));
    } catch (_) {}
  }
}

/// Two-second logging of small daily habits. No points (nobody verifies them):
/// they build a personal habit streak instead.
Future<void> showQuickLog(BuildContext context) =>
    showModalBottomSheet<void>(context: context, showDragHandle: true, isScrollControlled: true, builder: (_) => const _QuickLogSheet());

class _QuickLogSheet extends StatefulWidget {
  const _QuickLogSheet();

  @override
  State<_QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends State<_QuickLogSheet> {
  Json? _d;
  String? _busy;

  @override
  void initState() {
    super.initState();
    ApiService.dio.get("/quicklog").then((r) {
      if (mounted) setState(() => _d = Json.from(r.data as Map));
    }).catchError((Object e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    });
  }

  Future<void> _log(String kind, Json k) async {
    setState(() => _busy = kind);
    try {
      final r = await ApiService.dio.post("/quicklog", data: {"kind": kind});
      final d = Json.from(r.data as Map);
      if (!mounted) return;
      setState(() => _d = d);
      Celebration.show(context, {"big": false, "emoji": k["emoji"], "title": tr(k["label"].toString()), "message": "${tr("Habit streak")}: ${d["habitStreak"]}"});
      HomeWidgetSync.save(d);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final kinds = d == null ? <String, Json>{} : (d["kinds"] as Map).map((k, v) => MapEntry(k.toString(), Json.from(v as Map)));
    final done = (d?["today"] as List? ?? []).map((e) => e.toString()).toSet();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: d == null
            ? const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()))
            : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(tr("Quick log"), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(
                  "🔥 ${d["habitStreak"]} ${tr("day habit streak")} · ${d["weekCount"]} ${tr("this week")} · ≈ ${d["weekCo2Kg"]} kg CO₂",
                  style: TextStyle(color: AppColors.subtitle, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final e in kinds.entries)
                    FilterChip(
                      avatar: _busy == e.key ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(e.value["emoji"].toString()),
                      label: Text(tr(e.value["label"].toString())),
                      selected: done.contains(e.key),
                      showCheckmark: true,
                      onSelected: done.contains(e.key) || _busy != null ? null : (_) => _log(e.key, e.value),
                    ),
                ]),
                const SizedBox(height: 14),
                Text(tr("Small habits don't earn Eco Points, because nobody verifies them. They build your habit streak instead."),
                    style: TextStyle(color: AppColors.subtitle, fontSize: 12.5)),
              ]),
      ),
    );
  }
}
