import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/admin_api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'partner_pages.dart' show saveFile;

/// Public page a school or employer sees after scanning a member's passport QR.
class PassportVerifyPage extends StatefulWidget {
  const PassportVerifyPage({super.key, required this.code});
  final String code;

  @override
  State<PassportVerifyPage> createState() => _PassportVerifyPageState();
}

class _PassportVerifyPageState extends State<PassportVerifyPage> {
  Json? _p;
  String? _error;

  @override
  void initState() {
    super.initState();
    Session.instance.api.getJson('/public/passport/${widget.code}').then((r) {
      if (mounted) setState(() => _p = Json.from(r['passport'] as Map));
    }).catchError((Object e) {
      if (mounted) setState(() => _error = e is ApiError ? e.message : 'Passport not found');
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final t = p == null ? null : Json.from(p['totals'] as Map);
    return Scaffold(
      backgroundColor: Brand.canvas,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
            Text('GreenifyX impact passport', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Brand.muted, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            if (_error != null)
              Panel(child: Text(_error!, style: const TextStyle(fontSize: 16)))
            else if (p == null)
              const Loading()
            else ...[
              Text(p['name'] as String? ?? '', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [
                StatusPill(p['code'] as String, color: Brand.ink),
                if (p['verifiedResident'] == true) const StatusPill('UAE PASS verified resident', color: Brand.eco),
                if ((p['emirate'] as String?)?.isNotEmpty == true) StatusPill(p['emirate'] as String, color: Brand.sky),
              ]),
              const SizedBox(height: 16),
              ResponsiveGrid(minWidth: 160, maxColumns: 3, children: [
                KpiCard(label: 'Verified actions', value: Fmt.number(t!['verifiedActions'] as num?), icon: Icons.task_alt_rounded, color: Brand.eco),
                KpiCard(label: 'Volunteer hours', value: '${t['volunteerHours']}', icon: Icons.schedule_rounded, color: Brand.sun),
                KpiCard(label: 'Campaigns', value: Fmt.number(t['campaigns'] as num?), icon: Icons.campaign_rounded, color: Brand.coral),
              ]),
              const SizedBox(height: 16),
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Verified record', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 6),
                  for (final r in (p['record'] as List).map((e) => Json.from(e as Map)))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(r['title'] as String? ?? ''),
                      subtitle: Text('${Fmt.date(r['at'])} · ${r['method']}${r['hours'] != null ? ' · ${r['hours']} h' : ''}${(r['by'] as String?)?.isNotEmpty == true ? ' · ${r['by']}' : ''}'),
                    ),
                  const SizedBox(height: 8),
                  Text('${p['methodology']} Checked ${DateFormat('d MMM yyyy, h:mm a').format(DateTime.now())}.', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Audit trail: trace figures to actions and verifiers, sample and recheck, export evidence.
class AuditPage extends StatefulWidget {
  const AuditPage({super.key});

  @override
  State<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends State<AuditPage> {
  Json? _actions;
  List<Json>? _samples;
  Object? _error;
  DateTimeRange _range = DateTimeRange(start: DateTime.now().subtract(const Duration(days: 30)), end: DateTime.now());
  String _emirate = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic> get _q => {
        'from': _range.start.toIso8601String(),
        'to': _range.end.add(const Duration(days: 1)).toIso8601String(),
        if (_emirate.isNotEmpty) 'emirate': _emirate,
      };

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Future.wait([Session.instance.api.getJson('/audit/actions', query: _q), Session.instance.api.getJson('/audit/samples')]);
      if (!mounted) return;
      setState(() {
        _actions = r[0];
        _samples = List<Json>.from((r[1]['samples'] as List).map((e) => Json.from(e as Map)));
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _export(String format) async {
    try {
      final bytes = await Session.instance.api.getBytes('/audit/export', query: {..._q, 'format': format});
      saveFile(bytes, 'GreenifyX-audit.$format', format == 'xlsx' ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' : 'text/csv');
    } on ApiError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _newSample() async {
    final size = await showDialog<int>(
      context: context,
      builder: (_) {
        var v = 25;
        return AlertDialog(
          title: const Text('New random sample'),
          content: StatefulBuilder(
            builder: (context, set) => Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Pick $v verified actions at random from ${Fmt.date(_range.start.toIso8601String())} to ${Fmt.date(_range.end.toIso8601String())} to recheck.'),
              Slider(value: v.toDouble(), min: 5, max: 100, divisions: 19, label: '$v', onChanged: (x) => set(() => v = x.round())),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, v), child: const Text('Create')),
          ],
        );
      },
    );
    if (size == null) return;
    final r = await Session.instance.api.postJson('/audit/samples', {'from': _q['from'], 'to': _q['to'], 'size': size});
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => _SampleView(id: (r['sample'] as Map)['_id'] as String)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final a = _actions;
    final byMethod = Json.from(a?['byMethod'] as Map? ?? {});
    final rows = List<Json>.from((a?['actions'] as List? ?? []).map((e) => Json.from(e as Map)));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Audit trail',
        subtitle: 'Every verified action, how it was verified and who verified it. Sample, recheck and export the evidence.',
        actions: [
          OutlinedButton.icon(
            onPressed: () async {
              final r = await showDateRangePicker(context: context, firstDate: DateTime(2024), lastDate: DateTime.now(), initialDateRange: _range);
              if (r == null) return;
              setState(() => _range = r);
              _load();
            },
            icon: const Icon(Icons.date_range_rounded),
            label: Text('${Fmt.date(_range.start.toIso8601String())} – ${Fmt.date(_range.end.toIso8601String())}'),
          ),
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<String>(
              initialValue: _emirate,
              decoration: const InputDecoration(labelText: 'Emirate', isDense: true),
              items: [const DropdownMenuItem(value: '', child: Text('All')), for (final e in const ['Abu Dhabi', 'Dubai', 'Sharjah', 'Ajman', 'Umm Al Quwain', 'Ras Al Khaimah', 'Fujairah']) DropdownMenuItem(value: e, child: Text(e))],
              onChanged: (v) {
                setState(() => _emirate = v ?? '');
                _load();
              },
            ),
          ),
          FilledButton.tonalIcon(onPressed: () => _export('xlsx'), icon: const Icon(Icons.table_view_rounded), label: const Text('Export Excel')),
          TextButton(onPressed: () => _export('csv'), child: const Text('CSV')),
          FilledButton.icon(onPressed: _newSample, icon: const Icon(Icons.casino_rounded), label: const Text('Random sample')),
        ],
      ),
      if (_error != null)
        ErrorBox(error: _error!, onRetry: _load)
      else if (a == null)
        const Loading()
      else ...[
        ResponsiveGrid(minWidth: 180, maxColumns: 4, children: [
          KpiCard(label: 'Verified actions', value: Fmt.number(a['total'] as num?), icon: Icons.task_alt_rounded, color: Brand.eco),
          KpiCard(label: 'By friends', value: Fmt.number(byMethod['friend'] as num?), icon: Icons.people_rounded, color: Brand.sky),
          KpiCard(label: 'By AI check', value: Fmt.number(byMethod['ai'] as num?), icon: Icons.auto_awesome_rounded, color: Brand.sun),
          KpiCard(label: 'By admins', value: Fmt.number(byMethod['admin'] as num?), icon: Icons.verified_rounded, color: Brand.coral),
        ]),
        const SizedBox(height: 12),
        if ((_samples ?? []).isNotEmpty)
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Samples', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              for (final s in _samples!)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${s['label']} · ${Fmt.date(s['createdAt'])}'),
                  subtitle: Text('${s['reviewed']} of ${s['size']} checked${s['passRate'] != null ? ' · ${s['passRate']}% passed' : ''} · from ${s['population']} actions'),
                  trailing: StatusPill(s['status'] as String, color: s['status'] == 'closed' ? Brand.eco : Brand.sun),
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => _SampleView(id: s['_id'] as String)));
                    _load();
                  },
                ),
            ]),
          ),
        const SizedBox(height: 12),
        Panel(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: rows.isEmpty
              ? const EmptyState(icon: Icons.fact_check_outlined, title: 'No verified actions in this period')
              : Column(children: [
                  for (final r in rows)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${r['activity']} · ${r['userName']}'),
                      subtitle: Text('${Fmt.date(r['postedAt'])} · ${r['method']}${(r['verifierName'] as String?)?.isNotEmpty == true ? ' (${r['verifierName']})' : ''} · ${r['points']} pts ${r['pointsStatus'] == 'reversed' ? '(reversed)' : ''}'),
                      trailing: Text(r['emirate'] as String? ?? '', style: const TextStyle(color: Brand.muted)),
                    ),
                  if ((a['total'] as num) > rows.length) Padding(padding: const EdgeInsets.all(8), child: Text('Showing ${rows.length} of ${a['total']}. Export for the full list.', style: const TextStyle(color: Brand.muted))),
                ]),
        ),
      ],
    ]);
  }
}

class _SampleView extends StatefulWidget {
  const _SampleView({required this.id});
  final String id;

  @override
  State<_SampleView> createState() => _SampleViewState();
}

class _SampleViewState extends State<_SampleView> {
  Json? _s;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await Session.instance.api.getJson('/audit/samples/${widget.id}');
    if (mounted) setState(() => _s = Json.from(r['sample'] as Map));
  }

  Future<void> _review(Json item, String result) async {
    final note = TextEditingController();
    var reverse = false;
    final isAdmin = !Session.instance.isPartner && Session.instance.admin?['role'] != 'auditor';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: Text(result == 'pass' ? 'Mark as genuine' : 'Mark as failed'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: note, decoration: const InputDecoration(labelText: 'Note (what you checked)')),
            if (result == 'fail' && isAdmin)
              CheckboxListTile(contentPadding: EdgeInsets.zero, value: reverse, onChanged: (v) => set(() => reverse = v ?? false), title: const Text('Reverse the points for this action')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await Session.instance.api.patchJson('/audit/samples/${widget.id}/items/${item['_id']}', {'result': result, 'note': note.text.trim(), 'reverse': reverse});
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final sum = s == null ? null : Json.from(s['summary'] as Map);
    return Scaffold(
      backgroundColor: Brand.canvas,
      appBar: AppBar(title: Text(s?['label'] as String? ?? 'Sample')),
      body: s == null
          ? const Loading()
          : ListView(padding: const EdgeInsets.all(20), children: [
              Text('${sum!['reviewed']} of ${sum['size']} checked${sum['passRate'] != null ? ' · ${sum['passRate']}% passed' : ''} · picked at random (seed ${s['seed']}) from ${s['population']} verified actions'),
              const SizedBox(height: 12),
              for (final it in (s['items'] as List).map((e) => Json.from(e as Map)))
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if ((it['image'] as String?)?.isNotEmpty == true)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(it['image'] as String, width: 120, height: 120, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(width: 120, height: 120)),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${it['activity']} · ${(it['user'] as Map?)?['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text('${Fmt.date(it['postedAt'])} · verified by ${it['verifiedBy']}${(it['verifier'] as Map?)?['name'] != null ? ' (${(it['verifier'] as Map)['name']})' : ''} · ${it['points']} pts'),
                          if ((it['note'] as String?)?.isNotEmpty == true) Text('Note: ${it['note']}', style: const TextStyle(color: Brand.muted)),
                          if (it['reversed'] == true) const Text('Points reversed', style: TextStyle(color: Brand.danger)),
                          const SizedBox(height: 8),
                          Row(children: [
                            StatusPill(it['result'] as String, color: it['result'] == 'pass' ? Brand.eco : it['result'] == 'fail' ? Brand.danger : Brand.muted),
                            const Spacer(),
                            TextButton(onPressed: () => _review(it, 'pass'), child: const Text('Genuine')),
                            TextButton(onPressed: () => _review(it, 'fail'), child: const Text('Failed')),
                          ]),
                        ]),
                      ),
                    ]),
                  ),
                ),
            ]),
    );
  }
}

/// Where Stripe sends a creator after payout setup.
class PayoutResultPage extends StatelessWidget {
  const PayoutResultPage({super.key, required this.done});
  final bool done;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Brand.canvas,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(done ? Icons.check_circle_rounded : Icons.refresh_rounded, size: 64, color: done ? Brand.eco : Brand.sun),
              const SizedBox(height: 12),
              Text(done ? 'Payout details sent to Stripe' : 'That link expired', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                done ? 'Go back to the GreenifyX app. Brand deal payments will go straight to your bank once Stripe confirms your details.' : 'Go back to the GreenifyX app and tap "Set up payouts" again.',
                textAlign: TextAlign.center,
              ),
            ]),
          ),
        ),
      );
}
