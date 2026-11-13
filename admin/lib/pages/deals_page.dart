import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../api/admin_api.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Brand deals: brands pay eco creators for real posted actions. Payouts happen
/// outside the app (bank transfer); mark them paid here.
class DealsPage extends StatefulWidget {
  const DealsPage({super.key});

  @override
  State<DealsPage> createState() => _DealsPageState();
}

class _DealsPageState extends State<DealsPage> {
  List<Json>? _deals;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = await Session.instance.api.getJson('/admin/deals');
      if (mounted) setState(() => _deals = List<Json>.from((d['deals'] as List).map((e) => Json.from(e as Map))));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _edit([Json? deal]) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => _DealDialog(deal: deal));
    if (ok == true) _load();
  }

  Future<void> _move(Json deal, Json app, String to) async {
    try {
      await Session.instance.api.patchJson('/admin/deals/${deal['_id']}/applications/${(app['user'] as Map)['_id']}', {'status': to});
      _load();
    } on ApiError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final deals = _deals;
    final all = deals?.expand((d) => (d['applications'] as List).map((a) => Json.from(a as Map))).toList() ?? [];
    final owed = deals?.fold<double>(0, (s, d) {
          final delivered = (d['applications'] as List).where((a) => (a as Map)['status'] == 'delivered').length;
          return s + delivered * ((d['youReceiveAed'] as num?)?.toDouble() ?? 0);
        }) ??
        0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Brand deals',
        subtitle: 'Paid briefs for eco creators. GreenifyX keeps a platform fee; payouts are bank transfers marked paid here.',
        actions: [FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add_rounded), label: const Text('New deal'))],
      ),
      if (_error != null)
        ErrorBox(error: _error!, onRetry: _load)
      else if (deals == null)
        const Loading()
      else ...[
        ResponsiveGrid(minWidth: 220, maxColumns: 4, children: [
          KpiCard(label: 'Open deals', value: '${deals.where((d) => d['status'] == 'open').length}', icon: Icons.handshake_rounded, color: Brand.eco),
          KpiCard(label: 'Applications', value: '${all.length}', icon: Icons.inbox_rounded, color: Brand.sky),
          KpiCard(label: 'Waiting for review', value: '${all.where((a) => a['status'] == 'applied').length}', icon: Icons.hourglass_top_rounded, color: Brand.sun),
          KpiCard(label: 'To pay creators', value: 'AED ${owed.toStringAsFixed(0)}', icon: Icons.payments_rounded, color: Brand.coral),
        ]),
        const SizedBox(height: 16),
        if (deals.isEmpty)
          const Panel(child: EmptyState(icon: Icons.handshake_outlined, title: 'No deals yet'))
        else
          for (final d in deals)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${d['brand']} · ${d['title']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        Text(
                          'AED ${d['payoutAed']} per creator (they get AED ${d['youReceiveAed']}) · ${d['slots']} spots · ${d['minFollowers']}+ followers'
                          '${d['deadline'] != null ? ' · until ${DateFormat('d MMM yyyy').format(DateTime.parse(d['deadline'] as String).toLocal())}' : ''}',
                          style: const TextStyle(color: Brand.muted, fontSize: 12.5),
                        ),
                      ]),
                    ),
                    StatusPill(d['status'] as String, color: d['status'] == 'open' ? Brand.eco : Brand.muted),
                    IconButton(tooltip: 'Edit', onPressed: () => _edit(d), icon: const Icon(Icons.edit_rounded)),
                  ]),
                  const Divider(),
                  if ((d['applications'] as List).isEmpty)
                    const Padding(padding: EdgeInsets.all(8), child: Text('No applications yet', style: TextStyle(color: Brand.muted)))
                  else
                    for (final raw in d['applications'] as List)
                      Builder(builder: (_) {
                        final a = Json.from(raw as Map);
                        final u = Json.from(a['user'] as Map? ?? {});
                        final s = a['status'] as String;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${u['name'] ?? ''} · ${a['followers']} followers', style: const TextStyle(fontWeight: FontWeight.w700)),
                                if ((a['pitch'] as String? ?? '').isNotEmpty) Text(a['pitch'] as String, style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
                                if (a['post'] != null) SelectableText('Post: ${a['post']}', style: const TextStyle(color: Brand.sky, fontSize: 12)),
                              ]),
                            ),
                            StatusPill(s, color: {'accepted': Brand.sky, 'delivered': Brand.sun, 'paid': Brand.eco, 'rejected': Brand.danger}[s] ?? Brand.muted),
                            const SizedBox(width: 6),
                            if (s == 'applied' || s == 'rejected') TextButton(onPressed: () => _move(d, a, 'accepted'), child: const Text('Accept')),
                            if (s == 'applied' || s == 'accepted') TextButton(onPressed: () => _move(d, a, 'rejected'), child: const Text('Reject')),
                            if (s == 'delivered') FilledButton(onPressed: () => _move(d, a, 'paid'), child: const Text('Mark paid')),
                          ]),
                        );
                      }),
                ]),
              ),
            ),
      ],
    ]);
  }
}

class _DealDialog extends StatefulWidget {
  const _DealDialog({this.deal});
  final Json? deal;

  @override
  State<_DealDialog> createState() => _DealDialogState();
}

class _DealDialogState extends State<_DealDialog> {
  final _form = GlobalKey<FormState>();
  late final _brand = TextEditingController(text: widget.deal?['brand'] as String? ?? '');
  late final _logo = TextEditingController(text: widget.deal?['brandLogo'] as String? ?? '');
  late final _title = TextEditingController(text: widget.deal?['title'] as String? ?? '');
  late final _brief = TextEditingController(text: widget.deal?['brief'] as String? ?? '');
  late final _activity = TextEditingController(text: widget.deal?['activity'] as String? ?? '');
  late final _hashtag = TextEditingController(text: widget.deal?['hashtag'] as String? ?? '');
  late final _payout = TextEditingController(text: '${widget.deal?['payoutAed'] ?? ''}');
  late final _fee = TextEditingController(text: '${widget.deal?['platformFeePct'] ?? 15}');
  late final _followers = TextEditingController(text: '${widget.deal?['minFollowers'] ?? 0}');
  late final _slots = TextEditingController(text: '${widget.deal?['slots'] ?? 5}');
  late DateTime? _deadline = DateTime.tryParse(widget.deal?['deadline'] as String? ?? '')?.toLocal();
  late String _status = widget.deal?['status'] as String? ?? 'draft';
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = {
      'brand': _brand.text.trim(),
      'brandLogo': _logo.text.trim(),
      'title': _title.text.trim(),
      'brief': _brief.text.trim(),
      'activity': _activity.text.trim(),
      'hashtag': _hashtag.text.trim().replaceAll('#', ''),
      'payoutAed': double.tryParse(_payout.text.trim()) ?? 0,
      'platformFeePct': double.tryParse(_fee.text.trim()) ?? 15,
      'minFollowers': int.tryParse(_followers.text.trim()) ?? 0,
      'slots': int.tryParse(_slots.text.trim()) ?? 5,
      'status': _status,
      'deadline': _deadline?.toUtc().toIso8601String(),
    };
    try {
      final id = widget.deal?['_id'] as String?;
      id == null ? await Session.instance.api.postJson('/admin/deals', body) : await Session.instance.api.patchJson('/admin/deals/$id', body);
      if (mounted) Navigator.pop(context, true);
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    return AlertDialog(
      title: Text(widget.deal == null ? 'New brand deal' : 'Edit brand deal'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(child: TextFormField(controller: _brand, decoration: const InputDecoration(labelText: 'Brand'), validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null)),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'draft', child: Text('Draft')),
                      DropdownMenuItem(value: 'open', child: Text('Open')),
                      DropdownMenuItem(value: 'closed', child: Text('Closed')),
                    ],
                    onChanged: (v) => setState(() => _status = v ?? _status),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'Title'), validator: (v) => (v ?? '').trim().length < 3 ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _brief, maxLines: 3, decoration: const InputDecoration(labelText: 'Brief for creators')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _activity, decoration: const InputDecoration(labelText: 'Eco action to post (optional)'))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _hashtag, decoration: const InputDecoration(labelText: 'Hashtag (optional)'))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _payout,
                    inputFormatters: digits,
                    decoration: const InputDecoration(labelText: 'Brand pays per creator (AED)'),
                    validator: (v) => (double.tryParse((v ?? '').trim()) ?? 0) <= 0 ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _fee, inputFormatters: digits, decoration: const InputDecoration(labelText: 'Platform fee %'))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _followers, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Min followers'))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _slots, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Creator spots'))),
              ]),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_rounded),
                title: Text(_deadline == null ? 'No deadline' : DateFormat('EEE d MMM yyyy').format(_deadline!)),
                subtitle: const Text('Deadline'),
                trailing: const Icon(Icons.edit_calendar_rounded),
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: _deadline ?? DateTime.now().add(const Duration(days: 14)), firstDate: DateTime.now(), lastDate: DateTime(2030));
                  if (d != null) setState(() => _deadline = DateTime(d.year, d.month, d.day, 23, 59));
                },
              ),
              TextFormField(controller: _logo, decoration: const InputDecoration(labelText: 'Brand logo URL (optional)')),
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
