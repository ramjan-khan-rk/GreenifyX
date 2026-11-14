import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../api/admin_api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Save bytes as a file in the browser.
void saveFile(List<int> bytes, String name, String type) {
  final blob = web.Blob([Uint8List.fromList(bytes).toJS].toJS, web.BlobPropertyBag(type: type));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  a.click();
  web.URL.revokeObjectURL(url);
}

/// Partner portal: one organisation's live campaigns, members, impact and report downloads.
/// Partner logins see only their own organisation; admins can pick any organisation.
class PartnerPortalPage extends StatefulWidget {
  const PartnerPortalPage({super.key});

  @override
  State<PartnerPortalPage> createState() => _PartnerPortalPageState();
}

class _PartnerPortalPageState extends State<PartnerPortalPage> {
  Json? _data;
  Object? _error;
  String? _orgId;
  List<Json> _orgs = const [];
  bool _downloading = false;
  DateTimeRange? _range;

  bool get _admin => !Session.instance.isPartner;

  @override
  void initState() {
    super.initState();
    if (_admin) {
      _loadOrgs();
    } else {
      _load();
    }
  }

  Future<void> _loadOrgs() async {
    try {
      final r = await Session.instance.api.orgs();
      if (!mounted) return;
      setState(() {
        _orgs = r.page.items;
        _orgId = _orgs.isNotEmpty ? _orgs.first['_id'] as String : null;
      });
      if (_orgId != null) _load();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Map<String, dynamic> get _query => {
        if (_admin && _orgId != null) 'org': _orgId,
        if (_range != null) 'from': _range!.start.toIso8601String(),
        if (_range != null) 'to': _range!.end.add(const Duration(days: 1)).toIso8601String(),
      };

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = await Session.instance.api.getJson('/partner/overview', query: _query);
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _download(String format) async {
    setState(() => _downloading = true);
    try {
      final bytes = await Session.instance.api.getBytes('/partner/report', query: {..._query, 'format': format});
      final org = ((_data?['report'] as Map?)?['organisation'] as Map?)?['name']?.toString() ?? 'GreenifyX';
      final label = _data?['period']?['label']?.toString() ?? 'report';
      final name = 'GreenifyX-$org-$label'.replaceAll(RegExp(r'[^\w\- ]+'), '').trim().replaceAll(RegExp(r'\s+'), '-');
      const types = {'pdf': 'application/pdf', 'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'csv': 'text/csv'};
      saveFile(bytes, '$name.$format', types[format]!);
    } on ApiError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(context: context, firstDate: DateTime(2024), lastDate: now, initialDateRange: _range);
    if (r == null) return;
    setState(() => _range = r);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final report = d == null ? null : Json.from(d['report'] as Map);
    final t = report == null ? null : Json.from(report['totals'] as Map);
    final live = List<Json>.from((d?['liveCampaigns'] as List? ?? []).map((e) => Json.from(e as Map)));
    final members = List<Json>.from((report?['topMembers'] as List? ?? []).map((e) => Json.from(e as Map)));
    final orgName = (report?['organisation'] as Map?)?['name']?.toString() ?? 'Partner portal';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: orgName,
        subtitle: 'Live campaigns, members and verified impact${d == null ? '' : ' · ${d['period']['label']}'}',
        actions: [
          if (_admin && _orgs.isNotEmpty)
            SizedBox(
              width: 240,
              child: DropdownButtonFormField<String>(
                initialValue: _orgId,
                decoration: const InputDecoration(labelText: 'Organisation', isDense: true),
                items: [for (final o in _orgs) DropdownMenuItem(value: o['_id'] as String, child: Text(o['name'] as String? ?? '', overflow: TextOverflow.ellipsis))],
                onChanged: (v) {
                  setState(() => _orgId = v);
                  _load();
                },
              ),
            ),
          OutlinedButton.icon(onPressed: _pickRange, icon: const Icon(Icons.date_range_rounded), label: Text(_range == null ? 'Last month' : '${Fmt.date(_range!.start)} – ${Fmt.date(_range!.end)}')),
          FilledButton.icon(onPressed: _downloading || d == null ? null : () => _download('pdf'), icon: const Icon(Icons.picture_as_pdf_rounded), label: const Text('PDF')),
          FilledButton.tonalIcon(onPressed: _downloading || d == null ? null : () => _download('xlsx'), icon: const Icon(Icons.table_view_rounded), label: const Text('Excel')),
          TextButton(onPressed: _downloading || d == null ? null : () => _download('csv'), child: const Text('CSV')),
        ],
      ),
      if (_error != null)
        ErrorBox(error: _error!, onRetry: _admin ? _loadOrgs : _load)
      else if (_admin && _orgs.isEmpty && d == null)
        const Panel(child: EmptyState(icon: Icons.business_outlined, title: 'No organisations yet'))
      else if (t == null)
        const Loading()
      else ...[
        ResponsiveGrid(minWidth: 200, maxColumns: 4, children: [
          KpiCard(label: 'Members', value: Fmt.number(t['members'] as num?), icon: Icons.groups_rounded, color: Brand.sky, caption: '${t['participationRate']}% active'),
          KpiCard(label: 'UAE PASS verified', value: Fmt.number(d!['verifiedResidents'] as num?), icon: Icons.verified_user_rounded, color: Brand.eco),
          KpiCard(label: 'Verified actions', value: Fmt.number(t['verifiedActions'] as num?), icon: Icons.task_alt_rounded, color: Brand.coral),
          KpiCard(label: 'CO₂ saved (est.)', value: '${Fmt.number(t['co2Kg'] as num?)} kg', icon: Icons.eco_rounded, color: Brand.eco),
          KpiCard(label: 'Volunteer hours', value: Fmt.number(t['volunteerHours'] as num?), icon: Icons.schedule_rounded, color: Brand.sun),
          KpiCard(label: 'Trees planted', value: Fmt.number(t['treesPlanted'] as num?), icon: Icons.park_rounded, color: Brand.eco),
          KpiCard(label: 'Waste diverted', value: '${Fmt.number(t['wasteKg'] as num?)} kg', icon: Icons.recycling_rounded, color: Brand.sky),
          KpiCard(label: 'Campaigns', value: Fmt.number(t['campaigns'] as num?), icon: Icons.campaign_rounded, color: Brand.coral),
        ]),
        const SizedBox(height: 16),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Live campaigns', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (live.isEmpty) const Text('No active campaigns right now.', style: TextStyle(color: Brand.muted)),
            for (final c in live)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(c['title'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w700))),
                    StatusPill('${c['participants']} joined', color: Brand.sky),
                  ]),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: ((c['targetOutput'] as num? ?? 0) > 0) ? ((c['verifiedOutput'] as num) / (c['targetOutput'] as num)).clamp(0, 1).toDouble() : null,
                    minHeight: 6,
                    color: Brand.eco,
                    backgroundColor: Brand.border,
                  ),
                  const SizedBox(height: 4),
                  Text('${c['verifiedOutput']} of ${c['targetOutput']} ${c['outputUnit']} verified · ${c['emirate'] ?? ''}', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Most active members', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (members.isEmpty) const Text('No verified member actions in this period.', style: TextStyle(color: Brand.muted)),
            for (final m in members)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(m['name'] as String? ?? 'Member'),
                trailing: Text('${m['verifiedActions']} actions · ${m['co2Kg']} kg CO₂', style: const TextStyle(color: Brand.muted)),
              ),
            const SizedBox(height: 8),
            Text(report!['methodology'] as String? ?? '', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
          ]),
        ),
        const SizedBox(height: 8),
        const Text('A PDF and Excel report for the previous month is emailed to partner logins on the 1st of each month.', style: TextStyle(color: Brand.muted, fontSize: 12.5)),
      ],
    ]);
  }
}

/// Admin: give an organisation's staff a partner login.
class PartnerLoginsPage extends StatefulWidget {
  const PartnerLoginsPage({super.key});

  @override
  State<PartnerLoginsPage> createState() => _PartnerLoginsPageState();
}

class _PartnerLoginsPageState extends State<PartnerLoginsPage> {
  List<Json>? _partners;
  List<Json> _orgs = const [];
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final results = await Future.wait([Session.instance.api.getJson('/admin/partners'), Session.instance.api.orgs()]);
      if (!mounted) return;
      setState(() {
        _partners = List<Json>.from(((results[0] as Json)['partners'] as List).map((e) => Json.from(e as Map)));
        _orgs = (results[1] as ({Paged page, Map<String, int> counts})).page.items;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _add() async {
    final msg = await showDialog<String>(context: context, builder: (_) => _AddPartnerDialog(orgs: _orgs));
    if (msg == null) return;
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 6)));
    _load();
  }

  Future<void> _remove(Json p) async {
    await Session.instance.api.deleteJson('/admin/partners/${p['_id']}');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final list = _partners;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Partner and auditor logins',
        subtitle: 'Partners see only their own organisation. Auditors see only the audit trail, read-only.',
        actions: [FilledButton.icon(onPressed: _add, icon: const Icon(Icons.person_add_alt_rounded), label: const Text('Add login'))],
      ),
      if (_error != null)
        ErrorBox(error: _error!, onRetry: _load)
      else if (list == null)
        const Loading()
      else
        Panel(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: list.isEmpty
              ? const EmptyState(icon: Icons.badge_outlined, title: 'No partner logins yet')
              : Column(children: [
                  for (final p in list)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.badge_rounded, color: Brand.eco),
                      title: Text('${p['name'] ?? ''} · ${p['email'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(p['role'] == 'auditor' ? 'Auditor (read-only audit trail)' : (p['partnerOrg'] as Map?)?['name']?.toString() ?? 'No organisation'),
                      trailing: TextButton(onPressed: () => _remove(p), child: const Text('Remove access')),
                    ),
                ]),
        ),
    ]);
  }
}

class _AddPartnerDialog extends StatefulWidget {
  const _AddPartnerDialog({required this.orgs});
  final List<Json> orgs;

  @override
  State<_AddPartnerDialog> createState() => _AddPartnerDialogState();
}

class _AddPartnerDialogState extends State<_AddPartnerDialog> {
  final _email = TextEditingController();
  final _name = TextEditingController();
  late String _org = widget.orgs.isEmpty ? '' : widget.orgs.first['_id'] as String;
  String _role = 'partner';
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final r = await Session.instance.api.postJson('/admin/partners', {'email': _email.text.trim(), 'name': _name.text.trim(), 'org': _org, 'role': _role});
      if (mounted) Navigator.pop(context, r['message']?.toString() ?? 'Partner added');
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add partner login'),
        content: SizedBox(
          width: 440,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'partner', label: Text('Partner')), ButtonSegment(value: 'auditor', label: Text('Auditor'))],
              selected: {_role},
              onSelectionChanged: (v) => setState(() => _role = v.first),
            ),
            const SizedBox(height: 12),
            if (_role == 'partner') DropdownButtonFormField<String>(
              initialValue: _org,
              decoration: const InputDecoration(labelText: 'Organisation'),
              items: [for (final o in widget.orgs) DropdownMenuItem(value: o['_id'] as String, child: Text(o['name'] as String? ?? ''))],
              onChanged: (v) => setState(() => _org = v ?? _org),
            ),
            const SizedBox(height: 12),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Work email')),
            const SizedBox(height: 8),
            const Text('If they have no password yet, they set one with "Forgot password".', style: TextStyle(color: Brand.muted, fontSize: 12.5)),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Brand.danger))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Add')),
        ],
      );
}
