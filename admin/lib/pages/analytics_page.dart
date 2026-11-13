import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/admin_api.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/loader.dart';

/// Growth analytics: DAU/WAU/MAU, retention cohorts, activation funnel,
/// emirate breakdown and an activity heat map of the UAE.
class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Loader<Json>(
      load: () => Session.instance.api.analytics(),
      builder: (context, d, reload) => _Body(d: d, reload: reload),
    );
  }
}

List<Json> _list(Object? v) => [for (final x in (v as List? ?? const [])) if (x is Map) Json.from(x)];
num _n(Object? v) => v is num ? v : num.tryParse('$v') ?? 0;

class _Body extends StatelessWidget {
  const _Body({required this.d, required this.reload});
  final Json d;
  final VoidCallback reload;

  String _csv() {
    final b = StringBuffer();
    final e = Json.from(d['engagement'] as Map? ?? const {});
    b.writeln('Metric,Value');
    for (final k in ['dau', 'wau', 'mau', 'stickiness', 'totalUsers']) {
      b.writeln('$k,${e[k] ?? 0}');
    }
    b.writeln('\nDate,Active users');
    for (final r in _list(d['daily'])) {
      b.writeln('${r['date']},${r['active']}');
    }
    b.writeln('\nFunnel step,Users');
    for (final r in _list(d['funnel'])) {
      b.writeln('"${r['step']}",${r['users']}');
    }
    b.writeln('\nEmirate,Users,Active 30d,Verified actions,CO2 kg,Top activity');
    for (final r in _list(d['emirates'])) {
      b.writeln('${r['emirate']},${r['users']},${r['activeUsers30d']},${r['verifiedActions']},${r['co2Kg']},"${r['topActivity']}"');
    }
    b.writeln('\nCohort week,Size,${List.generate(8, (i) => 'W$i').join(',')}');
    for (final r in _list(d['cohorts'])) {
      b.writeln('${r['week']},${r['size']},${(r['retention'] as List? ?? const []).map((x) => x ?? '').join(',')}');
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final e = Json.from(d['engagement'] as Map? ?? const {});
    final daily = _list(d['daily']);
    final funnel = _list(d['funnel']);
    final emirates = _list(d['emirates'])..sort((a, b) => _n(b['users']).compareTo(_n(a['users'])));
    final trust = Json.from(d['trust'] as Map? ?? const {});
    final top = _list(d['topActivities']);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Analytics',
        subtitle: 'Who is active, who comes back, and where the impact happens',
        actions: [
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _csv()));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV copied. Paste it into Excel or Google Sheets.')));
              }
            },
            icon: const Icon(Icons.table_view_rounded, size: 18),
            label: const Text('Copy CSV'),
          ),
          const SizedBox(width: 8),
          IconButton(tooltip: 'Refresh', onPressed: reload, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      ResponsiveGrid(minWidth: 200, maxColumns: 5, children: [
        KpiCard(label: 'Daily active', value: '${e['dau'] ?? 0}', icon: Icons.today_rounded, color: Brand.coral),
        KpiCard(label: 'Weekly active', value: '${e['wau'] ?? 0}', icon: Icons.date_range_rounded, color: Brand.sky),
        KpiCard(label: 'Monthly active', value: '${e['mau'] ?? 0}', icon: Icons.calendar_month_rounded, color: Brand.eco),
        KpiCard(label: 'Stickiness', value: '${e['stickiness'] ?? 0}%', icon: Icons.favorite_rounded, color: Brand.sun, caption: 'DAU ÷ MAU'),
        KpiCard(
          label: 'AI verified (30d)',
          value: '${trust['aiVerified30d'] ?? 0}',
          icon: Icons.auto_awesome_rounded,
          color: const Color(0xFF8A5CC2),
          caption: '${trust['flagged30d'] ?? 0} flagged for review',
        ),
      ]),
      const SizedBox(height: 16),
      Panel(
        title: 'Daily active users · last 30 days',
        child: daily.isEmpty
            ? const EmptyState(icon: Icons.show_chart_rounded, title: 'No activity yet')
            : TrendChart(
                days: [for (final r in daily) '${r['date']}'],
                series: [LineSeries(label: 'Active users', values: [for (final r in daily) _n(r['active'])], color: Brand.coral)],
              ),
      ),
      const SizedBox(height: 16),
      ResponsiveGrid(minWidth: 420, maxColumns: 2, children: [
        Panel(title: 'Activation funnel · new users, 90 days', child: _Funnel(steps: funnel)),
        Panel(
          title: 'Top activities · 30 days',
          child: top.isEmpty
              ? const EmptyState(icon: Icons.eco_rounded, title: 'No posts yet')
              : BarList(
                  items: [
                    for (final t in top)
                      BarItem('${t['activity'] ?? '—'}', _n(t['posts']), note: '${t['verified'] ?? 0} verified'),
                  ],
                ),
        ),
      ]),
      const SizedBox(height: 16),
      Panel(
        title: 'Weekly retention cohorts',
        trailing: const Text('% of each signup week still active', style: TextStyle(color: Brand.muted, fontSize: 12)),
        child: _Cohorts(rows: _list(d['cohorts'])),
      ),
      const SizedBox(height: 16),
      ResponsiveGrid(minWidth: 420, maxColumns: 2, children: [
        Panel(title: 'Impact heat map', child: _HeatMap(points: _list(d['heat']))),
        Panel(title: 'By emirate', child: _Emirates(rows: emirates)),
      ]),
      const SizedBox(height: 24),
    ]);
  }
}

class _Funnel extends StatelessWidget {
  const _Funnel({required this.steps});
  final List<Json> steps;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const EmptyState(icon: Icons.filter_alt_rounded, title: 'No signups yet');
    final first = math.max(1, _n(steps.first['users']).toInt());
    return Column(children: [
      for (var i = 0; i < steps.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: LayoutBuilder(builder: (context, c) {
            final users = _n(steps[i]['users']).toInt();
            final pct = users / first;
            final prev = i == 0 ? users : _n(steps[i - 1]['users']).toInt();
            final drop = i == 0 || prev == 0 ? null : 100 - (users * 100 / prev).round();
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${steps[i]['step']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                Text('$users', style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                SizedBox(width: 48, child: Text('${(pct * 100).round()}%', textAlign: TextAlign.end, style: const TextStyle(color: Brand.muted))),
              ]),
              const SizedBox(height: 6),
              Stack(children: [
                Container(height: 12, decoration: BoxDecoration(color: Brand.canvas, borderRadius: BorderRadius.circular(6))),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  height: 12,
                  width: c.maxWidth * pct.clamp(0.0, 1.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Brand.series[i % Brand.series.length], Brand.series[(i + 1) % Brand.series.length]]),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ]),
              if (drop != null && drop > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('−$drop% from previous step', style: const TextStyle(fontSize: 11.5, color: Brand.muted)),
                ),
            ]);
          }),
        ),
    ]);
  }
}

class _Cohorts extends StatelessWidget {
  const _Cohorts({required this.rows});
  final List<Json> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const EmptyState(icon: Icons.grid_on_rounded, title: 'Not enough history yet');
    final weeks = rows.fold<int>(0, (m, r) => math.max(m, (r['retention'] as List? ?? const []).length));
    Widget cell(String text, {Color? bg, Color fg = Brand.ink, bool bold = false, double w = 58}) => Container(
          width: w,
          height: 34,
          margin: const EdgeInsets.all(1.5),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
          child: Text(text, style: TextStyle(fontSize: 12.5, color: fg, fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          cell('Signup week', w: 110, bold: true, fg: Brand.muted),
          cell('Users', bold: true, fg: Brand.muted),
          for (var i = 0; i < weeks; i++) cell('Week $i', bold: true, fg: Brand.muted),
        ]),
        for (final r in rows)
          Row(children: [
            cell('${r['week']}', w: 110),
            cell('${r['size'] ?? 0}', bold: true),
            for (var i = 0; i < weeks; i++)
              () {
                final list = r['retention'] as List? ?? const [];
                final v = i < list.length ? list[i] : null;
                if (v == null) return cell('', bg: Brand.canvas.withValues(alpha: 0.5));
                final p = _n(v).toDouble();
                return cell('${p.round()}%', bg: Color.lerp(const Color(0xFFEFF7F4), Brand.eco, (p / 100).clamp(0, 1)), fg: p > 55 ? Colors.white : Brand.ink);
              }(),
          ]),
      ]),
    );
  }
}

class _Emirates extends StatelessWidget {
  const _Emirates({required this.rows});
  final List<Json> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const EmptyState(icon: Icons.location_city_rounded, title: 'No users yet');
    const head = TextStyle(fontWeight: FontWeight.w800, color: Brand.muted, fontSize: 12.5);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 44,
        columnSpacing: 22,
        columns: const [
          DataColumn(label: Text('Emirate', style: head)),
          DataColumn(label: Text('Users', style: head), numeric: true),
          DataColumn(label: Text('Active 30d', style: head), numeric: true),
          DataColumn(label: Text('Verified', style: head), numeric: true),
          DataColumn(label: Text('CO₂ kg', style: head), numeric: true),
          DataColumn(label: Text('Top activity', style: head)),
        ],
        rows: [
          for (final r in rows)
            DataRow(cells: [
              DataCell(Text('${r['emirate']}', style: const TextStyle(fontWeight: FontWeight.w700))),
              DataCell(Text('${r['users'] ?? 0}')),
              DataCell(Text('${r['activeUsers30d'] ?? 0}')),
              DataCell(Text('${r['verifiedActions'] ?? 0}')),
              DataCell(Text('${r['co2Kg'] ?? 0}')),
              DataCell(Text('${r['topActivity'] ?? '—'}')),
            ]),
        ],
      ),
    );
  }
}

const _kindColors = {
  'campaign': Brand.eco,
  'report': Brand.coral,
  'pickup': Brand.sky,
  'event': Color(0xFF8A5CC2),
  'checkin': Brand.sun,
};

/// UAE outline-free heat map: every activity location drawn as a glowing dot
/// sized by how many people took part, with the main cities as landmarks.
class _HeatMap extends StatelessWidget {
  const _HeatMap({required this.points});
  final List<Json> points;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AspectRatio(
        aspectRatio: 1.35,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: CustomPaint(painter: _HeatPainter(points), child: const SizedBox.expand()),
        ),
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 14, runSpacing: 6, children: [
        for (final k in _kindColors.entries)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: k.value, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('${k.key[0].toUpperCase()}${k.key.substring(1)}s · ${points.where((p) => p['kind'] == k.key).length}',
                style: const TextStyle(fontSize: 12, color: Brand.muted)),
          ]),
      ]),
    ]);
  }
}

class _HeatPainter extends CustomPainter {
  _HeatPainter(this.points);
  final List<Json> points;

  static const _minLat = 22.6, _maxLat = 26.2, _minLng = 51.5, _maxLng = 56.5;
  static const _cities = [
    ('Abu Dhabi', 24.4539, 54.3773),
    ('Dubai', 25.2048, 55.2708),
    ('Sharjah', 25.3463, 55.4209),
    ('Ajman', 25.4052, 55.5136),
    ('Umm Al Quwain', 25.5647, 55.5552),
    ('Ras Al Khaimah', 25.8007, 55.9762),
    ('Fujairah', 25.1288, 56.3265),
    ('Al Ain', 24.2075, 55.7447),
  ];

  Offset _at(Size s, double lat, double lng) =>
      Offset((lng - _minLng) / (_maxLng - _minLng) * s.width, (1 - (lat - _minLat) / (_maxLat - _minLat)) * s.height);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFEAF4FB), Color(0xFFF7F1E8)]).createShader(Offset.zero & size),
    );
    final grid = Paint()
      ..color = const Color(0x14000000)
      ..strokeWidth = 1;
    for (var i = 1; i < 6; i++) {
      canvas.drawLine(Offset(size.width * i / 6, 0), Offset(size.width * i / 6, size.height), grid);
      canvas.drawLine(Offset(0, size.height * i / 6), Offset(size.width, size.height * i / 6), grid);
    }
    final maxW = points.fold<num>(1, (m, p) => math.max(m, _n(p['weight'])));
    for (final p in points) {
      final lat = _n(p['lat']).toDouble(), lng = _n(p['lng']).toDouble();
      if (lat < _minLat || lat > _maxLat || lng < _minLng || lng > _maxLng) continue;
      final c = _kindColors[p['kind']] ?? Brand.coral;
      final r = 6 + 22 * math.sqrt(_n(p['weight']) / maxW);
      final o = _at(size, lat, lng);
      canvas.drawCircle(o, r, Paint()..shader = RadialGradient(colors: [c.withValues(alpha: 0.55), c.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: o, radius: r)));
      canvas.drawCircle(o, 2.6, Paint()..color = c);
    }
    for (final city in _cities) {
      final o = _at(size, city.$2, city.$3);
      canvas.drawCircle(o, 3, Paint()..color = Brand.ink);
      final tp = TextPainter(
        text: TextSpan(text: city.$1, style: const TextStyle(color: Brand.ink, fontSize: 11, fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, o + const Offset(6, -7));
    }
  }

  @override
  bool shouldRepaint(_HeatPainter old) => old.points != points;
}
