import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../api/admin_api.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// My Forest: trees members funded with Eco Points. Mark them planted and post photo updates.
class ForestPage extends StatefulWidget {
  const ForestPage({super.key});

  @override
  State<ForestPage> createState() => _ForestPageState();
}

class _ForestPageState extends State<ForestPage> {
  String _status = 'pledged';
  Json? _data;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = await Session.instance.api.getJson('/admin/forest', query: {'status': _status, 'limit': 100});
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _plant(Json t) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => _PlantDialog(tree: t));
    if (ok == true) _load();
  }

  Future<void> _update(Json t) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => _UpdateDialog(tree: t));
    if (ok == true) _load();
  }

  Future<void> _cancel(Json t) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel and refund?'),
        content: Text('Tree ${t['code']} will be cancelled and ${t['pointsCost']} Eco Points returned to the member.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel and refund')),
        ],
      ),
    );
    if (yes != true) return;
    await Session.instance.api.patchJson('/admin/forest/${t['_id']}', {'status': 'cancelled'});
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final counts = Json.from(d?['counts'] as Map? ?? {});
    final trees = List<Json>.from((d?['trees'] as List? ?? []).map((e) => Json.from(e as Map)));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader(title: 'My Forest', subtitle: 'Native trees members funded with Eco Points. Plant them with a partner, then post photo updates.'),
      ResponsiveGrid(minWidth: 220, maxColumns: 3, children: [
        KpiCard(label: 'Waiting to plant', value: '${counts['pledged'] ?? 0}', icon: Icons.hourglass_top_rounded, color: Brand.sun),
        KpiCard(label: 'Planted', value: '${counts['planted'] ?? 0}', icon: Icons.park_rounded, color: Brand.eco),
        KpiCard(label: 'Cancelled', value: '${counts['cancelled'] ?? 0}', icon: Icons.undo_rounded, color: Brand.muted),
      ]),
      const SizedBox(height: 16),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'pledged', label: Text('Waiting')),
          ButtonSegment(value: 'planted', label: Text('Planted')),
          ButtonSegment(value: 'cancelled', label: Text('Cancelled')),
        ],
        selected: {_status},
        onSelectionChanged: (s) {
          setState(() => _status = s.first);
          _load();
        },
      ),
      const SizedBox(height: 12),
      if (_error != null)
        ErrorBox(error: _error!, onRetry: _load)
      else if (d == null)
        const Loading()
      else
        Panel(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: trees.isEmpty
              ? const EmptyState(icon: Icons.park_outlined, title: 'No trees here')
              : Column(children: [
                  for (final t in trees)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Brand.border))),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${t['code']} · ${t['species']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text(
                              '${(t['user'] as Map?)?['name'] ?? ''} · ${(t['user'] as Map?)?['emirate'] ?? ''} · funded ${DateFormat('d MMM yyyy').format(DateTime.tryParse(t['createdAt'] as String? ?? '')?.toLocal() ?? DateTime.now())}'
                              '${(t['place'] as String? ?? '').isEmpty ? '' : ' · ${t['place']}'}',
                              style: const TextStyle(color: Brand.muted, fontSize: 12.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ]),
                        ),
                        StatusPill('${(t['updates'] as List? ?? []).length} updates', color: Brand.sky),
                        const SizedBox(width: 8),
                        if (t['status'] == 'pledged') ...[
                          FilledButton(onPressed: () => _plant(t), child: const Text('Mark planted')),
                          IconButton(tooltip: 'Cancel and refund', onPressed: () => _cancel(t), icon: const Icon(Icons.undo_rounded)),
                        ],
                        if (t['status'] == 'planted') OutlinedButton.icon(onPressed: () => _update(t), icon: const Icon(Icons.add_a_photo_rounded), label: const Text('Add update')),
                      ]),
                    ),
                ]),
        ),
    ]);
  }
}

class _PlantDialog extends StatefulWidget {
  const _PlantDialog({required this.tree});
  final Json tree;

  @override
  State<_PlantDialog> createState() => _PlantDialogState();
}

class _PlantDialogState extends State<_PlantDialog> {
  final _partner = TextEditingController();
  final _place = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Session.instance.api.patchJson('/admin/forest/${widget.tree['_id']}', {
        'status': 'planted',
        'partner': _partner.text.trim(),
        'place': _place.text.trim(),
        if (double.tryParse(_lat.text.trim()) != null) 'lat': double.parse(_lat.text.trim()),
        if (double.tryParse(_lng.text.trim()) != null) 'lng': double.parse(_lng.text.trim()),
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
    return AlertDialog(
      title: Text('Planted ${widget.tree['code']}'),
      content: SizedBox(
        width: 440,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _partner, decoration: const InputDecoration(labelText: 'Planting partner')),
          const SizedBox(height: 12),
          TextField(controller: _place, decoration: const InputDecoration(labelText: 'Place (e.g. Jebel Ali mangroves)')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: _lat, inputFormatters: coord, decoration: const InputDecoration(labelText: 'Latitude'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _lng, inputFormatters: coord, decoration: const InputDecoration(labelText: 'Longitude'))),
          ]),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Brand.danger))),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Mark planted')),
      ],
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.tree});
  final Json tree;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  final _photo = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Session.instance.api.postJson('/admin/forest/${widget.tree['_id']}/updates', {'photoUrl': _photo.text.trim(), 'note': _note.text.trim()});
      if (mounted) Navigator.pop(context, true);
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Update for ${widget.tree['code']}'),
        content: SizedBox(
          width: 440,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: _photo, decoration: const InputDecoration(labelText: 'Photo URL (https)')),
            const SizedBox(height: 12),
            TextField(controller: _note, maxLines: 3, decoration: const InputDecoration(labelText: 'Note (e.g. "3 months in, 40 cm tall")')),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Brand.danger))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Sending…' : 'Send to member')),
        ],
      );
}
