import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/app_locale.dart';
import '../theme/app_colors.dart';

/// Moments of joy: confetti, a vibration and a chime for big moments
/// (first ever, streak milestone, streak saved, level up), and a small pop for points.
class Celebration {
  Celebration._();

  static const _soundKey = "celebration_sound";
  static OverlayEntry? _entry;
  static AudioPlayer? _player;

  static Future<bool> soundOn() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool(_soundKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> setSound(bool on) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_soundKey, on);
    } catch (_) {}
  }

  static Future<void> _chime() async {
    if (!await soundOn()) return;
    try {
      _player ??= AudioPlayer();
      await _player!.setAsset("assets/sounds/celebrate.wav");
      await _player!.setVolume(0.6);
      await _player!.play();
    } catch (_) {}
  }

  /// Show a moment from the server: { big, emoji, title, message }.
  static void show(BuildContext context, Map<String, dynamic> m) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _entry?.remove();
    final big = m["big"] == true;
    if (big) {
      HapticFeedback.heavyImpact();
      _chime();
    } else {
      HapticFeedback.lightImpact();
    }
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CelebrationView(
        big: big,
        emoji: m["emoji"]?.toString() ?? "✨",
        title: tr(m["title"]?.toString() ?? ""),
        message: m["message"]?.toString() ?? "",
        onDone: () {
          if (_entry == entry) _entry = null;
          entry.remove();
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }
}

class _CelebrationView extends StatefulWidget {
  final bool big;
  final String emoji;
  final String title;
  final String message;
  final VoidCallback onDone;
  const _CelebrationView({required this.big, required this.emoji, required this.title, required this.message, required this.onDone});

  @override
  State<_CelebrationView> createState() => _CelebrationViewState();
}

class _CelebrationViewState extends State<_CelebrationView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Duration(milliseconds: widget.big ? 3200 : 2000))..forward().whenComplete(widget.onDone);
  late final List<_Piece> _pieces = List.generate(widget.big ? 90 : 0, (i) => _Piece.random(math.Random(i * 7919 + DateTime.now().millisecond)));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return IgnorePointer(
      ignoring: !widget.big,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          // Card slides in, stays, then fades out over the last 15%.
          final appear = Curves.easeOutBack.transform((t / 0.15).clamp(0.0, 1.0));
          final fade = t > 0.85 ? 1 - (t - 0.85) / 0.15 : 1.0;
          return Stack(children: [
            if (widget.big && !reduceMotion) Positioned.fill(child: CustomPaint(painter: _ConfettiPainter(_pieces, t))),
            Positioned(
              left: 24,
              right: 24,
              top: widget.big ? MediaQuery.sizeOf(context).height * 0.32 : null,
              bottom: widget.big ? null : 100 + MediaQuery.paddingOf(context).bottom,
              child: Opacity(
                opacity: fade.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.7 + 0.3 * appear,
                  child: GestureDetector(
                    onTap: widget.onDone,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: widget.big ? 22 : 12),
                        decoration: BoxDecoration(
                          color: widget.big ? AppColors.inkFixed : AppColors.eco,
                          borderRadius: BorderRadius.circular(widget.big ? 26 : 40),
                          boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(0, 10))],
                        ),
                        child: widget.big
                            ? Column(mainAxisSize: MainAxisSize.min, children: [
                                Text(widget.emoji, style: const TextStyle(fontSize: 52)),
                                const SizedBox(height: 8),
                                Text(widget.title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                                if (widget.message.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(widget.message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, height: 1.35)),
                                ],
                              ])
                            : Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                                Text(widget.emoji, style: const TextStyle(fontSize: 20)),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    widget.message.isEmpty ? widget.title : "${widget.title} · ${widget.message}",
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _Piece {
  final double x;
  final double delay;
  final double speed;
  final double drift;
  final double size;
  final double spin;
  final Color color;
  _Piece(this.x, this.delay, this.speed, this.drift, this.size, this.spin, this.color);

  static const _colors = [Color(0xFFE36A4A), Color(0xFFF2B544), Color(0xFF1F8A70), Color(0xFF4CC9A0), Color(0xFF7F53AC), Color(0xFF00B4DB)];

  factory _Piece.random(math.Random r) => _Piece(
        r.nextDouble(),
        r.nextDouble() * 0.25,
        0.7 + r.nextDouble() * 0.6,
        (r.nextDouble() - 0.5) * 0.2,
        5 + r.nextDouble() * 6,
        (r.nextDouble() - 0.5) * 12,
        _colors[r.nextInt(_colors.length)],
      );
}

class _ConfettiPainter extends CustomPainter {
  final List<_Piece> pieces;
  final double t;
  _ConfettiPainter(this.pieces, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -20 + local * p.speed * (size.height + 40);
      final x = (p.x + p.drift * local + math.sin(local * 10 + p.x * 6) * 0.02) * size.width;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * local);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6), Paint()..color = p.color.withValues(alpha: (1 - local * 0.6).clamp(0.0, 1.0)));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}
