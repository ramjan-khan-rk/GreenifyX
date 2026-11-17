import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../api/admin_api.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

Color _hex(String? h, Color fallback) {
  final v = int.tryParse((h ?? '').replaceFirst('#', ''), radix: 16);
  return v == null ? fallback : Color(0xFF000000 | v);
}

/// UAE seasons and moments: schedule National Day, Ramadan, Earth Hour and more.
class SeasonsPage extends StatefulWidget {
  const SeasonsPage({super.key});

  @override
  State<SeasonsPage> createState() => _SeasonsPageState();
}

class _SeasonsPageState extends State<SeasonsPage> {
  List<Json>? _seasons;
  String? _live;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = await Session.instance.api.getJson('/admin/seasons');
      if (!mounted) return;
      setState(() {
        _seasons = List<Json>.from((d['seasons'] as List).map((e) => Json.from(e as Map)));
        _live = d['liveKey'] as String?;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _edit([Json? s]) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => _SeasonDialog(season: s));
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final list = _seasons;
    final f = DateFormat('d MMM yyyy');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Seasons and moments',
        subtitle: 'A themed banner, badge and optional mission in the app for National Day, Ramadan, Earth Hour and more. Everyone is notified when a season starts.',
        actions: [FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add_rounded), label: const Text('New season'))],
      ),
      if (_error != null)
        ErrorBox(error: _error!, onRetry: _load)
      else if (list == null)
        const Loading()
      else
        Panel(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: list.isEmpty
              ? const EmptyState(icon: Icons.celebration_outlined, title: 'Seasons appear here after the server starts once')
              : Column(children: [
                  for (final s in list)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(colors: [
                            _hex((s['colors'] as List?)?.elementAtOrNull(0)?.toString(), Brand.eco),
                            _hex((s['colors'] as List?)?.elementAtOrNull(1)?.toString(), Brand.sun),
                          ]),
                        ),
                        child: Text(s['emoji'] as String? ?? '🌱', style: const TextStyle(fontSize: 22)),
                      ),
                      title: Text(s['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(s['startsAt'] == null
                          ? 'Template · set dates to schedule'
                          : '${f.format(DateTime.parse(s['startsAt'] as String).toLocal())} – ${f.format(DateTime.parse(s['endsAt'] as String).toLocal())}${(s['badgeLabel'] as String?)?.isNotEmpty == true ? ' · badge: ${s['badgeLabel']}' : ''}'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (s['key'] == _live) const StatusPill('live now', color: Brand.eco) else if (s['isActive'] == true) const StatusPill('scheduled', color: Brand.sky) else const StatusPill('off'),
                        IconButton(tooltip: 'Edit', onPressed: () => _edit(s), icon: const Icon(Icons.edit_rounded)),
                      ]),
                    ),
                ]),
        ),
    ]);
  }
}

class _SeasonDialog extends StatefulWidget {
  const _SeasonDialog({this.season});
  final Json? season;

  @override
  State<_SeasonDialog> createState() => _SeasonDialogState();
}

class _SeasonDialogState extends State<_SeasonDialog> {
  late final _name = TextEditingController(text: widget.season?['name'] as String? ?? '');
  late final _nameAr = TextEditingController(text: widget.season?['nameAr'] as String? ?? '');
  late final _emoji = TextEditingController(text: widget.season?['emoji'] as String? ?? '🌱');
  late final _msg = TextEditingController(text: widget.season?['message'] as String? ?? '');
  late final _msgAr = TextEditingController(text: widget.season?['messageAr'] as String? ?? '');
  late final _badge = TextEditingController(text: widget.season?['badgeLabel'] as String? ?? '');
  late final _c1 = TextEditingController(text: (widget.season?['colors'] as List?)?.elementAtOrNull(0)?.toString() ?? '#1F8A70');
  late final _c2 = TextEditingController(text: (widget.season?['colors'] as List?)?.elementAtOrNull(1)?.toString() ?? '#F2B544');
  late final _qFrom = TextEditingController(text: widget.season?['quietFrom'] as String? ?? '');
  late final _qTo = TextEditingController(text: widget.season?['quietTo'] as String? ?? '');
  late DateTimeRange? _range = widget.season?['startsAt'] == null
      ? null
      : DateTimeRange(start: DateTime.parse(widget.season!['startsAt'] as String).toLocal(), end: DateTime.parse(widget.season!['endsAt'] as String).toLocal());
  late bool _active = widget.season?['isActive'] == true;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_active && _range == null) return setState(() => _error = 'Pick the dates before switching it on');
    setState(() {
      _saving = true;
      _error = null;
    });
    final badgeKey = _badge.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final body = {
      'name': _name.text.trim(),
      'nameAr': _nameAr.text.trim(),
      'emoji': _emoji.text.trim(),
      'message': _msg.text.trim(),
      'messageAr': _msgAr.text.trim(),
      'badgeLabel': _badge.text.trim(),
      if (badgeKey.isNotEmpty) 'badge': badgeKey,
      'colors': [_c1.text.trim(), _c2.text.trim()],
      'quietFrom': _qFrom.text.trim(),
      'quietTo': _qTo.text.trim(),
      'isActive': _active,
      if (_range != null) 'startsAt': DateTime(_range!.start.year, _range!.start.month, _range!.start.day).toUtc().toIso8601String(),
      if (_range != null) 'endsAt': DateTime(_range!.end.year, _range!.end.month, _range!.end.day).add(const Duration(days: 1)).toUtc().toIso8601String(),
    };
    try {
      final id = widget.season?['_id'] as String?;
      id == null ? await Session.instance.api.postJson('/admin/seasons', body) : await Session.instance.api.patchJson('/admin/seasons/$id', body);
      if (mounted) Navigator.pop(context, true);
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.season == null ? 'New season' : 'Edit season'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                SizedBox(width: 70, child: TextField(controller: _emoji, decoration: const InputDecoration(labelText: 'Emoji'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _nameAr, textDirection: TextDirection.rtl, decoration: const InputDecoration(labelText: 'Name (Arabic)'))),
              ]),
              const SizedBox(height: 12),
              TextField(controller: _msg, maxLines: 2, decoration: const InputDecoration(labelText: 'Message on the banner')),
              const SizedBox(height: 12),
              TextField(controller: _msgAr, maxLines: 2, textDirection: TextDirection.rtl, decoration: const InputDecoration(labelText: 'Message (Arabic)')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: _badge, decoration: const InputDecoration(labelText: 'Badge name (optional)'))),
                const SizedBox(width: 10),
                SizedBox(width: 110, child: TextField(controller: _c1, decoration: const InputDecoration(labelText: 'Colour 1'))),
                const SizedBox(width: 10),
                SizedBox(width: 110, child: TextField(controller: _c2, decoration: const InputDecoration(labelText: 'Colour 2'))),
              ]),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.date_range_rounded),
                title: Text(_range == null ? 'No dates yet' : '${DateFormat('d MMM yyyy').format(_range!.start)} – ${DateFormat('d MMM yyyy').format(_range!.end)}'),
                subtitle: const Text('Days in UAE time, start to end inclusive'),
                trailing: const Icon(Icons.edit_calendar_rounded),
                onTap: () async {
                  final r = await showDateRangePicker(context: context, firstDate: DateTime(2026), lastDate: DateTime(2032), initialDateRange: _range);
                  if (r != null) setState(() => _range = r);
                },
              ),
              Row(children: [
                Expanded(child: TextField(controller: _qFrom, decoration: const InputDecoration(labelText: 'No nudges from (HH:MM)', helperText: 'e.g. 17:30 for iftar'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _qTo, decoration: const InputDecoration(labelText: 'until (HH:MM)'))),
              ]),
              SwitchListTile(contentPadding: EdgeInsets.zero, value: _active, onChanged: (v) => setState(() => _active = v), title: const Text('Switched on')),
              if (_error != null) Text(_error!, style: const TextStyle(color: Brand.danger)),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save')),
        ],
      );
}
