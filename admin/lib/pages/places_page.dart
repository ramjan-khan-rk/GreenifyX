import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/admin_api.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'users_page.dart' show emirates;

const placeTypes = ['Recycling Centre', 'Recycling Bin', 'E-waste Drop-off', 'Water Refill'];

IconData placeIcon(String t) => switch (t) {
      'Water Refill' => Icons.water_drop_rounded,
      'E-waste Drop-off' => Icons.devices_other_rounded,
      'Recycling Bin' => Icons.delete_outline_rounded,
      _ => Icons.recycling_rounded,
    };

class PlacesPage extends StatefulWidget {
  const PlacesPage({super.key});

  @override
  State<PlacesPage> createState() => _PlacesPageState();
}

class _PlacesPageState extends State<PlacesPage> {
  List<Json>? _items;
  Object? _error;
  String _type = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final items = await Session.instance.api.places();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _toggle(Json p, String field, bool value) async {
    try {
      await Session.instance.api.updatePlace(p['_id'] as String, {field: value});
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _add() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const _PlaceDialog());
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final shown = items?.where((p) => _type.isEmpty || p['type'] == _type).toList();
    final official = items?.where((p) => p['verified'] == true).length ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Eco places',
          subtitle: 'Recycling, e-waste and water refill points on the Smart Eco Map',
          actions: [FilledButton.icon(onPressed: _add, icon: const Icon(Icons.add_location_alt_rounded), label: const Text('Add place'))],
        ),
        if (items != null) ...[
          ResponsiveGrid(minWidth: 220, maxColumns: 4, children: [
            KpiCard(label: 'Places listed', value: '${items.length}', icon: Icons.place_rounded, color: Brand.sky),
            KpiCard(label: 'Official partners', value: '$official', icon: Icons.verified_rounded, color: Brand.eco,
                caption: 'Shown with an official badge'),
            KpiCard(label: 'Community listed', value: '${items.length - official}', icon: Icons.groups_rounded, color: Brand.muted),
            KpiCard(label: 'Emirates covered', value: '${items.map((p) => p['emirate']).where((e) => (e as String?)?.isNotEmpty == true).toSet().length} / 7',
                icon: Icons.map_rounded, color: Brand.coral),
          ]),
          const SizedBox(height: 16),
        ],
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in ['', ...placeTypes])
            ChoiceChip(
              label: Text(t.isEmpty ? 'All' : t),
              selected: _type == t,
              onSelected: (_) => setState(() => _type = t),
            ),
        ]),
        const SizedBox(height: 16),
        if (_error != null)
          ErrorBox(error: _error!, onRetry: _load)
        else if (shown == null)
          const Loading()
        else if (shown.isEmpty)
          const Panel(child: EmptyState(icon: Icons.add_location_alt_rounded, title: 'No places yet'))
        else
          Panel(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(children: [
              for (final p in shown)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Brand.border))),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: Brand.sky.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                      child: Icon(placeIcon(p['type'] as String? ?? ''), color: Brand.sky, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Flexible(
                            child: Text(p['name'] as String? ?? '',
                                overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                          if (p['verified'] == true) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified_rounded, size: 16, color: Brand.eco),
                          ],
                        ]),
                        Text(
                          [p['type'], p['emirate'], if ((p['hours'] as String?)?.isNotEmpty == true) p['hours']]
                              .where((v) => (v as String?)?.isNotEmpty == true)
                              .join(' · '),
                          style: const TextStyle(color: Brand.muted, fontSize: 12.5),
                        ),
                        if ((p['acceptedMaterials'] as List?)?.isNotEmpty == true)
                          Text('Accepts ${(p['acceptedMaterials'] as List).join(', ')}',
                              style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                    Tooltip(
                      message: 'Official partner (confirmed with the operator)',
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Official', style: TextStyle(fontSize: 12.5, color: Brand.muted)),
                        Switch(value: p['verified'] == true, onChanged: (v) => _toggle(p, 'verified', v)),
                      ]),
                    ),
                    Tooltip(
                      message: 'Show on the map',
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Visible', style: TextStyle(fontSize: 12.5, color: Brand.muted)),
                        Switch(value: p['active'] != false, onChanged: (v) => _toggle(p, 'active', v)),
                      ]),
                    ),
                  ]),
                ),
            ]),
          ),
      ],
    );
  }
}

class _PlaceDialog extends StatefulWidget {
  const _PlaceDialog();

  @override
  State<_PlaceDialog> createState() => _PlaceDialogState();
}

class _PlaceDialogState extends State<_PlaceDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _hours = TextEditingController();
  final _materials = TextEditingController();
  final _source = TextEditingController();
  String _type = placeTypes.first;
  String _emirate = 'Dubai';
  bool _verified = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _lat, _lng, _hours, _materials, _source]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Session.instance.api.createPlace({
        'name': _name.text.trim(),
        'type': _type,
        'emirate': _emirate,
        'lat': double.tryParse(_lat.text.trim()),
        'lng': double.tryParse(_lng.text.trim()),
        'hours': _hours.text.trim(),
        'acceptedMaterials': _materials.text.trim(),
        'source': _source.text.trim(),
        'verified': _verified,
      });
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
    String? coordCheck(String? v, double max) {
      final n = double.tryParse((v ?? '').trim());
      return n == null || n.abs() > max ? 'Invalid' : null;
    }

    return AlertDialog(
      title: const Text('Add eco place'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => (v == null || v.trim().length < 3) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: [for (final t in placeTypes) DropdownMenuItem(value: t, child: Text(t))],
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
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _lat,
                    inputFormatters: coord,
                    decoration: const InputDecoration(labelText: 'Latitude'),
                    validator: (v) => coordCheck(v, 90),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lng,
                    inputFormatters: coord,
                    decoration: const InputDecoration(labelText: 'Longitude'),
                    validator: (v) => coordCheck(v, 180),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextFormField(controller: _hours, decoration: const InputDecoration(labelText: 'Opening hours')),
              const SizedBox(height: 12),
              TextFormField(controller: _materials, decoration: const InputDecoration(labelText: 'Accepted materials', hintText: 'Plastic, Paper, Batteries')),
              const SizedBox(height: 12),
              TextFormField(controller: _source, decoration: const InputDecoration(labelText: 'Source', hintText: 'Who confirmed this listing')),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _verified,
                onChanged: (v) => setState(() => _verified = v),
                title: const Text('Official partner'),
                subtitle: const Text('Only turn on when confirmed directly with the operator'),
              ),
              if (_error != null) Text(_error!, style: const TextStyle(color: Brand.danger, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('Add place')),
      ],
    );
  }
}
