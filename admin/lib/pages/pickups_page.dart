import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../api/admin_api.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

const _statuses = ['requested', 'scheduled', 'collected', 'cancelled'];

Color pickupColor(String s) => switch (s) {
      'scheduled' => Brand.sky,
      'collected' => Brand.eco,
      'cancelled' => Brand.danger,
      _ => Brand.sun,
    };

class PickupsPage extends StatefulWidget {
  const PickupsPage({super.key});

  @override
  State<PickupsPage> createState() => _PickupsPageState();
}

class _PickupsPageState extends State<PickupsPage> {
  List<Json>? _items;
  Json _stats = {};
  Object? _error;
  String _status = 'requested';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Session.instance.api.pickups(status: _status);
      if (!mounted) return;
      setState(() {
        _items = List<Json>.from((r['pickups'] as List? ?? const []).map((e) => Json.from(e as Map)));
        _stats = Json.from(r['stats'] as Map? ?? {});
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  int _count(String s) => ((_stats[s] as Map?)?['count'] as num?)?.toInt() ?? 0;

  Future<void> _schedule(Json p) async {
    final initial = DateTime.tryParse(p['preferredDate'] as String? ?? '')?.toLocal() ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(DateTime.now()) ? DateTime.now() : initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (d == null || !mounted) return;
    final slot = p['timeSlot'] as String? ?? 'morning';
    final hour = slot == 'evening' ? 17 : slot == 'afternoon' ? 13 : 9;
    await _update(p, {'status': 'scheduled', 'scheduledFor': DateTime(d.year, d.month, d.day, hour).toIso8601String()});
  }

  Future<void> _collect(Json p) async {
    final kg = TextEditingController(text: '${p['estimatedKg'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record collection'),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: kg,
            autofocus: true,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: const InputDecoration(labelText: 'Weighed amount (kg)', helperText: 'Member earns 10 Eco Points per kg (max 500)'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mark collected')),
        ],
      ),
    );
    if (ok != true) return;
    await _update(p, {'status': 'collected', 'collectedKg': double.tryParse(kg.text.trim()) ?? 0});
  }

  Future<void> _update(Json p, Json body) async {
    try {
      await Session.instance.api.updatePickup(p['_id'] as String, body);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pickup ${body['status']}')));
      _load();
    } on ApiError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final kg = ((_stats['collected'] as Map?)?['kg'] as num?) ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader(title: 'Recycling pickups', subtitle: 'Doorstep collections: schedule, weigh and credit Eco Points'),
      ResponsiveGrid(minWidth: 200, maxColumns: 4, children: [
        KpiCard(label: 'New requests', value: '${_count('requested')}', icon: Icons.inbox_rounded, color: Brand.sun),
        KpiCard(label: 'Scheduled', value: '${_count('scheduled')}', icon: Icons.event_available_rounded, color: Brand.sky),
        KpiCard(label: 'Collected', value: '${_count('collected')}', icon: Icons.task_alt_rounded, color: Brand.eco),
        KpiCard(label: 'Kg recycled', value: kg.toStringAsFixed(1), icon: Icons.recycling_rounded, color: Brand.coral),
      ]),
      const SizedBox(height: 16),
      Wrap(spacing: 8, children: [
        for (final s in _statuses)
          ChoiceChip(
            label: Text('$s (${_count(s)})'),
            selected: _status == s,
            onSelected: (_) {
              setState(() {
                _status = s;
                _items = null;
              });
              _load();
            },
          ),
      ]),
      const SizedBox(height: 16),
      if (_error != null)
        ErrorBox(error: _error!, onRetry: _load)
      else if (items == null)
        const Loading()
      else if (items.isEmpty)
        const Panel(child: EmptyState(icon: Icons.local_shipping_outlined, title: 'Nothing here', message: 'New pickup requests from the app will show up here.'))
      else
        Panel(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(children: [
            for (final p in items) _row(p),
          ]),
        ),
    ]);
  }

  Widget _row(Json p) {
    final user = Json.from(p['user'] as Map? ?? {});
    final status = p['status'] as String? ?? 'requested';
    final when = DateTime.tryParse((p['scheduledFor'] ?? p['preferredDate'] ?? '') as String)?.toLocal();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Brand.border))),
      child: Row(children: [
        Avatar(url: user['profileImage'] as String?, name: user['name'] as String? ?? '?'),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user['name'] as String? ?? 'Member', style: const TextStyle(fontWeight: FontWeight.w800)),
            Text('${p['address']}, ${p['emirate']}', style: const TextStyle(color: Brand.muted, fontSize: 12.5), overflow: TextOverflow.ellipsis),
            if ((p['notes'] as String? ?? '').isNotEmpty)
              Text('“${p['notes']}”', style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic), overflow: TextOverflow.ellipsis),
          ]),
        ),
        Expanded(
          flex: 2,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((p['materials'] as List? ?? []).join(', '), style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(
              status == 'collected' ? '${p['collectedKg']} kg · +${p['pointsAwarded']} pts' : '~${p['estimatedKg']} kg estimated',
              style: const TextStyle(color: Brand.muted, fontSize: 12.5),
            ),
          ]),
        ),
        Expanded(
          flex: 2,
          child: Text(
            when == null ? '-' : '${DateFormat('EEE d MMM').format(when)} · ${p['timeSlot']}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        StatusPill(status, color: pickupColor(status)),
        const SizedBox(width: 8),
        if (status == 'requested') TextButton(onPressed: () => _schedule(p), child: const Text('Schedule')),
        if (status == 'requested' || status == 'scheduled') ...[
          FilledButton.tonal(onPressed: () => _collect(p), child: const Text('Collected')),
          IconButton(
            tooltip: 'Cancel pickup',
            onPressed: () => _update(p, {'status': 'cancelled'}),
            icon: const Icon(Icons.close_rounded, color: Brand.danger),
          ),
        ],
      ]),
    );
  }
}
