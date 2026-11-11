import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../api/admin_api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/campaign_visuals.dart';
import '../widgets/common.dart';
import 'users_page.dart' show emirates;

class CampaignsPage extends StatefulWidget {
  const CampaignsPage({super.key});

  @override
  State<CampaignsPage> createState() => _CampaignsPageState();
}

class _CampaignsPageState extends State<CampaignsPage> {
  String _status = '';
  int _page = 1;
  Paged? _data;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await Session.instance.api.campaigns(status: _status, page: _page, limit: 12);
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _openEditor([Json? campaign]) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => CampaignEditor(campaign: campaign));
    if (saved == true) _load();
  }

  Future<void> _openDetail(Json campaign) async {
    final changed = await showDialog<bool>(context: context, builder: (_) => _CampaignDetail(campaign: campaign));
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Campaigns',
          subtitle: 'Approved environmental activities, field verifiers and verified outcomes',
          actions: [
            FilledButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New campaign'),
            ),
          ],
        ),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in const {'': 'All', 'active': 'Active', 'draft': 'Drafts', 'completed': 'Completed', 'cancelled': 'Cancelled'}.entries)
            ChoiceChip(
              label: Text(s.value),
              selected: _status == s.key,
              onSelected: (_) {
                setState(() {
                  _status = s.key;
                  _page = 1;
                  _data = null;
                });
                _load();
              },
            ),
        ]),
        const SizedBox(height: 16),
        if (_error != null)
          ErrorBox(error: _error!, onRetry: _load)
        else if (data == null)
          const Loading()
        else if (data.items.isEmpty)
          Panel(
            child: Column(children: [
              const EmptyState(
                icon: Icons.forest_outlined,
                title: 'No campaigns yet',
                message: 'Create a campaign, assign a field verifier and publish it to the app.',
              ),
              FilledButton.icon(onPressed: () => _openEditor(), icon: const Icon(Icons.add_rounded), label: const Text('New campaign')),
              const SizedBox(height: 24),
            ]),
          )
        else ...[
          ResponsiveGrid(
            minWidth: 330,
            maxColumns: 3,
            children: [for (final c in data.items) _CampaignCard(c: c, onTap: () => _openDetail(c))],
          ),
          Pager(
            page: data.page,
            pages: data.pages,
            total: data.total,
            limit: data.limit,
            onPage: (p) {
              _page = p;
              _load();
            },
          ),
        ],
      ],
    );
  }
}

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({required this.c, required this.onTap});
  final Json c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = c['status'] as String? ?? 'draft';
    final pending = (c['pendingReports'] as num?)?.toInt() ?? 0;
    final verifiers = List<Json>.from((c['verifiers'] as List? ?? const []).map((e) => Json.from(e as Map)));
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CampaignCover(
              category: c['category'] as String?,
              imageUrl: c['coverImage'] as String?,
              height: 110,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GlassChip(c['category'] as String? ?? ''),
                    const Spacer(),
                    _GlassChip(campaignStatusLabel(status), dot: campaignStatusColor(status)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c['title'] as String? ?? '',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(c['organiserName'] as String? ?? '', style: const TextStyle(color: Brand.muted, fontSize: 13)),
                  const SizedBox(height: 10),
                  _IconLine(Icons.place_outlined, '${c['locationName']}'),
                  const SizedBox(height: 4),
                  _IconLine(Icons.event_outlined, '${Fmt.date(c['startDate'])} – ${Fmt.date(c['endDate'])}'),
                  const SizedBox(height: 14),
                  _Meter(
                    label: 'Participants',
                    value: (c['participantCount'] as num?) ?? 0,
                    target: (c['targetParticipants'] as num?) ?? 1,
                    color: Brand.sky,
                  ),
                  const SizedBox(height: 10),
                  _Meter(
                    label: 'Verified ${c['outputUnit'] ?? ''}',
                    value: (c['verifiedOutput'] as num?) ?? 0,
                    target: (c['targetOutput'] as num?) ?? 0,
                    color: Brand.eco,
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    if (verifiers.isEmpty)
                      const StatusPill('No verifier', color: Brand.danger)
                    else
                      Expanded(
                        child: Row(children: [
                          const Icon(Icons.verified_user_rounded, size: 16, color: Brand.eco),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(verifiers.map((v) => v['name'] ?? '').join(', '),
                                overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ]),
                      ),
                    if (verifiers.isEmpty) const Spacer(),
                    if (pending > 0) StatusPill('$pending to review', color: Brand.coral),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  const _GlassChip(this.label, {this.dot});
  final String label;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dot != null) ...[
          Container(width: 7, height: 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 6),
        ],
        Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Brand.ink)),
      ]),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 15, color: Brand.muted),
      const SizedBox(width: 6),
      Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
    ]);
  }
}

class _Meter extends StatelessWidget {
  const _Meter({required this.label, required this.value, required this.target, required this.color});
  final String label;
  final num value;
  final num target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = target <= 0 ? 0.0 : (value / target).clamp(0, 1).toDouble();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: const TextStyle(fontSize: 12.5, color: Brand.muted, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(target > 0 ? '${Fmt.number(value)} / ${Fmt.number(target)}' : Fmt.number(value),
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 5),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(value: pct, minHeight: 7, backgroundColor: Brand.canvas, color: color),
      ),
    ]);
  }
}

/* ---------------- Detail ---------------- */

class _CampaignDetail extends StatefulWidget {
  const _CampaignDetail({required this.campaign});
  final Json campaign;

  @override
  State<_CampaignDetail> createState() => _CampaignDetailState();
}

class _CampaignDetailState extends State<_CampaignDetail> {
  late Json _c = widget.campaign;
  bool _busy = false;
  bool _changed = false;

  Future<void> _run(Future<Json> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      final updated = await action();
      setState(() {
        _c = {..._c, ...updated};
        _changed = true;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assign() async {
    final current = List<Json>.from((_c['verifiers'] as List? ?? const []).map((e) => Json.from(e as Map)));
    final picked = await showDialog<List<String>>(
      context: context,
      builder: (_) => _VerifierPicker(selected: current.map((v) => v['_id'] as String).toSet()),
    );
    if (picked == null) return;
    await _run(() => Session.instance.api.setCampaignVerifiers(_c['_id'] as String, picked), 'Field verifiers updated');
  }

  Future<void> _setStatus(String status, String done) =>
      _run(() => Session.instance.api.updateCampaign(_c['_id'] as String, {'status': status}), done);

  Future<void> _edit() async {
    final saved = await showDialog<bool>(context: context, builder: (_) => CampaignEditor(campaign: _c));
    if (saved == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final status = c['status'] as String? ?? 'draft';
    final verifiers = List<Json>.from((c['verifiers'] as List? ?? const []).map((e) => Json.from(e as Map)));
    final loc = Json.from(c['location'] as Map? ?? const {});
    final t = Theme.of(context).textTheme;
    final pending = (c['pendingReports'] as num?)?.toInt() ?? 0;

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 820),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CampaignCover(
                category: c['category'] as String?,
                imageUrl: c['coverImage'] as String?,
                height: 150,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 12, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        _GlassChip(c['category'] as String? ?? ''),
                        const SizedBox(width: 8),
                        _GlassChip(campaignStatusLabel(status), dot: campaignStatusColor(status)),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(_changed),
                          icon: const Icon(Icons.close_rounded, color: Colors.white),
                        ),
                      ]),
                      const Spacer(),
                      Text(c['title'] as String? ?? '',
                          style: t.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                      Text(c['organiserName'] as String? ?? '', style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if ((c['description'] as String?)?.isNotEmpty == true) ...[
                      Text(c['description'] as String, style: const TextStyle(height: 1.55)),
                      const SizedBox(height: 18),
                    ],
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      _Fact('Participants', '${Fmt.number(c['participantCount'] as num?)} / ${Fmt.number(c['targetParticipants'] as num?)}'),
                      _Fact('Verified people', Fmt.number(c['verifiedCount'] as num?)),
                      _Fact('Verified ${c['outputUnit'] ?? ''}', '${Fmt.number(c['verifiedOutput'] as num?)} / ${Fmt.number(c['targetOutput'] as num?)}'),
                      _Fact('Eco Points each', Fmt.number(c['pointsPerParticipant'] as num?)),
                    ]),
                    const SizedBox(height: 18),
                    _Row('Location', '${c['locationName']} · ${c['emirate']}'),
                    _Row('Coordinates', '${(loc['lat'] as num?)?.toStringAsFixed(5)}, ${(loc['lng'] as num?)?.toStringAsFixed(5)}  ·  site radius ${c['geofenceRadiusM']} m'),
                    _Row('Dates', '${Fmt.date(c['startDate'])} – ${Fmt.date(c['endDate'])}'),
                    _Row('Permit reference', (c['permitReference'] as String?)?.isNotEmpty == true ? c['permitReference'] as String : 'Not recorded'),
                    if ((c['requirements'] as String?)?.isNotEmpty == true) _Row('Requirements', c['requirements'] as String),
                    const SizedBox(height: 18),
                    Row(children: [
                      Text('Field verifiers', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      const Spacer(),
                      TextButton.icon(onPressed: _busy ? null : _assign, icon: const Icon(Icons.person_add_alt_1_rounded, size: 18), label: const Text('Assign')),
                    ]),
                    const SizedBox(height: 6),
                    if (verifiers.isEmpty)
                      const Text('No verifier assigned. Campaigns need one before they can be published.', style: TextStyle(color: Brand.danger))
                    else
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final v in verifiers)
                          Chip(
                            avatar: Avatar(name: v['name'] as String? ?? '', url: v['profileImage'] as String?, size: 24),
                            label: Text(v['name'] as String? ?? ''),
                            side: const BorderSide(color: Brand.border),
                            backgroundColor: Brand.surface,
                          ),
                      ]),
                    if (pending > 0) ...[
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop(_changed);
                          context.go('/verification');
                        },
                        icon: const Icon(Icons.fact_check_rounded),
                        label: Text('Review $pending verification report${pending == 1 ? '' : 's'}'),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.end, children: [
                      OutlinedButton.icon(onPressed: _busy ? null : _edit, icon: const Icon(Icons.edit_rounded, size: 18), label: const Text('Edit')),
                      if (status == 'draft')
                        FilledButton.icon(
                          onPressed: _busy ? null : () => _setStatus('active', 'Campaign published to the app'),
                          icon: const Icon(Icons.public_rounded, size: 18),
                          label: const Text('Publish'),
                        ),
                      if (status == 'active') ...[
                        OutlinedButton(
                          onPressed: _busy ? null : () => _setStatus('cancelled', 'Campaign cancelled'),
                          child: const Text('Cancel campaign'),
                        ),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: Brand.sky),
                          onPressed: _busy ? null : () => _setStatus('completed', 'Campaign marked completed'),
                          icon: const Icon(Icons.flag_rounded, size: 18),
                          label: const Text('Mark completed'),
                        ),
                      ],
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 145,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Brand.canvas, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Brand.muted, fontSize: 12)),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 140, child: Text(label, style: const TextStyle(color: Brand.muted))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

class _VerifierPicker extends StatefulWidget {
  const _VerifierPicker({required this.selected});
  final Set<String> selected;

  @override
  State<_VerifierPicker> createState() => _VerifierPickerState();
}

class _VerifierPickerState extends State<_VerifierPicker> {
  late final Set<String> _picked = {...widget.selected};
  late final Future<List<Json>> _future = Session.instance.api.verifiers();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign field verifiers'),
      content: SizedBox(
        width: 420,
        child: FutureBuilder<List<Json>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Loading();
            if (snap.hasError) return Text(snap.error.toString());
            final list = snap.data!;
            if (list.isEmpty) {
              return const Text('No field verifiers yet. Open a user in Users and turn on "Field verifier".');
            }
            return ListView(
              shrinkWrap: true,
              children: [
                for (final v in list)
                  CheckboxListTile(
                    value: _picked.contains(v['_id']),
                    onChanged: (on) => setState(() => on == true ? _picked.add(v['_id'] as String) : _picked.remove(v['_id'])),
                    secondary: Avatar(name: v['name'] as String? ?? '', url: v['profileImage'] as String?),
                    title: Text(v['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text([v['role'] == 'admin' ? 'Admin' : 'Field verifier', v['emirate'] ?? ''].where((s) => (s as String).isNotEmpty).join(' · ')),
                  ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _picked.toList()), child: const Text('Save')),
      ],
    );
  }
}

/* ---------------- Create / edit ---------------- */

class CampaignEditor extends StatefulWidget {
  const CampaignEditor({super.key, this.campaign});
  final Json? campaign;

  @override
  State<CampaignEditor> createState() => _CampaignEditorState();
}

class _CampaignEditorState extends State<CampaignEditor> {
  final _form = GlobalKey<FormState>();
  late final Json _c = widget.campaign ?? const {};
  late final _title = TextEditingController(text: _c['title'] as String? ?? '');
  late final _organiser = TextEditingController(text: _c['organiserName'] as String? ?? '');
  late final _description = TextEditingController(text: _c['description'] as String? ?? '');
  late final _locationName = TextEditingController(text: _c['locationName'] as String? ?? '');
  late final _lat = TextEditingController(text: (_c['location'] as Map?)?['lat']?.toString() ?? '');
  late final _lng = TextEditingController(text: (_c['location'] as Map?)?['lng']?.toString() ?? '');
  late final _radius = TextEditingController(text: (_c['geofenceRadiusM'] ?? 500).toString());
  late final _permit = TextEditingController(text: _c['permitReference'] as String? ?? '');
  late final _requirements = TextEditingController(text: _c['requirements'] as String? ?? '');
  late final _people = TextEditingController(text: (_c['targetParticipants'] ?? 50).toString());
  late final _output = TextEditingController(text: (_c['targetOutput'] ?? 100).toString());
  late final _unit = TextEditingController(text: _c['outputUnit'] as String? ?? 'trees');
  late final _points = TextEditingController(text: (_c['pointsPerParticipant'] ?? 50).toString());
  late String _category = _c['category'] as String? ?? campaignCategories.first;
  late String _emirate = _c['emirate'] as String? ?? 'Dubai';
  late DateTimeRange? _dates = _c['startDate'] == null
      ? null
      : DateTimeRange(
          start: Fmt.uae(_c['startDate']) ?? DateTime.now(),
          end: Fmt.uae(_c['endDate']) ?? DateTime.now(),
        );
  bool _saving = false;
  String? _error;

  bool get _editing => widget.campaign != null;

  @override
  void dispose() {
    for (final c in [_title, _organiser, _description, _locationName, _lat, _lng, _radius, _permit, _requirements, _people, _output, _unit, _points]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _dates,
      helpText: 'Campaign dates',
    );
    if (picked != null) setState(() => _dates = picked);
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_dates == null) {
      setState(() => _error = 'Choose the campaign dates');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    // Dates are picked as UAE calendar days: start 08:00, end 20:00 Gulf time.
    final start = DateTime.utc(_dates!.start.year, _dates!.start.month, _dates!.start.day, 4);
    final end = DateTime.utc(_dates!.end.year, _dates!.end.month, _dates!.end.day, 16);
    final body = <String, dynamic>{
      'title': _title.text.trim(),
      'category': _category,
      'organiserName': _organiser.text.trim(),
      'description': _description.text.trim(),
      'emirate': _emirate,
      'locationName': _locationName.text.trim(),
      'lat': double.tryParse(_lat.text.trim()),
      'lng': double.tryParse(_lng.text.trim()),
      'geofenceRadiusM': int.tryParse(_radius.text.trim()) ?? 500,
      'permitReference': _permit.text.trim(),
      'requirements': _requirements.text.trim(),
      'startDate': start.toIso8601String(),
      'endDate': end.toIso8601String(),
      'targetParticipants': int.tryParse(_people.text.trim()) ?? 1,
      'targetOutput': int.tryParse(_output.text.trim()) ?? 0,
      'outputUnit': _unit.text.trim(),
      'pointsPerParticipant': int.tryParse(_points.text.trim()) ?? 0,
    };
    try {
      final api = Session.instance.api;
      if (_editing) {
        await api.updateCampaign(widget.campaign!['_id'] as String, body);
      } else {
        await api.createCampaign(body);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_editing ? 'Campaign updated' : 'Draft created. Assign a verifier, then publish.')),
        );
        Navigator.of(context).pop(true);
      }
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _number(String? v, {double min = 0, double max = double.infinity}) {
    final n = double.tryParse((v ?? '').trim());
    if (n == null) return 'Enter a number';
    if (n < min || n > max) return 'Between ${min.toStringAsFixed(0)} and ${max.isInfinite ? '∞' : max.toStringAsFixed(0)}';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final digits = [FilteringTextInputFormatter.digitsOnly];
    final coord = [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.]'))];

    Widget field(TextEditingController c, String label,
            {String? Function(String?)? validator, int lines = 1, List<TextInputFormatter>? formatters, String? hint}) =>
        TextFormField(
          controller: c,
          maxLines: lines,
          validator: validator,
          inputFormatters: formatters,
          decoration: InputDecoration(labelText: label, hintText: hint, alignLabelWithHint: lines > 1),
        );

    Widget pair(Widget a, Widget b) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: a),
          const SizedBox(width: 12),
          Expanded(child: b),
        ]);

    Widget section(String title) => Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 10),
          child: Text(title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: Brand.coral)),
        );

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 860),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 8),
              child: Row(children: [
                Expanded(child: Text(_editing ? 'Edit campaign' : 'New campaign', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ]),
            ),
            const Divider(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      section('About'),
                      field(_title, 'Title', validator: (v) => (v == null || v.trim().length < 4) ? 'At least 4 characters' : null),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: [for (final c in campaignCategories) DropdownMenuItem(value: c, child: Text(c))],
                        onChanged: (v) => setState(() => _category = v ?? _category),
                      ),
                      const SizedBox(height: 12),
                      field(_organiser, 'Organising organisation', validator: _required),
                      const SizedBox(height: 12),
                      field(_description, 'Description', lines: 3),
                      section('Approved location'),
                      pair(
                        DropdownButtonFormField<String>(
                          initialValue: _emirate,
                          decoration: const InputDecoration(labelText: 'Emirate'),
                          items: [for (final e in emirates) DropdownMenuItem(value: e, child: Text(e))],
                          onChanged: (v) => setState(() => _emirate = v ?? _emirate),
                        ),
                        field(_locationName, 'Place name', validator: _required),
                      ),
                      const SizedBox(height: 12),
                      pair(
                        field(_lat, 'Latitude', formatters: coord, hint: '24.4489', validator: (v) => _number(v, min: -90, max: 90)),
                        field(_lng, 'Longitude', formatters: coord, hint: '54.4122', validator: (v) => _number(v, min: -180, max: 180)),
                      ),
                      const SizedBox(height: 12),
                      pair(
                        field(_radius, 'Site radius (metres)', formatters: digits, validator: (v) => _number(v, min: 50, max: 20000)),
                        field(_permit, 'Permit reference', hint: 'Land / activity permission'),
                      ),
                      section('Schedule & targets'),
                      InkWell(
                        onTap: _pickDates,
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Dates', suffixIcon: Icon(Icons.date_range_rounded)),
                          child: Text(_dates == null
                              ? 'Choose start and end'
                              : '${Fmt.day(_dates!.start)} – ${Fmt.day(_dates!.end)}'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      pair(
                        field(_people, 'Target participants', formatters: digits, validator: (v) => _number(v, min: 1)),
                        field(_points, 'Eco Points per verified participant', formatters: digits, validator: (v) => _number(v, min: 0, max: 1000)),
                      ),
                      const SizedBox(height: 12),
                      pair(
                        field(_output, 'Target output', formatters: digits, validator: (v) => _number(v, min: 0)),
                        field(_unit, 'Output unit', hint: 'trees, kg, bags', validator: _required),
                      ),
                      const SizedBox(height: 12),
                      field(_requirements, 'Participation requirements', lines: 2),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(_error!, style: const TextStyle(color: Brand.danger, fontWeight: FontWeight.w700)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
              child: Row(children: [
                if (!_editing)
                  const Expanded(
                    child: Text('Saved as a draft. Residents see it after you publish.', style: TextStyle(color: Brand.muted, fontSize: 13)),
                  )
                else
                  const Spacer(),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_editing ? 'Save changes' : 'Create draft'),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
