import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../api/admin_api.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'users_page.dart' show emirates;

const _types = {
  'recycling_bin': ('Recycling bin', Icons.delete_outline_rounded),
  'refill_station': ('Refill station', Icons.water_drop_rounded),
  'event': ('Event', Icons.event_rounded),
  'partner': ('Partner store', Icons.storefront_rounded),
  'campaign': ('Campaign site', Icons.forest_rounded),
};

/// Printable QR codes at real places. Scanning one in the app proves presence and credits points.
class CheckpointsPage extends StatefulWidget {
  const CheckpointsPage({super.key});

  @override
  State<CheckpointsPage> createState() => _CheckpointsPageState();
}

class _CheckpointsPageState extends State<CheckpointsPage> {
  List<Json>? _items;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final items = await Session.instance.api.checkpoints();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _edit([Json? cp]) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => _CheckpointDialog(cp: cp));
    if (ok == true) _load();
  }

  void _showQr(Json cp) {
    final data = cp['qr'] as String? ?? 'greenifyx://checkin/${cp['code']}';
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset('assets/brand/app_icon_rounded.png', width: 32, height: 32)),
              const SizedBox(width: 10),
              const Text('GreenifyX', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            ]),
            const SizedBox(height: 16),
            Text(cp['name'] as String? ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Scan with the GreenifyX app · +${cp['points']} Eco Points', style: const TextStyle(color: Brand.muted)),
            const SizedBox(height: 16),
            QrImageView(data: data, size: 260, eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Brand.ink)),
            const SizedBox(height: 10),
            SelectableText(cp['code'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2)),
            const SizedBox(height: 8),
            const Text('Tip: take a screenshot or use your browser’s Print (Ctrl+P) to print this sticker.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Brand.muted)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Clipboard.setData(ClipboardData(text: data)), child: const Text('Copy link')),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final active = items?.where((c) => c['isActive'] != false).length ?? 0;
    final scans = items?.fold<int>(0, (s, c) => s + ((c['scans'] as num?)?.toInt() ?? 0)) ?? 0;
    final week = items?.fold<int>(0, (s, c) => s + ((c['scans7d'] as num?)?.toInt() ?? 0)) ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'QR check-ins',
        subtitle: 'Print a QR for recycling bins, refill stations, events and partner stores. Scans prove presence — no fake GPS.',
        actions: [FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add_rounded), label: const Text('New QR point'))],
      ),
      if (items != null) ...[
        ResponsiveGrid(minWidth: 200, maxColumns: 4, children: [
          KpiCard(label: 'Active QR points', value: '$active', icon: Icons.qr_code_2_rounded, color: Brand.eco),
          KpiCard(label: 'Scans (all time)', value: '$scans', icon: Icons.touch_app_rounded, color: Brand.sky),
          KpiCard(label: 'Scans this week', value: '$week', icon: Icons.trending_up_rounded, color: Brand.coral),
          KpiCard(label: 'Partners', value: '${items.map((c) => c['partner']).where((p) => (p as String?)?.isNotEmpty == true).toSet().length}', icon: Icons.handshake_rounded, color: Brand.sun),
        ]),
        const SizedBox(height: 16),
      ],
      if (_error != null)
        ErrorBox(error: _error!, onRetry: _load)
      else if (items == null)
        const Loading()
      else if (items.isEmpty)
        const Panel(child: EmptyState(icon: Icons.qr_code_2_rounded, title: 'No QR points yet', message: 'Create one, print it and stick it on a bin or event board.'))
      else
        Panel(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(children: [
            for (final c in items)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Brand.border))),
                child: Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: Brand.eco.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                    child: Icon(_types[c['type']]?.$2 ?? Icons.qr_code_2_rounded, color: Brand.eco),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(
                        [
                          _types[c['type']]?.$1,
                          c['partner'],
                          c['emirate'],
                          'every ${c['cooldownHours']}h',
                          if ((c['radiusM'] as num? ?? 0) > 0) 'GPS ${c['radiusM']} m',
                        ].where((v) => v != null && '$v'.isNotEmpty).join(' · '),
                        style: const TextStyle(color: Brand.muted, fontSize: 12.5),
                      ),
                    ]),
                  ),
                  StatusPill('+${c['points']} pts', color: Brand.sun),
                  const SizedBox(width: 10),
                  Text('${c['scans'] ?? 0} scans', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
                  const SizedBox(width: 8),
                  Switch(
                    value: c['isActive'] != false,
                    onChanged: (v) async {
                      await Session.instance.api.updateCheckpoint(c['_id'] as String, {'isActive': v});
                      _load();
                    },
                  ),
                  IconButton(tooltip: 'Show / print QR', onPressed: () => _showQr(c), icon: const Icon(Icons.qr_code_rounded)),
                  IconButton(tooltip: 'Edit', onPressed: () => _edit(c), icon: const Icon(Icons.edit_rounded)),
                ]),
              ),
          ]),
        ),
    ]);
  }
}

class _CheckpointDialog extends StatefulWidget {
  const _CheckpointDialog({this.cp});
  final Json? cp;

  @override
  State<_CheckpointDialog> createState() => _CheckpointDialogState();
}

class _CheckpointDialogState extends State<_CheckpointDialog> {
  late final _name = TextEditingController(text: widget.cp?['name'] as String? ?? '');
  late final _partner = TextEditingController(text: widget.cp?['partner'] as String? ?? '');
  late final _points = TextEditingController(text: '${widget.cp?['points'] ?? 10}');
  late final _cooldown = TextEditingController(text: '${widget.cp?['cooldownHours'] ?? 24}');
  late final _radius = TextEditingController(text: '${widget.cp?['radiusM'] ?? 0}');
  late final _lat = TextEditingController(text: '${(widget.cp?['location'] as Map?)?['lat'] ?? ''}');
  late final _lng = TextEditingController(text: '${(widget.cp?['location'] as Map?)?['lng'] ?? ''}');
  late String _type = widget.cp?['type'] as String? ?? 'recycling_bin';
  late String _emirate = (widget.cp?['emirate'] as String?)?.isNotEmpty == true ? widget.cp!['emirate'] as String : 'Dubai';
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = {
      'name': _name.text.trim(),
      'partner': _partner.text.trim(),
      'type': _type,
      'emirate': _emirate,
      'points': int.tryParse(_points.text) ?? 10,
      'cooldownHours': int.tryParse(_cooldown.text) ?? 24,
      'radiusM': int.tryParse(_radius.text) ?? 0,
      if (_lat.text.trim().isNotEmpty && _lng.text.trim().isNotEmpty) 'location': {'lat': double.tryParse(_lat.text), 'lng': double.tryParse(_lng.text)},
    };
    try {
      final id = widget.cp?['_id'] as String?;
      id == null ? await Session.instance.api.createCheckpoint(body) : await Session.instance.api.updateCheckpoint(id, body);
      if (mounted) Navigator.pop(context, true);
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.digitsOnly];
    final coord = [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.]'))];
    return AlertDialog(
      title: Text(widget.cp == null ? 'New QR point' : 'Edit QR point'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Marina Walk recycling bins')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [for (final t in _types.entries) DropdownMenuItem(value: t.key, child: Text(t.value.$1))],
                  onChanged: (v) => setState(() => _type = v ?? _type),
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
            TextField(controller: _partner, decoration: const InputDecoration(labelText: 'Partner (optional)')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: _points, inputFormatters: digits, decoration: const InputDecoration(labelText: 'Eco Points per scan'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _cooldown, inputFormatters: digits, decoration: const InputDecoration(labelText: 'Once every (hours)'))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: _lat, inputFormatters: coord, decoration: const InputDecoration(labelText: 'Latitude (optional)'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _lng, inputFormatters: coord, decoration: const InputDecoration(labelText: 'Longitude (optional)'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _radius, inputFormatters: digits, decoration: const InputDecoration(labelText: 'GPS radius m', helperText: '0 = no GPS check'))),
            ]),
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
