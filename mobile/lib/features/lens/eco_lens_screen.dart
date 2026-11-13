import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/i18n/app_locale.dart';
import '../../core/services/api_service.dart';

typedef Json = Map<String, dynamic>;

enum _Lens { none, forest, cleanAir, sticker, leafFrame }

/// Eco Lens: impact effects drawn over a photo using the member's real numbers,
/// then baked into a new image for the post.
class EcoLensScreen extends StatefulWidget {
  final File photo;
  const EcoLensScreen({super.key, required this.photo});

  @override
  State<EcoLensScreen> createState() => _EcoLensScreenState();
}

class _EcoLensScreenState extends State<EcoLensScreen> with SingleTickerProviderStateMixin {
  final _key = GlobalKey();
  _Lens _lens = _Lens.forest;
  Json? _impact;
  bool _saving = false;
  Offset _stickerPos = const Offset(0.5, 0.18); // fraction of the frame
  late final AnimationController _grow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();

  @override
  void initState() {
    super.initState();
    ApiService.dio.get("/impact/me").then((r) {
      if (mounted) setState(() => _impact = Json.from(r.data["total"] as Map));
    }).catchError((Object _) {});
  }

  @override
  void dispose() {
    _grow.dispose();
    super.dispose();
  }

  num get _co2 => (_impact?["co2Kg"] as num?) ?? 0;
  int get _trees => math.max(3, math.min(14, (_co2 / 21).ceil() + 3));

  void _pick(_Lens l) {
    setState(() => _lens = l);
    _grow.forward(from: 0);
  }

  Future<void> _done() async {
    if (_lens == _Lens.none) return Navigator.pop(context);
    setState(() => _saving = true);
    try {
      _grow.value = 1;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final boundary = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await boundary.toImage(pixelRatio: 3);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final f = File("${dir.path}/ecolens-${DateTime.now().millisecondsSinceEpoch}.png");
      await f.writeAsBytes(bytes!.buffer.asUint8List());
      if (mounted) Navigator.pop(context, f);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr("Couldn't apply the effect. Try again."))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lenses = [
      (_Lens.none, "🚫", tr("None")),
      (_Lens.forest, "🌳", tr("Growing forest")),
      (_Lens.cleanAir, "🌬️", tr("Clean air")),
      (_Lens.sticker, "🌍", tr("My impact")),
      (_Lens.leafFrame, "🍃", tr("Leaf frame")),
    ];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(tr("Eco Lens")),
        actions: [TextButton(onPressed: _saving ? null : _done, child: Text(tr("Use"), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)))],
      ),
      body: Column(children: [
        Expanded(
          child: Center(
            child: RepaintBoundary(
              key: _key,
              child: LayoutBuilder(builder: (context, c) {
                return Stack(children: [
                  Image.file(widget.photo, fit: BoxFit.contain),
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _grow,
                      builder: (_, _) => switch (_lens) {
                        _Lens.none => const SizedBox.shrink(),
                        _Lens.forest => CustomPaint(painter: _ForestPainter(trees: _trees, t: Curves.easeOutBack.transform(_grow.value))),
                        _Lens.cleanAir => _CleanAir(t: _grow.value, co2: _co2),
                        _Lens.leafFrame => CustomPaint(painter: _LeafFramePainter(t: _grow.value)),
                        _Lens.sticker => const SizedBox.shrink(),
                      },
                    ),
                  ),
                  if (_lens == _Lens.sticker || _lens == _Lens.forest)
                    Positioned.fill(
                      child: LayoutBuilder(builder: (context, box) {
                        return Stack(children: [
                          Positioned(
                            left: _stickerPos.dx * box.maxWidth - 90,
                            top: _stickerPos.dy * box.maxHeight - 26,
                            child: GestureDetector(
                              onPanUpdate: (d) => setState(() {
                                _stickerPos = Offset(
                                  ((_stickerPos.dx * box.maxWidth + d.delta.dx) / box.maxWidth).clamp(0.15, 0.85),
                                  ((_stickerPos.dy * box.maxHeight + d.delta.dy) / box.maxHeight).clamp(0.06, 0.94),
                                );
                              }),
                              child: _ImpactSticker(co2: _co2, forest: _lens == _Lens.forest),
                            ),
                          ),
                        ]);
                      }),
                    ),
                ]);
              }),
            ),
          ),
        ),
        if (_lens == _Lens.sticker || _lens == _Lens.forest)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(tr("Drag the sticker to move it"), style: const TextStyle(color: Colors.white54, fontSize: 12))),
        SizedBox(
          height: 96,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(12), children: [
            for (final l in lenses)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => _pick(l.$1),
                  child: Container(
                    width: 86,
                    decoration: BoxDecoration(
                      color: _lens == l.$1 ? Colors.white : Colors.white12,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(l.$2, style: const TextStyle(fontSize: 24)),
                      const SizedBox(height: 4),
                      Text(l.$3, textAlign: TextAlign.center, maxLines: 2, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _lens == l.$1 ? Colors.black : Colors.white)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _ImpactSticker extends StatelessWidget {
  final num co2;
  final bool forest;
  const _ImpactSticker({required this.co2, required this.forest});

  @override
  Widget build(BuildContext context) => Container(
        width: 180,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 10)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(forest ? "🌳" : "🌍", style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 6),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text("${co2.round()} kg CO₂", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0E3B2E))),
              Text(tr("saved on GreenifyX"), style: const TextStyle(fontSize: 10.5, color: Color(0xFF1F8A70), fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      );
}

/// A row of trees growing up from the bottom edge.
class _ForestPainter extends CustomPainter {
  final int trees;
  final double t;
  _ForestPainter({required this.trees, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final ground = Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x002E7D32), Color(0xCC1B5E20)]).createShader(Rect.fromLTWH(0, size.height * 0.7, size.width, size.height * 0.3));
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.7, size.width, size.height * 0.3), ground);
    for (var i = 0; i < trees; i++) {
      final x = (i + 0.5) / trees * size.width + (rnd.nextDouble() - 0.5) * size.width / trees * 0.6;
      final h = size.height * (0.14 + rnd.nextDouble() * 0.12) * t.clamp(0.0, 1.2);
      final base = size.height;
      final trunk = Paint()..color = const Color(0xFF5D4037);
      canvas.drawRect(Rect.fromLTWH(x - 3, base - h * 0.45, 6, h * 0.45), trunk);
      final crown = Paint()..color = Color.lerp(const Color(0xFF2E7D32), const Color(0xFF66BB6A), rnd.nextDouble())!;
      canvas.drawCircle(Offset(x, base - h * 0.62), h * 0.3, crown);
      canvas.drawCircle(Offset(x - h * 0.17, base - h * 0.5), h * 0.2, crown);
      canvas.drawCircle(Offset(x + h * 0.17, base - h * 0.5), h * 0.2, crown);
    }
  }

  @override
  bool shouldRepaint(covariant _ForestPainter old) => old.t != t || old.trees != trees;
}

/// Blue sky wash and a caption about air.
class _CleanAir extends StatelessWidget {
  final double t;
  final num co2;
  const _CleanAir({required this.t, required this.co2});

  @override
  Widget build(BuildContext context) => Stack(children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [Color.fromRGBO(79, 172, 254, 0.55 * t), Color.fromRGBO(0, 242, 254, 0)],
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Opacity(
            opacity: t,
            child: Text(
              "${tr("Cleaner air, one action at a time")} · ${co2.round()} kg CO₂",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, shadows: [Shadow(blurRadius: 8, color: Colors.black54)]),
            ),
          ),
        ),
      ]);
}

/// Leaves growing in from the corners.
class _LeafFramePainter extends CustomPainter {
  final double t;
  _LeafFramePainter({required this.t});

  void _leaf(Canvas c, Offset at, double size, double angle, Color color) {
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(angle);
    final p = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(size * 0.5, -size * 0.35, size, 0)
      ..quadraticBezierTo(size * 0.5, size * 0.35, 0, 0);
    c.drawPath(p, Paint()..color = color);
    c.drawLine(Offset.zero, Offset(size, 0), Paint()..color = const Color(0x55FFFFFF)..strokeWidth = 1.2);
    c.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height) * 0.22 * Curves.easeOut.transform(t);
    const colors = [Color(0xE62E7D32), Color(0xE643A047), Color(0xE666BB6A)];
    final corners = [Offset.zero, Offset(size.width, 0), Offset(0, size.height), Offset(size.width, size.height)];
    final base = [math.pi / 4, 3 * math.pi / 4, -math.pi / 4, -3 * math.pi / 4];
    for (var i = 0; i < 4; i++) {
      for (var j = 0; j < 3; j++) {
        _leaf(canvas, corners[i], s * (1 - j * 0.2), base[i] + (j - 1) * 0.45, colors[j]);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LeafFramePainter old) => old.t != t;
}
