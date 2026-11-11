import 'package:flutter/material.dart';

import '../api/admin_api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/loader.dart';

class ImpactPage extends StatelessWidget {
  const ImpactPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Loader<Json>(
      load: Session.instance.api.stats,
      builder: (context, stats, reload) => _Impact(stats: stats, reload: reload),
    );
  }
}

class _Impact extends StatelessWidget {
  const _Impact({required this.stats, required this.reload});
  final Json stats;
  final VoidCallback reload;

  @override
  Widget build(BuildContext context) {
    final k = Json.from(stats['kpis'] as Map);
    final impact = List<Json>.from((stats['impactByActivity'] as List? ?? const []).map((e) => Json.from(e as Map)));
    final emirates = List<Json>.from((stats['byEmirate'] as List).map((e) => Json.from(e as Map)));
    final co2 = (k['co2SavedKg'] as num?)?.toDouble() ?? 0;
    final reached = emirates.where((e) => e['emirate'] != 'Not set' && (e['count'] as num) > 0).length;

    // Plain-language equivalents help non-technical stakeholders.
    final treeYears = co2 / 21;
    final carKm = co2 / 0.17;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Environmental impact',
          subtitle: 'Estimated from community-verified actions only',
          actions: [
            OutlinedButton.icon(onPressed: reload, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Refresh')),
          ],
        ),
        _Hero(co2: co2, treeYears: treeYears, carKm: carKm),
        const SizedBox(height: 16),
        ResponsiveGrid(children: [
          KpiCard(label: 'Verified actions', value: Fmt.number(k['verifiedPosts'] as num?), icon: Icons.verified_rounded, color: Brand.eco),
          KpiCard(label: 'Verification rate', value: '${k['verificationRate']}%', icon: Icons.fact_check_rounded, color: Brand.sky,
              caption: 'Confirmed by a friend'),
          KpiCard(label: 'Emirates reached', value: '$reached / 7', icon: Icons.map_rounded, color: Brand.coral),
          KpiCard(label: 'Eco Points issued', value: Fmt.compact(k['ecoPointsIssued'] as num?), icon: Icons.stars_rounded, color: Brand.sun),
        ]),
        const SizedBox(height: 16),
        ResponsiveGrid(minWidth: 420, maxColumns: 2, children: [
          Panel(
            title: 'CO₂ saved by action',
            child: impact.isEmpty
                ? const EmptyState(icon: Icons.eco_outlined, title: 'No verified actions yet',
                    message: 'Impact appears once friends verify posts.')
                : BarList(
                    color: Brand.eco,
                    valueLabel: Fmt.co2,
                    items: [
                      for (var i = 0; i < impact.length; i++)
                        BarItem(
                          impact[i]['activity'] as String,
                          impact[i]['co2Kg'] as num,
                          note: '${Fmt.number(impact[i]['verifiedActions'] as num?)} actions',
                          color: Brand.series[i % Brand.series.length],
                        ),
                    ],
                  ),
          ),
          Panel(
            title: 'Members by emirate',
            child: BarList(
              color: Brand.sky,
              items: [
                for (final e in emirates)
                  if (e['emirate'] != 'Not set' || (e['count'] as num) > 0)
                    BarItem(e['emirate'] as String, e['count'] as num,
                        color: e['emirate'] == 'Not set' ? Brand.border : Brand.sky),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 16),
        const Panel(
          title: 'How these numbers are calculated',
          child: Text(
            'Each verified action is multiplied by a conservative per-action estimate, for example about 21 kg CO₂ '
            'for a planted tree (one year of absorption) and about 1.2 kg for a cycled trip that replaced a car. '
            'Only posts a friend has verified are counted. These are indicative planning figures for engagement '
            'reporting, not certified carbon measurement.',
            style: TextStyle(color: Brand.muted, height: 1.6),
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.co2, required this.treeYears, required this.carKm});
  final double co2;
  final double treeYears;
  final double carKm;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(colors: [Brand.eco, Color(0xFF16664F)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Wrap(
        spacing: 40,
        runSpacing: 20,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Estimated CO₂ saved', style: t.titleMedium?.copyWith(color: Colors.white.withValues(alpha: 0.8))),
            const SizedBox(height: 6),
            Text(Fmt.co2(co2), style: t.displayMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          ]),
          _Equiv(icon: Icons.park_rounded, value: Fmt.number(treeYears.round()), label: 'tree-years of absorption'),
          _Equiv(icon: Icons.directions_car_rounded, value: Fmt.compact(carKm.round()), label: 'km of car driving avoided'),
        ],
      ),
    );
  }
}

class _Equiv extends StatelessWidget {
  const _Equiv({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: Colors.white),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22)),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
      ]),
    ]);
  }
}
