import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/i18n/app_locale.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../post/domain/eco_activity.dart';

typedef Json = Map<String, dynamic>;

/// Live social proof on Home: what's happening around you right now, one line at a time.
class PulseStrip extends StatefulWidget {
  const PulseStrip({super.key});

  @override
  State<PulseStrip> createState() => _PulseStripState();
}

class _PulseStripState extends State<PulseStrip> with SingleTickerProviderStateMixin {
  List<(String, String)> _lines = const [];
  int _liveNow = 0;
  int _i = 0;
  Timer? _rotate;
  Timer? _refresh;
  late final AnimationController _dot = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _load();
    _rotate = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted && _lines.length > 1) setState(() => _i = (_i + 1) % _lines.length);
    });
    _refresh = Timer.periodic(const Duration(minutes: 2), (_) => _load());
  }

  @override
  void dispose() {
    _rotate?.cancel();
    _refresh?.cancel();
    _dot.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ApiService.dio.get("/pulse");
      final d = Json.from(r.data as Map);
      final lines = <(String, String)>[];
      final zone = d["zone"] is Map ? Json.from(d["zone"] as Map) : null;
      final emirate = d["emirate"] is Map ? Json.from(d["emirate"] as Map) : null;
      if (zone != null && (zone["recyclersToday"] as num) > 0) {
        lines.add(("♻️", "${zone["recyclersToday"]} ${tr("people in")} ${zone["name"]} ${tr("recycled today")}"));
      }
      if (zone != null && (zone["actionsToday"] as num) > 0) {
        lines.add(("🌱", "${zone["actionsToday"]} ${tr("verified actions in")} ${zone["name"]} ${tr("today")}"));
      }
      if (emirate != null && (emirate["actionsToday"] as num) > 0) {
        lines.add(("🇦🇪", "${emirate["actionsToday"]} ${tr("verified actions in")} ${tr(emirate["name"].toString())} ${tr("today")}"));
      }
      for (final f in (d["friends"] as List? ?? []).map((e) => Json.from(e as Map))) {
        lines.add(f["kind"] == "lesson"
            ? ("🎓", "${f["name"]} ${tr("just finished today's lesson")}")
            : ("👏", "${f["name"]} ${tr("just did")} ${activityName(f["activity"].toString())}"));
      }
      if (d["mission"] is Map) {
        final m = Json.from(d["mission"] as Map);
        lines.add(("🎯", "${m["title"]}: ${m["percent"]}% ${tr("done in your area")}"));
      }
      if (!mounted) return;
      setState(() {
        _lines = lines;
        _liveNow = (d["liveNow"] as num?)?.toInt() ?? 0;
        if (_i >= _lines.length) _i = 0;
      });
    } catch (_) {
      // Social proof is a nice-to-have: stay quiet if it can't load.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_lines.isEmpty && _liveNow < 2) return const SizedBox.shrink();
    final line = _lines.isEmpty ? null : _lines[_i % _lines.length];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          if (_liveNow >= 2) ...[
            FadeTransition(
              opacity: Tween(begin: 0.35, end: 1.0).animate(_dot),
              child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFE8384F), shape: BoxShape.circle)),
            ),
            const SizedBox(width: 6),
            Text("$_liveNow ${tr("live now")}", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
            if (line != null) Container(width: 1, height: 16, margin: const EdgeInsets.symmetric(horizontal: 10), color: AppColors.border),
          ],
          if (line != null)
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(a), child: c)),
                child: Row(key: ValueKey(_i), children: [
                  Text(line.$1, style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(line.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600, fontSize: 13))),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}
