import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';

class LineSeries {
  const LineSeries({required this.label, required this.values, required this.color});
  final String label;
  final List<num> values;
  final Color color;
}

/// Multi-series line chart with soft area fill, gridlines and hover readout.
class TrendChart extends StatefulWidget {
  const TrendChart({super.key, required this.days, required this.series, this.height = 240});
  final List<String> days; // yyyy-MM-dd
  final List<LineSeries> series;
  final double height;

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  int? _hover;

  @override
  Widget build(BuildContext context) {
    final hover = _hover;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final s in widget.series)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 6),
                Text(
                  hover == null ? s.label : '${s.label}: ${Fmt.number(s.values[hover])}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ]),
            if (hover != null)
              Text(Fmt.shortDay(widget.days[hover]), style: const TextStyle(color: Brand.muted, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(builder: (context, c) {
            void track(Offset p) {
              final n = widget.days.length;
              if (n < 2) return;
              const left = 36.0;
              final x = (p.dx - left).clamp(0, c.maxWidth - left);
              final i = (x / (c.maxWidth - left) * (n - 1)).round().clamp(0, n - 1);
              if (i != _hover) setState(() => _hover = i);
            }

            return MouseRegion(
              onHover: (e) => track(e.localPosition),
              onExit: (_) => setState(() => _hover = null),
              child: GestureDetector(
                onPanDown: (d) => track(d.localPosition),
                onPanUpdate: (d) => track(d.localPosition),
                onPanEnd: (_) => setState(() => _hover = null),
                child: CustomPaint(
                  size: Size(c.maxWidth, widget.height),
                  painter: _TrendPainter(widget.days, widget.series, hover),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.days, this.series, this.hover);
  final List<String> days;
  final List<LineSeries> series;
  final int? hover;

  static const _left = 36.0;
  static const _bottom = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    final n = days.length;
    if (n < 2) return;
    final maxV = series.expand((s) => s.values).fold<num>(0, (m, v) => math.max(m, v));
    final top = _niceCeil(maxV.toDouble());
    final w = size.width - _left;
    final h = size.height - _bottom;

    final grid = Paint()
      ..color = Brand.border
      ..strokeWidth = 1;
    const labelStyle = TextStyle(color: Brand.muted, fontSize: 11);

    for (var i = 0; i <= 4; i++) {
      final y = h - h * i / 4;
      canvas.drawLine(Offset(_left, y), Offset(size.width, y), grid);
      _text(canvas, Fmt.compact(top * i / 4), Offset(0, y - 7), labelStyle, width: _left - 6, align: TextAlign.right);
    }

    final step = (n / 6).ceil();
    for (var i = 0; i < n; i += step) {
      final x = _left + w * i / (n - 1);
      _text(canvas, Fmt.shortDay(days[i]), Offset(x - 24, h + 6), labelStyle, width: 48, align: TextAlign.center);
    }

    for (final s in series) {
      final pts = <Offset>[
        for (var i = 0; i < n; i++) Offset(_left + w * i / (n - 1), h - (top == 0 ? 0 : h * s.values[i] / top)),
      ];
      final line = _smooth(pts);
      final area = Path.from(line)
        ..lineTo(pts.last.dx, h)
        ..lineTo(pts.first.dx, h)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [s.color.withValues(alpha: 0.18), s.color.withValues(alpha: 0.0)],
          ).createShader(Rect.fromLTWH(0, 0, size.width, h)),
      );
      canvas.drawPath(
        line,
        Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
      if (hover != null) {
        canvas.drawCircle(pts[hover!], 5, Paint()..color = Colors.white);
        canvas.drawCircle(pts[hover!], 3.5, Paint()..color = s.color);
      }
    }

    if (hover != null) {
      final x = _left + w * hover! / (n - 1);
      canvas.drawLine(Offset(x, 0), Offset(x, h), Paint()..color = Brand.ink.withValues(alpha: 0.18));
    }
  }

  Path _smooth(List<Offset> p) {
    final path = Path()..moveTo(p.first.dx, p.first.dy);
    for (var i = 0; i < p.length - 1; i++) {
      final a = p[i];
      final b = p[i + 1];
      final mid = (a.dx + b.dx) / 2;
      path.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
    }
    return path;
  }

  double _niceCeil(double v) {
    if (v <= 4) return 4;
    final mag = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    for (final f in [1, 2, 2.5, 5, 10]) {
      if (f * mag >= v) return f * mag;
    }
    return 10 * mag;
  }

  void _text(Canvas c, String s, Offset o, TextStyle st, {required double width, TextAlign align = TextAlign.left}) {
    final tp = TextPainter(text: TextSpan(text: s, style: st), textAlign: align, textDirection: TextDirection.ltr)
      ..layout(minWidth: width, maxWidth: width);
    tp.paint(c, o);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => old.series != series || old.hover != hover || old.days != days;
}

class BarItem {
  const BarItem(this.label, this.value, {this.color, this.note});
  final String label;
  final num value;
  final Color? color;
  final String? note;
}

/// Horizontal ranked bars with labels and values. Accessible and readable at any width.
class BarList extends StatelessWidget {
  const BarList({super.key, required this.items, this.color = Brand.eco, this.valueLabel});
  final List<BarItem> items;
  final Color color;
  final String Function(num value)? valueLabel;

  @override
  Widget build(BuildContext context) {
    final maxV = items.fold<num>(0, (m, e) => math.max(m, e.value));
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(item.label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    if (item.note != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Text(item.note!, style: const TextStyle(color: Brand.muted, fontSize: 12)),
                      ),
                    Text(valueLabel?.call(item.value) ?? Fmt.number(item.value),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: maxV == 0 ? 0 : item.value / maxV,
                    minHeight: 8,
                    backgroundColor: Brand.canvas,
                    color: item.color ?? color,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
