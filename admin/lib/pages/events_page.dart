import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../api/admin_api.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'users_page.dart' show emirates;

const eventCategories = ['cleanup', 'planting', 'workshop', 'talk', 'market', 'other'];

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
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
      final items = await Session.instance.api.events();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _edit([Json? e]) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => _EventDialog(event: e));
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final now = DateTime.now();
    DateTime start(Json e) => DateTime.tryParse(e['startsAt'] as String? ?? '')?.toLocal() ?? now;
    final upcoming = items?.where((e) => start(e).isAfter(now)).toList() ?? [];
    final rsvps = items?.fold<int>(0, (s, e) => s + ((e['attendeeCount'] as num?)?.toInt() ?? 0)) ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Green events',
        subtitle: 'Clean-ups, plantings and workshops shown in the app calendar (active campaigns appear there too)',
        actions: [FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add_rounded), label: const Text('New event'))],
      ),
      if (_error != null)
        ErrorBox(error: _error!, onRetry: _load)
      else if (items == null)
        const Loading()
      else ...[
        ResponsiveGrid(minWidth: 220, maxColumns: 4, children: [
          KpiCard(label: 'Upcoming', value: '${upcoming.length}', icon: Icons.event_rounded, color: Brand.sky),
          KpiCard(label: 'Total RSVPs', value: '$rsvps', icon: Icons.groups_rounded, color: Brand.eco),
          KpiCard(label: 'Emirates', value: '${items.map((e) => e['emirate']).where((x) => (x as String?)?.isNotEmpty == true).toSet().length} / 7', icon: Icons.map_rounded, color: Brand.coral),
          KpiCard(label: 'Drafts', value: '${items.where((e) => e['isPublished'] == false).length}', icon: Icons.edit_note_rounded, color: Brand.muted),
        ]),
        const SizedBox(height: 16),
        Panel(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: items.isEmpty
              ? const EmptyState(icon: Icons.event_busy_rounded, title: 'No events yet')
              : Column(children: [
                  for (final e in items)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Brand.border))),
                      child: Row(children: [
                        Container(
                          width: 52,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(color: Brand.blush, borderRadius: BorderRadius.circular(12)),
                          child: Column(children: [
                            Text(DateFormat('MMM').format(start(e)).toUpperCase(), style: const TextStyle(fontSize: 11, color: Brand.coral, fontWeight: FontWeight.w800)),
                            Text('${start(e).day}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          ]),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(e['title'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text(
                              '${DateFormat('EEE h:mm a').format(start(e))} · ${e['venue']}, ${e['emirate']} · ${e['category']}',
                              style: const TextStyle(color: Brand.muted, fontSize: 12.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ]),
                        ),
                        StatusPill(
                          (e['capacity'] as num? ?? 0) > 0 ? '${e['attendeeCount']}/${e['capacity']} going' : '${e['attendeeCount']} going',
                          color: Brand.eco,
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Published in the app',
                          child: Switch(
                            value: e['isPublished'] != false,
                            onChanged: (v) async {
                              await Session.instance.api.updateEvent(e['_id'] as String, {'isPublished': v});
                              _load();
                            },
                          ),
                        ),
                        IconButton(tooltip: 'Edit', onPressed: () => _edit(e), icon: const Icon(Icons.edit_rounded)),
                      ]),
                    ),
                ]),
        ),
      ],
    ]);
  }
}

class _EventDialog extends StatefulWidget {
  const _EventDialog({this.event});
  final Json? event;

  @override
  State<_EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends State<_EventDialog> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.event?['title'] as String? ?? '');
  late final _desc = TextEditingController(text: widget.event?['description'] as String? ?? '');
  late final _venue = TextEditingController(text: widget.event?['venue'] as String? ?? '');
  late final _organizer = TextEditingController(text: widget.event?['organizer'] as String? ?? 'GreenifyX');
  late final _image = TextEditingController(text: widget.event?['coverImage'] as String? ?? '');
  late final _capacity = TextEditingController(text: '${widget.event?['capacity'] ?? 0}');
  late final _lat = TextEditingController(text: '${(widget.event?['location'] as Map?)?['lat'] ?? ''}');
  late final _lng = TextEditingController(text: '${(widget.event?['location'] as Map?)?['lng'] ?? ''}');
  late String _category = widget.event?['category'] as String? ?? 'cleanup';
  late String _emirate = (widget.event?['emirate'] as String?)?.isNotEmpty == true ? widget.event!['emirate'] as String : 'Dubai';
  late DateTime _start = DateTime.tryParse(widget.event?['startsAt'] as String? ?? '')?.toLocal() ??
      DateTime.now().add(const Duration(days: 7)).copyWith(hour: 8, minute: 0);
  late Duration _length = (DateTime.tryParse(widget.event?['endsAt'] as String? ?? '')?.toLocal() ?? _start.add(const Duration(hours: 3))).difference(_start);
  bool _saving = false;
  String? _error;

  Future<void> _pickStart() async {
    final d = await showDatePicker(context: context, initialDate: _start, firstDate: DateTime(2024), lastDate: DateTime(2030));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_start));
    if (t == null) return;
    setState(() => _start = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    final body = {
      'title': _title.text.trim(),
      'description': _desc.text.trim(),
      'venue': _venue.text.trim(),
      'organizer': _organizer.text.trim(),
      'coverImage': _image.text.trim(),
      'capacity': int.tryParse(_capacity.text.trim()) ?? 0,
      'category': _category,
      'emirate': _emirate,
      'startsAt': _start.toUtc().toIso8601String(),
      'endsAt': _start.add(_length).toUtc().toIso8601String(),
      if (lat != null && lng != null) 'location': {'lat': lat, 'lng': lng},
    };
    try {
      final id = widget.event?['_id'] as String?;
      id == null ? await Session.instance.api.createEvent(body) : await Session.instance.api.updateEvent(id, body);
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
      title: Text(widget.event == null ? 'New event' : 'Edit event'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'Title'), validator: (v) => (v ?? '').trim().length < 3 ? 'Required' : null),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [for (final c in eventCategories) DropdownMenuItem(value: c, child: Text(c))],
                    onChanged: (v) => setState(() => _category = v ?? _category),
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
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_rounded),
                title: Text(DateFormat('EEE d MMM yyyy, h:mm a').format(_start)),
                subtitle: const Text('Start'),
                trailing: const Icon(Icons.edit_calendar_rounded),
                onTap: _pickStart,
              ),
              DropdownButtonFormField<int>(
                initialValue: [1, 2, 3, 4, 6, 8].contains(_length.inHours) ? _length.inHours : 3,
                decoration: const InputDecoration(labelText: 'Duration'),
                items: [for (final h in [1, 2, 3, 4, 6, 8]) DropdownMenuItem(value: h, child: Text('$h hours'))],
                onChanged: (v) => setState(() => _length = Duration(hours: v ?? 3)),
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _venue, decoration: const InputDecoration(labelText: 'Venue')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _lat, inputFormatters: coord, decoration: const InputDecoration(labelText: 'Latitude (optional)'))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _lng, inputFormatters: coord, decoration: const InputDecoration(labelText: 'Longitude (optional)'))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _organizer, decoration: const InputDecoration(labelText: 'Organiser'))),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _capacity,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Capacity', helperText: '0 = no limit'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextFormField(controller: _desc, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
              const SizedBox(height: 12),
              TextFormField(controller: _image, decoration: const InputDecoration(labelText: 'Cover image URL')),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Brand.danger))),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save')),
      ],
    );
  }
}
