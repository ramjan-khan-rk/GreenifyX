import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../api/admin_api.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'users_page.dart' show emirates;

/// Neighbourhoods (zones) for leagues, and targeted missions announced to people in an area.
class MissionsPage extends StatefulWidget {
  const MissionsPage({super.key});

  @override
  State<MissionsPage> createState() => _MissionsPageState();
}

class _MissionsPageState extends State<MissionsPage> {
  List<Json>? _zones;
  List<Json>? _missions;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Future.wait([Session.instance.api.getJson('/admin/zones'), Session.instance.api.getJson('/admin/missions')]);
      if (!mounted) return;
      setState(() {
        _zones = List<Json>.from((r[0]['zones'] as List).map((e) => Json.from(e as Map)));
        _missions = List<Json>.from((r[1]['missions'] as List).map((e) => Json.from(e as Map)));
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _zone([Json? z]) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => _ZoneDialog(zone: z));
    if (ok == true) _load();
  }

  Future<void> _mission([Json? m]) async {
    final msg = await showDialog<String>(context: context, builder: (_) => _MissionDialog(mission: m, zones: _zones ?? const []));
    if (msg == null) return;
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final zones = _zones;
    final missions = _missions;
    final now = DateTime.now();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Missions and leagues',
        subtitle: 'Draw neighbourhoods for weekly leagues, then launch missions to the people who live there',
        actions: [
          OutlinedButton.icon(onPressed: () => _zone(), icon: const Icon(Icons.add_location_alt_rounded), label: const Text('Add neighbourhood')),
          FilledButton.icon(onPressed: zones == null ? null : () => _mission(), icon: const Icon(Icons.flag_rounded), label: const Text('New mission')),
        ],
      ),
      if (_error != null)
        ErrorBox(error: _error!, onRetry: _load)
      else if (zones == null || missions == null)
        const Loading()
      else ...[
        Panel(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Missions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            if (missions.isEmpty) const EmptyState(icon: Icons.flag_outlined, title: 'No missions yet'),
            for (final m in missions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(m['title'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(
                  '${(m['zone'] as Map?)?['name'] ?? ((m['emirate'] as String?)?.isNotEmpty == true ? m['emirate'] : 'All UAE')}'
                  ' · ${m['activity']?.toString().isNotEmpty == true ? m['activity'] : 'any action'}'
                  ' · ${m['completions']}${(m['targetCount'] ?? 0) > 0 ? ' / ${m['targetCount']}' : ''} done · +${m['bonusPoints']}'
                  ' · until ${DateFormat('d MMM').format(DateTime.parse(m['endsAt'] as String).toLocal())}',
                ),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  StatusPill(
                    m['status'] == 'active' && DateTime.parse(m['endsAt'] as String).isAfter(now) ? 'live' : m['status'] as String,
                    color: m['status'] == 'active' ? Brand.eco : Brand.muted,
                  ),
                  IconButton(tooltip: 'Edit', onPressed: () => _mission(m), icon: const Icon(Icons.edit_rounded)),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        Panel(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Neighbourhoods', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            if (zones.isEmpty) const EmptyState(icon: Icons.map_outlined, title: 'No neighbourhoods yet'),
            for (final z in zones)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${z['name']} · ${z['emirate'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${(z['center'] as Map)['lat']}, ${(z['center'] as Map)['lng']} · ${((z['radiusM'] as num) / 1000).toStringAsFixed(1)} km radius · ${z['members']} members'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (z['isActive'] == false) const StatusPill('hidden'),
                  IconButton(tooltip: 'Edit', onPressed: () => _zone(z), icon: const Icon(Icons.edit_rounded)),
                ]),
              ),
          ]),
        ),
      ],
    ]);
  }
}

class _ZoneDialog extends StatefulWidget {
  const _ZoneDialog({this.zone});
  final Json? zone;

  @override
  State<_ZoneDialog> createState() => _ZoneDialogState();
}

class _ZoneDialogState extends State<_ZoneDialog> {
  late final _name = TextEditingController(text: widget.zone?['name'] as String? ?? '');
  late final _lat = TextEditingController(text: '${(widget.zone?['center'] as Map?)?['lat'] ?? ''}');
  late final _lng = TextEditingController(text: '${(widget.zone?['center'] as Map?)?['lng'] ?? ''}');
  late final _radius = TextEditingController(text: '${widget.zone?['radiusM'] ?? 2000}');
  late String _emirate = (widget.zone?['emirate'] as String?)?.isNotEmpty == true ? widget.zone!['emirate'] as String : 'Dubai';
  late bool _active = widget.zone?['isActive'] != false;
  String? _error;
  bool _saving = false;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = {'name': _name.text.trim(), 'emirate': _emirate, 'lat': double.tryParse(_lat.text.trim()), 'lng': double.tryParse(_lng.text.trim()), 'radiusM': int.tryParse(_radius.text.trim()) ?? 2000, 'isActive': _active};
    try {
      final id = widget.zone?['_id'] as String?;
      id == null ? await Session.instance.api.postJson('/admin/zones', body) : await Session.instance.api.patchJson('/admin/zones/$id', body);
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
      title: Text(widget.zone == null ? 'Add neighbourhood' : 'Edit neighbourhood'),
      content: SizedBox(
        width: 440,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name (e.g. JLT, Al Nahda)')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _emirate,
            decoration: const InputDecoration(labelText: 'Emirate'),
            items: [for (final e in emirates) DropdownMenuItem(value: e, child: Text(e))],
            onChanged: (v) => setState(() => _emirate = v ?? _emirate),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: _lat, inputFormatters: coord, decoration: const InputDecoration(labelText: 'Centre latitude'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _lng, inputFormatters: coord, decoration: const InputDecoration(labelText: 'Centre longitude'))),
          ]),
          const SizedBox(height: 12),
          TextField(controller: _radius, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Radius in metres', helperText: '200 to 30,000')),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: _active, onChanged: (v) => setState(() => _active = v), title: const Text('Shown in the app')),
          if (_error != null) Text(_error!, style: const TextStyle(color: Brand.danger)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save')),
      ],
    );
  }
}

class _MissionDialog extends StatefulWidget {
  const _MissionDialog({this.mission, required this.zones});
  final Json? mission;
  final List<Json> zones;

  @override
  State<_MissionDialog> createState() => _MissionDialogState();
}

class _MissionDialogState extends State<_MissionDialog> {
  late final _title = TextEditingController(text: widget.mission?['title'] as String? ?? '');
  late final _desc = TextEditingController(text: widget.mission?['description'] as String? ?? '');
  late final _activity = TextEditingController(text: widget.mission?['activity'] as String? ?? '');
  late final _bonus = TextEditingController(text: '${widget.mission?['bonusPoints'] ?? 20}');
  late final _target = TextEditingController(text: '${widget.mission?['targetCount'] ?? 0}');
  late String _area = (widget.mission?['zone'] as Map?)?['_id'] as String? ?? ((widget.mission?['emirate'] as String?)?.isNotEmpty == true ? 'emirate:${widget.mission!['emirate']}' : 'uae');
  late String _status = widget.mission?['status'] as String? ?? 'active';
  late DateTime _ends = DateTime.tryParse(widget.mission?['endsAt'] as String? ?? '')?.toLocal() ?? DateTime.now().add(const Duration(days: 7));
  String? _error;
  bool _saving = false;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = {
      'title': _title.text.trim(),
      'description': _desc.text.trim(),
      'activity': _activity.text.trim(),
      'bonusPoints': int.tryParse(_bonus.text.trim()) ?? 20,
      'targetCount': int.tryParse(_target.text.trim()) ?? 0,
      'status': _status,
      'endsAt': _ends.toUtc().toIso8601String(),
      'zone': _area.startsWith('emirate:') || _area == 'uae' ? '' : _area,
      'emirate': _area.startsWith('emirate:') ? _area.substring(8) : '',
    };
    try {
      final id = widget.mission?['_id'] as String?;
      final r = id == null ? await Session.instance.api.postJson('/admin/missions', body) : await Session.instance.api.patchJson('/admin/missions/$id', body);
      final told = r['notified'] ?? 0;
      if (mounted) Navigator.pop(context, told > 0 ? 'Saved and announced to $told people' : 'Saved');
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.mission == null ? 'New mission' : 'Edit mission'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title (e.g. Clean JBR beach this weekend)')),
              const SizedBox(height: 12),
              TextField(controller: _desc, maxLines: 2, decoration: const InputDecoration(labelText: 'What to do')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _area,
                decoration: const InputDecoration(labelText: 'Who it is for'),
                items: [
                  const DropdownMenuItem(value: 'uae', child: Text('Everyone in the UAE')),
                  for (final e in emirates) DropdownMenuItem(value: 'emirate:$e', child: Text('Everyone in $e')),
                  for (final z in widget.zones) DropdownMenuItem(value: z['_id'] as String, child: Text('Neighbourhood: ${z['name']}')),
                ],
                onChanged: (v) => setState(() => _area = v ?? _area),
              ),
              const SizedBox(height: 12),
              TextField(controller: _activity, decoration: const InputDecoration(labelText: 'Eco action to post (exact name, optional)')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: _bonus, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Bonus points'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _target, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Area target (optional)'))),
              ]),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_rounded),
                title: Text('Ends ${DateFormat('EEE d MMM yyyy').format(_ends)}'),
                trailing: const Icon(Icons.edit_calendar_rounded),
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: _ends, firstDate: DateTime.now(), lastDate: DateTime(2030));
                  if (d != null) setState(() => _ends = DateTime(d.year, d.month, d.day, 23, 59));
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status', helperText: 'Active missions are announced to the area once'),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'draft', child: Text('Draft')),
                  DropdownMenuItem(value: 'ended', child: Text('Ended')),
                ],
                onChanged: (v) => setState(() => _status = v ?? _status),
              ),
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
