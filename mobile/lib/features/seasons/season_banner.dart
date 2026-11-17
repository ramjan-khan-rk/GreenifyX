import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config/app_config.dart';
import '../../core/i18n/app_locale.dart';
import '../../core/services/api_service.dart';
import '../missions/missions_screen.dart';
import '../post/presentation/screens/create_post_screen.dart';

typedef Json = Map<String, dynamic>;

Color _hex(String h, Color fallback) {
  final v = int.tryParse(h.replaceFirst("#", ""), radix: 16);
  return v == null ? fallback : Color(0xFF000000 | v);
}

/// A UAE season or moment (Eid Al Etihad, Green Ramadan, Earth Hour...) on Home.
class SeasonBanner extends StatefulWidget {
  const SeasonBanner({super.key});

  @override
  State<SeasonBanner> createState() => _SeasonBannerState();
}

class _SeasonBannerState extends State<SeasonBanner> {
  Json? _d;

  @override
  void initState() {
    super.initState();
    ApiService.dio.get("/seasons/current").then((r) {
      if (mounted && r.data["season"] is Map) setState(() => _d = Json.from(r.data as Map));
    }).catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    if (d == null) return const SizedBox.shrink();
    final s = Json.from(d["season"] as Map);
    final colors = (s["colors"] as List? ?? []).map((c) => _hex(c.toString(), const Color(0xFF1F8A70))).toList();
    final a = colors.isNotEmpty ? colors[0] : const Color(0xFF1F8A70);
    final b = colors.length > 1 ? colors[1] : const Color(0xFFF2B544);
    final ar = AppLocale.isArabic;
    final name = ar && (s["nameAr"] ?? "").toString().isNotEmpty ? s["nameAr"].toString() : s["name"].toString();
    final message = ar && (s["messageAr"] ?? "").toString().isNotEmpty ? s["messageAr"].toString() : tr(s["message"].toString());
    final actions = (d["myActions"] as num?)?.toInt() ?? 0;
    final earned = d["badgeEarned"] == true;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Material(
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => _SeasonSheet(d: d, a: a, b: b, name: name, message: message)),
          child: Ink(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [a, b], begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: Row(children: [
              Text(s["emoji"]?.toString() ?? "🌱", style: const TextStyle(fontSize: 36)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(
                    earned ? "🏅 ${tr("Badge earned")} · $actions ${tr("actions this season")}" : message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, height: 1.3),
                  ),
                ]),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SeasonSheet extends StatefulWidget {
  final Json d;
  final Color a;
  final Color b;
  final String name;
  final String message;
  const _SeasonSheet({required this.d, required this.a, required this.b, required this.name, required this.message});

  @override
  State<_SeasonSheet> createState() => _SeasonSheetState();
}

class _SeasonSheetState extends State<_SeasonSheet> {
  final _card = GlobalKey();

  Future<void> _share() async {
    try {
      final boundary = _card.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await boundary.toImage(pixelRatio: 3);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final f = File("${dir.path}/greenifyx-season.png");
      await f.writeAsBytes(bytes!.buffer.asUint8List());
      await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], text: "${widget.name} ${tr("on GreenifyX")} 🌱 ${AppConfig.publicSiteUrl}"));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = Json.from(widget.d["season"] as Map);
    final actions = (widget.d["myActions"] as num?)?.toInt() ?? 0;
    final earned = widget.d["badgeEarned"] == true;
    final ends = DateTime.tryParse(s["endsAt"]?.toString() ?? "")?.toLocal();
    final daysLeft = ends == null ? null : ends.difference(DateTime.now()).inDays + 1;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          RepaintBoundary(
            key: _card,
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: LinearGradient(colors: [widget.a, widget.b], begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s["emoji"]?.toString() ?? "🌱", style: const TextStyle(fontSize: 48)),
                const SizedBox(height: 8),
                Text(widget.name, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(widget.message, style: const TextStyle(color: Colors.white, height: 1.4)),
                const SizedBox(height: 16),
                Row(children: [
                  Text("$actions", style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(tr("verified actions by me this season"), style: const TextStyle(color: Colors.white70))),
                  if (earned)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(30)),
                      child: Text("🏅 ${s["badgeLabel"]}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                ]),
                const SizedBox(height: 8),
                const Text("GreenifyX", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          if (daysLeft != null) Text("$daysLeft ${tr("days left")}", textAlign: TextAlign.center),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => s["mission"] != null ? const MissionsScreen() : const CreatePostScreen()));
            },
            icon: const Icon(Icons.add_a_photo_rounded),
            label: Text(earned ? tr("Do another action") : tr("Take part now")),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _share, icon: const Icon(Icons.ios_share_rounded), label: Text(tr("Share"))),
        ]),
      ),
    );
  }
}
