import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../api/admin_api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'users_page.dart' show emirates;

const _kindLabel = {'bin': 'Recycling bin', 'reverse_vending': 'Reverse-vending machine', 'centre': 'Recycling centre'};
const _statusLabel = {'active': 'Open', 'full': 'Full', 'out_of_service': 'Out of service', 'retired': 'Retired'};

/// Recycling drop-off network: stations, their QR codes, status and estimated volumes.
class StationsPage extends StatefulWidget {
  const StationsPage({super.key});

  @override
  State<StationsPage> createState() => _StationsPageState();
}

class _StationsPageState extends State<StationsPage> {
  Json? _data;
  Object? _error;
  int _days = 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = await Session.instance.api.getJson('/admin/stations', query: {'days': _days});
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _edit([Json? s]) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => _StationDialog(station: s, materials: Json.from(_data!['materials'] as Map)));
    if (ok == true) _load();
  }

  void _qr(Json s) => showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(s['name'] as String? ?? ''),
          content: SizedBox(
            width: 280,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              QrImageView(data: s['code'] as String, size: 240, backgroundColor: Colors.white),
              const SizedBox(height: 8),
              SelectableText(s['code'] as String, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2, fontSize: 18)),
              const SizedBox(height: 4),
              const Text('Print and stick this on the station. Members scan it in the app after a drop-off.', textAlign: TextAlign.center, style: TextStyle(color: Brand.muted, fontSize: 12.5)),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final stations = List<Json>.from((d?['stations'] as List? ?? []).map((e) => Json.from(e as Map)));
    final byEmirate = List<Json>.from((d?['byEmirate'] as List? ?? []).map((e) => Json.from(e as Map)));
    final totalKg = stations.fold<double>(0, (s, x) => s + ((x['kg'] as num?)?.toDouble() ?? 0));
    final drops = stations.fold<int>(0, (s, x) => s + ((x['dropoffs'] as num?)?.toInt() ?? 0));
    final attention = stations.where((s) => s['status'] == 'full' || s['status'] == 'out_of_service' || ((s['reports'] as Map?)?.values.any((v) => (v as num) > 0) ?? false)).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Recycling stations',
        subtitle: 'QR-coded bins and reverse-vending machines. Kilograms are estimates from what members report.',
        actions: [
          SegmentedButton<int>(
            segments: const [ButtonSegment(value: 7, label: Text('7 days')), ButtonSegment(value: 30, label: Text('30 days')), ButtonSegment(value: 90, label: Text('90 days'))],
            selected: {_days},
            onSelectionChanged: (s) {
              setState(() => _days = s.first);
              _load();
            },
          ),
          FilledButton.icon(onPressed: d == null ? null : () => _edit(), icon: const Icon(Icons.add_rounded), label: const Text('Add station')),
        ],
      ),
      if (_error != null)
        ErrorBox(error: _error!, onRetry: _load)
      else if (d == null)
        const Loading()
      else ...[
        ResponsiveGrid(minWidth: 200, maxColumns: 4, children: [
          KpiCard(label: 'Stations', value: Fmt.number(stations.length), icon: Icons.recycling_rounded, color: Brand.eco),
          KpiCard(label: 'Drop-offs', value: Fmt.number(drops), icon: Icons.inventory_2_rounded, color: Brand.sky),
          KpiCard(label: 'Estimated kg', value: Fmt.number(totalKg.round()), icon: Icons.scale_rounded, color: Brand.coral),
          KpiCard(label: 'Need attention', value: Fmt.number(attention), icon: Icons.report_problem_rounded, color: Brand.sun),
        ]),
        if (byEmirate.isNotEmpty) ...[
          const SizedBox(height: 12),
          Panel(
            child: Wrap(spacing: 12, runSpacing: 8, children: [
              for (final e in byEmirate) StatusPill('${e['emirate']}: ${e['kg']} kg · ${e['dropoffs']} drop-offs', color: Brand.eco),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        Panel(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: stations.isEmpty
              ? const EmptyState(icon: Icons.recycling_rounded, title: 'No stations yet')
              : Column(children: [
                  for (final s in stations)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Brand.border))),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${s['name']} · ${s['code']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text(
                              '${_kindLabel[s['kind']] ?? s['kind']} · ${s['emirate'] ?? ''} · ${s['dropoffs']} drop-offs · ${s['kg']} kg · ${s['people']} people'
                              '${((s['reports'] as Map?)?['full'] ?? 0) > 0 ? ' · reported full ×${(s['reports'] as Map)['full']}' : ''}'
                              '${((s['reports'] as Map?)?['broken'] ?? 0) > 0 ? ' · broken ×${(s['reports'] as Map)['broken']}' : ''}',
                              style: const TextStyle(color: Brand.muted, fontSize: 12.5),
                            ),
                          ]),
                        ),
                        StatusPill(_statusLabel[s['status']] ?? s['status'] as String, color: s['status'] == 'active' ? Brand.eco : Brand.danger),
                        IconButton(tooltip: 'QR code', onPressed: () => _qr(s), icon: const Icon(Icons.qr_code_2_rounded)),
                        IconButton(tooltip: 'Edit', onPressed: () => _edit(s), icon: const Icon(Icons.edit_rounded)),
                      ]),
                    ),
                ]),
        ),
      ],
    ]);
  }
}

class _StationDialog extends StatefulWidget {
  const _StationDialog({this.station, required this.materials});
  final Json? station;
  final Json materials;

  @override
  State<_StationDialog> createState() => _StationDialogState();
}

class _StationDialogState extends State<_StationDialog> {
  late final _name = TextEditingController(text: widget.station?['name'] as String? ?? '');
  late final _address = TextEditingController(text: widget.station?['address'] as String? ?? '');
  late final _operator = TextEditingController(text: widget.station?['operator'] as String? ?? '');
  late final _lat = TextEditingController(text: '${(widget.station?['location'] as Map?)?['lat'] ?? ''}');
  late final _lng = TextEditingController(text: '${(widget.station?['location'] as Map?)?['lng'] ?? ''}');
  late String _kind = widget.station?['kind'] as String? ?? 'bin';
  late String _status = widget.station?['status'] as String? ?? 'active';
  late String _emirate = (widget.station?['emirate'] as String?)?.isNotEmpty == true ? widget.station!['emirate'] as String : 'Dubai';
  late final Set<String> _mats = {...List<String>.from(widget.station?['materials'] as List? ?? ['plastic', 'cans'])};
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = {
      'name': _name.text.trim(),
      'address': _address.text.trim(),
      'operator': _operator.text.trim(),
      'kind': _kind,
      'status': _status,
      'emirate': _emirate,
      'materials': _mats.toList(),
      if (double.tryParse(_lat.text.trim()) != null && double.tryParse(_lng.text.trim()) != null) ...{'lat': double.parse(_lat.text.trim()), 'lng': double.parse(_lng.text.trim())},
      if (widget.station != null) 'clearReports': true,
    };
    try {
      final id = widget.station?['_id'] as String?;
      id == null ? await Session.instance.api.postJson('/admin/stations', body) : await Session.instance.api.patchJson('/admin/stations/$id', body);
      if (mounted) Navigator.pop(context, true);
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coord = [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.]'))];
    return AlertDialog(
      title: Text(widget.station == null ? 'Add station' : 'Edit station'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name (e.g. Al Barsha Park gate 2)')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _kind,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [for (final k in _kindLabel.entries) DropdownMenuItem(value: k.key, child: Text(k.value))],
                  onChanged: (v) => setState(() => _kind = v ?? _kind),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _emirate,
                  decoration: const InputDecoration(labelText: 'Emirate'),
                  items: [for (final e in emirates) DropdownMenuItem(value: e, child: Text(e))],
                  onChanged: (v) => setState(() => _emirate = v ?? _emirate),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(controller: _address, decoration: const InputDecoration(labelText: 'Address or landmark')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: _lat, inputFormatters: coord, decoration: const InputDecoration(labelText: 'Latitude'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _lng, inputFormatters: coord, decoration: const InputDecoration(labelText: 'Longitude'))),
            ]),
            const SizedBox(height: 12),
            TextField(controller: _operator, decoration: const InputDecoration(labelText: 'Operator (e.g. municipality or partner)')),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: Text('Materials accepted', style: Theme.of(context).textTheme.labelLarge)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final m in widget.materials.entries)
                FilterChip(
                  label: Text((m.value as Map)['label'] as String),
                  selected: _mats.contains(m.key),
                  onSelected: (v) => setState(() => v ? _mats.add(m.key) : _mats.remove(m.key)),
                ),
            ]),
            if (widget.station != null) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status', helperText: 'Saving clears member reports'),
                items: [for (final s in _statusLabel.entries) DropdownMenuItem(value: s.key, child: Text(s.value))],
                onChanged: (v) => setState(() => _status = v ?? _status),
              ),
            ],
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Brand.danger))),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save')),
      ],
    );
  }
}
