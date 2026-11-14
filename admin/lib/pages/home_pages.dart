import 'package:flutter/material.dart';

import '../api/admin_api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Health sync, utility bills, households and Eco Academy at a glance.
class HomeHealthPage extends StatefulWidget {
  const HomeHealthPage({super.key});

  @override
  State<HomeHealthPage> createState() => _HomeHealthPageState();
}

class _HomeHealthPageState extends State<HomeHealthPage> {
  Json? _d;
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
      final d = await Session.instance.api.getJson('/admin/insights/home', query: {'days': _days});
      if (mounted) setState(() => _d = d);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    Json m(String k) => Json.from(d![k] as Map);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Home and health',
        subtitle: 'Steps and cycling, electricity and water bills, households and Eco Academy',
        actions: [
          SegmentedButton<int>(
            segments: const [ButtonSegment(value: 7, label: Text('7 days')), ButtonSegment(value: 30, label: Text('30 days')), ButtonSegment(value: 90, label: Text('90 days'))],
            selected: {_days},
            onSelectionChanged: (s) {
              setState(() => _days = s.first);
              _load();
            },
          ),
        ],
      ),
      if (_error != null)
        ErrorBox(error: _error!, onRetry: _load)
      else if (d == null)
        const Loading()
      else ...[
        ResponsiveGrid(minWidth: 200, maxColumns: 4, children: [
          KpiCard(label: 'People syncing steps', value: Fmt.number(m('health')['people'] as num?), icon: Icons.directions_walk_rounded, color: Brand.eco, caption: '${Fmt.compact(m('health')['steps'] as num?)} steps · ${m('health')['cycleKm']} km cycled'),
          KpiCard(label: 'Bills from photos', value: Fmt.number(m('bills')['photo'] as num?), icon: Icons.document_scanner_rounded, color: Brand.sky, caption: '${m('bills')['typed']} typed in · ≈ ${Fmt.number(m('bills')['co2Kg'] as num?)} kg CO₂'),
          KpiCard(label: 'Households', value: Fmt.number(m('households')['count'] as num?), icon: Icons.cottage_rounded, color: Brand.sun, caption: '${m('households')['members']} members · ${m('households')['goalsReachedThisWeek']} hit this week\'s goal'),
          KpiCard(label: 'Lessons passed', value: Fmt.number(m('academy')['passed'] as num?), icon: Icons.school_rounded, color: Brand.coral, caption: '${m('academy')['people']} learners · ${m('academy')['attempts']} attempts'),
        ]),
        const SizedBox(height: 12),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Latest bills read from photos', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const Text('Spot-check that the numbers match the photo. Points were paid only for photo bills.', style: TextStyle(color: Brand.muted, fontSize: 12.5)),
            const SizedBox(height: 8),
            if ((m('bills')['recent'] as List).isEmpty) const Text('No photo bills yet.', style: TextStyle(color: Brand.muted)),
            Wrap(spacing: 12, runSpacing: 12, children: [
              for (final b in (m('bills')['recent'] as List).map((e) => Json.from(e as Map)))
                SizedBox(
                  width: 220,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if ((b['photoUrl'] as String?)?.isNotEmpty == true)
                        InkWell(
                          onTap: () => showDialog<void>(context: context, builder: (_) => Dialog(child: InteractiveViewer(child: Image.network(b['photoUrl'] as String)))),
                          child: Image.network(b['photoUrl'] as String, height: 120, width: 220, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(height: 120)),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${b['provider']} · ${b['month']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text('${(b['user'] as Map?)?['name'] ?? ''}', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
                          Text('${b['electricityKwh']} kWh · ${b['waterLitres']} L · +${b['points']}', style: const TextStyle(fontSize: 12.5)),
                        ]),
                      ),
                    ]),
                  ),
                ),
            ]),
          ]),
        ),
      ],
    ]);
  }
}

/// Eco Academy lessons: edit text and quizzes, add new ones, switch them on or off.
class LessonsPage extends StatefulWidget {
  const LessonsPage({super.key});

  @override
  State<LessonsPage> createState() => _LessonsPageState();
}

class _LessonsPageState extends State<LessonsPage> {
  List<Json>? _lessons;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = await Session.instance.api.getJson('/admin/lessons');
      if (mounted) setState(() => _lessons = List<Json>.from((d['lessons'] as List).map((e) => Json.from(e as Map))));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _edit([Json? l]) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => _LessonDialog(lesson: l));
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final list = _lessons;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Eco Academy lessons',
        subtitle: 'One lesson a day rotates through the active lessons. Members earn points the first time they pass a quiz.',
        actions: [FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add_rounded), label: const Text('New lesson'))],
      ),
      if (_error != null)
        ErrorBox(error: _error!, onRetry: _load)
      else if (list == null)
        const Loading()
      else
        Panel(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: list.isEmpty
              ? const EmptyState(icon: Icons.school_outlined, title: 'Lessons appear here after the server starts once')
              : Column(children: [
                  for (final l in list)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Text(l['emoji'] as String? ?? '🌱', style: const TextStyle(fontSize: 24)),
                      title: Text(l['title'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${l['passed']} passed · ${l['attempts']} attempts${(l['titleAr'] as String?)?.isNotEmpty == true ? ' · has Arabic' : ''}'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Switch(
                          value: l['isActive'] != false,
                          onChanged: (v) async {
                            await Session.instance.api.patchJson('/admin/lessons/${l['_id']}', {'isActive': v});
                            _load();
                          },
                        ),
                        IconButton(tooltip: 'Edit', onPressed: () => _edit(l), icon: const Icon(Icons.edit_rounded)),
                      ]),
                    ),
                ]),
        ),
    ]);
  }
}

class _Q {
  _Q(Json? q)
      : q = TextEditingController(text: q?['q'] as String? ?? ''),
        qAr = TextEditingController(text: q?['qAr'] as String? ?? ''),
        options = List.generate(3, (i) => TextEditingController(text: ((q?['options'] as List?)?.length ?? 0) > i ? (q!['options'] as List)[i].toString() : '')),
        optionsAr = List.generate(3, (i) => TextEditingController(text: ((q?['optionsAr'] as List?)?.length ?? 0) > i ? (q!['optionsAr'] as List)[i].toString() : '')),
        why = TextEditingController(text: q?['why'] as String? ?? ''),
        answer = (q?['answer'] as num?)?.toInt() ?? 0;
  final TextEditingController q;
  final TextEditingController qAr;
  final List<TextEditingController> options;
  final List<TextEditingController> optionsAr;
  final TextEditingController why;
  int answer;

  Json toJson() => {
        'q': q.text.trim(),
        'qAr': qAr.text.trim(),
        'options': [for (final o in options) o.text.trim()],
        'optionsAr': [for (final o in optionsAr) o.text.trim()],
        'answer': answer,
        'why': why.text.trim(),
      };
}

class _LessonDialog extends StatefulWidget {
  const _LessonDialog({this.lesson});
  final Json? lesson;

  @override
  State<_LessonDialog> createState() => _LessonDialogState();
}

class _LessonDialogState extends State<_LessonDialog> {
  late final _emoji = TextEditingController(text: widget.lesson?['emoji'] as String? ?? '🌱');
  late final _title = TextEditingController(text: widget.lesson?['title'] as String? ?? '');
  late final _titleAr = TextEditingController(text: widget.lesson?['titleAr'] as String? ?? '');
  late final _cards = List.generate(3, (i) => TextEditingController(text: ((widget.lesson?['cards'] as List?)?.length ?? 0) > i ? (widget.lesson!['cards'] as List)[i].toString() : ''));
  late final _cardsAr = List.generate(3, (i) => TextEditingController(text: ((widget.lesson?['cardsAr'] as List?)?.length ?? 0) > i ? (widget.lesson!['cardsAr'] as List)[i].toString() : ''));
  late final List<_Q> _quiz = List.generate(3, (i) => _Q(((widget.lesson?['quiz'] as List?)?.length ?? 0) > i ? Json.from((widget.lesson!['quiz'] as List)[i] as Map) : null));
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = {
      'emoji': _emoji.text.trim(),
      'title': _title.text.trim(),
      'titleAr': _titleAr.text.trim(),
      'cards': [for (final c in _cards) c.text.trim()],
      'cardsAr': [for (final c in _cardsAr) c.text.trim()],
      'quiz': [for (final q in _quiz) if (q.q.text.trim().isNotEmpty) q.toJson()],
    };
    try {
      final id = widget.lesson?['_id'] as String?;
      id == null ? await Session.instance.api.postJson('/admin/lessons', body) : await Session.instance.api.patchJson('/admin/lessons/$id', body);
      if (mounted) Navigator.pop(context, true);
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _pair(TextEditingController en, TextEditingController ar, String label, {int lines = 1}) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: TextField(controller: en, maxLines: lines, decoration: InputDecoration(labelText: label))),
        const SizedBox(width: 10),
        Expanded(child: TextField(controller: ar, maxLines: lines, textDirection: TextDirection.rtl, decoration: InputDecoration(labelText: '$label (Arabic, optional)'))),
      ]);

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.lesson == null ? 'New lesson' : 'Edit lesson'),
        content: SizedBox(
          width: 760,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                SizedBox(width: 70, child: TextField(controller: _emoji, decoration: const InputDecoration(labelText: 'Emoji'))),
                const SizedBox(width: 10),
                Expanded(child: _pair(_title, _titleAr, 'Title')),
              ]),
              const SizedBox(height: 14),
              const Text('Cards (about 25 words each)', style: TextStyle(fontWeight: FontWeight.w800)),
              for (var i = 0; i < 3; i++) Padding(padding: const EdgeInsets.only(top: 8), child: _pair(_cards[i], _cardsAr[i], 'Card ${i + 1}', lines: 2)),
              const SizedBox(height: 14),
              const Text('Quiz (3 answers each; tick the right one)', style: TextStyle(fontWeight: FontWeight.w800)),
              for (var i = 0; i < 3; i++)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(border: Border.all(color: Brand.border), borderRadius: BorderRadius.circular(12)),
                  child: Column(children: [
                    _pair(_quiz[i].q, _quiz[i].qAr, 'Question ${i + 1}'),
                    for (var o = 0; o < 3; o++)
                      Row(children: [
                        IconButton(
                          tooltip: 'Right answer',
                          onPressed: () => setState(() => _quiz[i].answer = o),
                          icon: Icon(_quiz[i].answer == o ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: _quiz[i].answer == o ? Brand.eco : Brand.muted),
                        ),
                        Expanded(child: _pair(_quiz[i].options[o], _quiz[i].optionsAr[o], 'Answer ${o + 1}')),
                      ]),
                    TextField(controller: _quiz[i].why, decoration: const InputDecoration(labelText: 'Why (shown after answering)')),
                  ]),
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
