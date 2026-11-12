import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/admin_api.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

const activityLanes = ['Planet', 'Humanity', 'Wildlife', 'Stories'];

/// Icon names the app understands (kept in sync with the app's activityIcon()).
const activityIcons = <String, IconData>{
  'eco': Icons.eco_rounded,
  'park': Icons.park_rounded,
  'forest': Icons.forest_rounded,
  'water': Icons.water_rounded,
  'water_drop': Icons.water_drop_rounded,
  'yard': Icons.yard_rounded,
  'compost': Icons.compost_rounded,
  'recycling': Icons.recycling_rounded,
  'devices_other': Icons.devices_other_rounded,
  'shopping_bag': Icons.shopping_bag_rounded,
  'autorenew': Icons.autorenew_rounded,
  'restaurant': Icons.restaurant_rounded,
  'cleaning_services': Icons.cleaning_services_rounded,
  'beach_access': Icons.beach_access_rounded,
  'landscape': Icons.landscape_rounded,
  'scuba_diving': Icons.scuba_diving_rounded,
  'pedal_bike': Icons.pedal_bike_rounded,
  'directions_walk': Icons.directions_walk_rounded,
  'directions_subway': Icons.directions_subway_rounded,
  'groups': Icons.groups_rounded,
  'bolt': Icons.bolt_rounded,
  'solar_power': Icons.solar_power_rounded,
  'volunteer_activism': Icons.volunteer_activism_rounded,
  'dinner_dining': Icons.dinner_dining_rounded,
  'checkroom': Icons.checkroom_rounded,
  'school': Icons.school_rounded,
  'pets': Icons.pets_rounded,
  'flutter_dash': Icons.flutter_dash_rounded,
  'favorite': Icons.favorite_rounded,
  'emoji_events': Icons.emoji_events_rounded,
};

Color laneColor(String lane) => switch (lane) {
      'Humanity' => Brand.coral,
      'Wildlife' => const Color(0xFF7F53AC),
      'Stories' => Brand.sun,
      _ => Brand.eco,
    };

class ActivitiesPage extends StatefulWidget {
  const ActivitiesPage({super.key});

  @override
  State<ActivitiesPage> createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends State<ActivitiesPage> {
  List<Json>? _items;
  Object? _error;
  String _lane = '';
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final items = await Session.instance.api.activities();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _edit([Json? a]) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => _ActivityDialog(activity: a));
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final q = _q.toLowerCase();
    final shown = items?.where((a) {
      if (_lane.isNotEmpty && a['lane'] != _lane) return false;
      if (q.isEmpty) return true;
      final hay = [a['name'], a['nameAr'], a['line'], ...(a['keywords'] as List? ?? [])].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
    final active = items?.where((a) => a['isActive'] != false).length ?? 0;
    final posts = items?.fold<int>(0, (s, a) => s + ((a['posts'] as num?)?.toInt() ?? 0)) ?? 0;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Eco activities',
        subtitle: 'What members can post about: points, CO₂ value and the keywords used for search and AI',
        actions: [FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add_rounded), label: const Text('New activity'))],
      ),
      if (items != null) ...[
        ResponsiveGrid(minWidth: 200, maxColumns: 4, children: [
          KpiCard(label: 'Activities live', value: '$active', icon: Icons.eco_rounded, color: Brand.eco),
          KpiCard(label: 'Disabled', value: '${items.length - active}', icon: Icons.visibility_off_rounded, color: Brand.muted),
          KpiCard(label: 'Posts using them', value: '$posts', icon: Icons.photo_library_rounded, color: Brand.sky),
          KpiCard(
            label: 'Keywords',
            value: '${items.fold<int>(0, (s, a) => s + ((a['keywords'] as List?)?.length ?? 0))}',
            icon: Icons.key_rounded,
            color: Brand.sun,
          ),
        ]),
        const SizedBox(height: 16),
      ],
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(
          width: 260,
          child: TextField(
            decoration: const InputDecoration(isDense: true, hintText: 'Search name or keyword', prefixIcon: Icon(Icons.search_rounded, size: 18)),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        for (final l in ['', ...activityLanes])
          ChoiceChip(label: Text(l.isEmpty ? 'All' : l), selected: _lane == l, onSelected: (_) => setState(() => _lane = l)),
      ]),
      const SizedBox(height: 16),
      if (_error != null)
        ErrorBox(error: _error!, onRetry: _load)
      else if (shown == null)
        const Loading()
      else if (shown.isEmpty)
        const Panel(child: EmptyState(icon: Icons.eco_outlined, title: 'No activities match'))
      else
        Panel(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(children: [
            for (final a in shown)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Brand.border))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: laneColor(a['lane'] as String? ?? '').withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(activityIcons[a['icon']] ?? Icons.eco_rounded, color: laneColor(a['lane'] as String? ?? '')),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(child: Text(a['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w800))),
                        if ((a['nameAr'] as String? ?? '').isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(a['nameAr'] as String, style: const TextStyle(color: Brand.muted)),
                        ],
                      ]),
                      Text('${a['lane']} · ${a['line']}', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 4, runSpacing: 4, children: [
                        for (final k in (a['keywords'] as List? ?? []))
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Brand.canvas, borderRadius: BorderRadius.circular(8), border: Border.all(color: Brand.border)),
                            child: Text('$k', style: const TextStyle(fontSize: 11.5)),
                          ),
                      ]),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    StatusPill('+${a['points']} pts', color: Brand.sun),
                    const SizedBox(height: 6),
                    Text('${a['co2Kg']} kg CO₂ · ${a['posts'] ?? 0} posts', style: const TextStyle(fontSize: 12, color: Brand.muted)),
                  ]),
                  const SizedBox(width: 8),
                  Switch(
                    value: a['isActive'] != false,
                    onChanged: (v) async {
                      await Session.instance.api.updateActivity(a['_id'] as String, {'isActive': v});
                      _load();
                    },
                  ),
                  IconButton(tooltip: 'Edit', onPressed: () => _edit(a), icon: const Icon(Icons.edit_rounded)),
                ]),
              ),
          ]),
        ),
    ]);
  }
}

class _ActivityDialog extends StatefulWidget {
  const _ActivityDialog({this.activity});
  final Json? activity;

  @override
  State<_ActivityDialog> createState() => _ActivityDialogState();
}

class _ActivityDialogState extends State<_ActivityDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.activity?['name'] as String? ?? '');
  late final _nameAr = TextEditingController(text: widget.activity?['nameAr'] as String? ?? '');
  late final _line = TextEditingController(text: widget.activity?['line'] as String? ?? '');
  late final _points = TextEditingController(text: '${widget.activity?['points'] ?? 20}');
  late final _co2 = TextEditingController(text: '${widget.activity?['co2Kg'] ?? 0.5}');
  late final _keywords = TextEditingController(text: ((widget.activity?['keywords'] as List?) ?? []).join(', '));
  late String _lane = widget.activity?['lane'] as String? ?? 'Planet';
  late String _icon = activityIcons.containsKey(widget.activity?['icon']) ? widget.activity!['icon'] as String : 'eco';
  bool _saving = false;
  String? _error;

  bool get _isNew => widget.activity == null;

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = {
      if (_isNew) 'name': _name.text.trim(),
      'nameAr': _nameAr.text.trim(),
      'line': _line.text.trim(),
      'lane': _lane,
      'icon': _icon,
      'points': int.tryParse(_points.text.trim()) ?? 10,
      'co2Kg': double.tryParse(_co2.text.trim()) ?? 0,
      'keywords': _keywords.text,
    };
    try {
      _isNew
          ? await Session.instance.api.createActivity(body)
          : await Session.instance.api.updateActivity(widget.activity!['_id'] as String, body);
      if (mounted) Navigator.pop(context, true);
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isNew ? 'New eco activity' : 'Edit activity'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextFormField(
                controller: _name,
                enabled: _isNew,
                decoration: InputDecoration(
                  labelText: 'Name (English)',
                  helperText: _isNew ? 'e.g. Fixed a Leaky Tap' : 'Names stay fixed so existing posts keep their points',
                ),
                validator: (v) => (v ?? '').trim().length < 3 ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _nameAr, textDirection: TextDirection.rtl, decoration: const InputDecoration(labelText: 'Name (Arabic)')),
              const SizedBox(height: 12),
              TextFormField(controller: _line, decoration: const InputDecoration(labelText: 'Short description')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _lane,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [for (final l in activityLanes) DropdownMenuItem(value: l, child: Text(l))],
                    onChanged: (v) => setState(() => _lane = v ?? _lane),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _points,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Eco Points'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _co2,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    decoration: const InputDecoration(labelText: 'CO₂ saved (kg)'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                controller: _keywords,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Keywords', helperText: 'Comma separated, e.g. water, tap, leak, plumbing'),
              ),
              const SizedBox(height: 14),
              const Text('Icon', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final e in activityIcons.entries)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _icon = e.key),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _icon == e.key ? laneColor(_lane).withValues(alpha: 0.15) : Brand.canvas,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _icon == e.key ? laneColor(_lane) : Brand.border, width: _icon == e.key ? 2 : 1),
                      ),
                      child: Icon(e.value, size: 20, color: _icon == e.key ? laneColor(_lane) : Brand.muted),
                    ),
                  ),
              ]),
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
