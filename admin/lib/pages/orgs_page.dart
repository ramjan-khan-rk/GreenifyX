import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/admin_api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

IconData orgIcon(String type) => switch (type) {
      'Company' => Icons.business_rounded,
      'School' => Icons.school_rounded,
      'University' => Icons.account_balance_rounded,
      'NGO' => Icons.volunteer_activism_rounded,
      'Community' => Icons.holiday_village_rounded,
      'Government' => Icons.account_balance_wallet_rounded,
      _ => Icons.groups_rounded,
    };

Color orgStatusColor(String s) => switch (s) {
      'verified' => Brand.eco,
      'pending' => Brand.sun,
      'suspended' => Brand.danger,
      _ => Brand.muted,
    };

class OrgsPage extends StatefulWidget {
  const OrgsPage({super.key});

  @override
  State<OrgsPage> createState() => _OrgsPageState();
}

class _OrgsPageState extends State<OrgsPage> {
  String _status = '';
  int _page = 1;
  ({Paged page, Map<String, int> counts})? _data;
  Object? _error;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = await Session.instance.api.orgs(status: _status, page: _page);
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _set(Json o, String status) async {
    String note = '';
    if (status == 'rejected' || status == 'suspended') {
      final r = await showDialog<String>(context: context, builder: (_) => _NoteDialog(status: status, name: o['name'] as String? ?? ''));
      if (r == null) return;
      note = r;
    }
    final id = o['_id'] as String;
    setState(() => _busy.add(id));
    try {
      await Session.instance.api.setOrgStatus(id, status, note: note);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(switch (status) {
          'verified' => '${o['name']} is now verified and can run or sponsor campaigns.',
          'suspended' => 'Organisation suspended.',
          'rejected' => 'Application rejected.',
          _ => 'Status updated.',
        }),
      ));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final c = d?.counts ?? const <String, int>{};
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader(
        title: 'Organisations',
        subtitle: 'Companies, schools and communities with verified team impact',
      ),
      if (d != null) ...[
        ResponsiveGrid(minWidth: 220, maxColumns: 4, children: [
          KpiCard(label: 'Verified', value: Fmt.number(c['verified'] ?? 0), icon: Icons.verified_rounded, color: Brand.eco),
          KpiCard(label: 'Awaiting review', value: Fmt.number(c['pending'] ?? 0), icon: Icons.hourglass_top_rounded, color: Brand.sun),
          KpiCard(label: 'Suspended', value: Fmt.number(c['suspended'] ?? 0), icon: Icons.block_rounded, color: Brand.danger),
          KpiCard(label: 'Rejected', value: Fmt.number(c['rejected'] ?? 0), icon: Icons.do_not_disturb_on_rounded, color: Brand.muted),
        ]),
        const SizedBox(height: 16),
      ],
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final s in const {'': 'All', 'pending': 'Awaiting review', 'verified': 'Verified', 'suspended': 'Suspended', 'rejected': 'Rejected'}.entries)
          ChoiceChip(
            label: Text(s.value),
            selected: _status == s.key,
            onSelected: (_) {
              setState(() {
                _status = s.key;
                _page = 1;
              });
              _load();
            },
          ),
      ]),
      const SizedBox(height: 16),
      if (_error != null)
        ErrorBox(error: _error!, onRetry: _load)
      else if (d == null)
        const Loading()
      else if (d.page.items.isEmpty)
        const Panel(child: EmptyState(icon: Icons.business_rounded, title: 'No organisations here', message: 'Organisations register from the app.'))
      else ...[
        ResponsiveGrid(minWidth: 380, maxColumns: 3, children: [
          for (final o in d.page.items) _OrgCard(o: o, busy: _busy.contains(o['_id']), onSet: (s) => _set(o, s)),
        ]),
        Pager(
          page: d.page.page,
          pages: d.page.pages,
          total: d.page.total,
          limit: d.page.limit,
          onPage: (p) {
            _page = p;
            _load();
          },
        ),
      ],
    ]);
  }
}

class _OrgCard extends StatelessWidget {
  const _OrgCard({required this.o, required this.busy, required this.onSet});
  final Json o;
  final bool busy;
  final ValueChanged<String> onSet;

  @override
  Widget build(BuildContext context) {
    final status = o['status'] as String? ?? 'pending';
    final type = o['type'] as String? ?? '';
    final impact = o['impact'] is Map ? Json.from(o['impact'] as Map) : null;
    final owner = o['owner'] is Map ? Json.from(o['owner'] as Map) : null;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: Brand.sky.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(orgIcon(type), color: Brand.sky),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16), overflow: TextOverflow.ellipsis),
              Text([type, o['emirate']].where((v) => (v as String?)?.isNotEmpty == true).join(' · '),
                  style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
            ]),
          ),
          StatusPill(status[0].toUpperCase() + status.substring(1), color: orgStatusColor(status)),
        ]),
        const SizedBox(height: 14),
        _Line('Members', Fmt.number(o['memberCount'] as num?)),
        _Line('Owner', owner == null ? '—' : '${owner['name']}${(owner['email'] as String?)?.isNotEmpty == true ? ' · ${owner['email']}' : ''}'),
        _Line('Registration ref.', (o['registrationRef'] as String?)?.isNotEmpty == true ? o['registrationRef'] as String : 'Not provided'),
        if ((o['contactEmail'] as String?)?.isNotEmpty == true) _Line('Contact', o['contactEmail'] as String),
        Row(children: [
          const SizedBox(width: 130, child: Text('Join code', style: TextStyle(color: Brand.muted))),
          Text(o['joinCode'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2)),
          IconButton(
            tooltip: 'Copy',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: o['joinCode'] as String? ?? ''));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Join code copied')));
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
          ),
        ]),
        if ((o['statusNote'] as String?)?.isNotEmpty == true) _Line('Note', o['statusNote'] as String),
        if (impact != null) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _Mini('Points (90d)', Fmt.compact(impact['points'] as num?)),
            _Mini('Verified participations', Fmt.number(impact['participations'] as num?)),
            _Mini('Trees', Fmt.number(impact['trees'] as num?)),
            _Mini('CO₂', Fmt.co2(impact['co2Kg'] as num?)),
          ]),
        ],
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (status == 'pending' || status == 'suspended' || status == 'rejected')
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Brand.eco),
              onPressed: busy ? null : () => onSet('verified'),
              icon: const Icon(Icons.verified_rounded, size: 18),
              label: Text(status == 'pending' ? 'Verify' : 'Reinstate'),
            ),
          if (status == 'pending')
            OutlinedButton(onPressed: busy ? null : () => onSet('rejected'), child: const Text('Reject')),
          if (status == 'verified')
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Brand.danger),
              onPressed: busy ? null : () => onSet('suspended'),
              child: const Text('Suspend'),
            ),
        ]),
      ]),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(color: Brand.muted))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}

class _Mini extends StatelessWidget {
  const _Mini(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Brand.canvas, borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: Brand.muted, fontSize: 11.5)),
        ]),
      );
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.status, required this.name});
  final String status;
  final String name;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.status == 'suspended' ? 'Suspend ${widget.name}?' : 'Reject ${widget.name}?'),
      content: SizedBox(
        width: 400,
        child: TextField(controller: _c, maxLength: 300, maxLines: 2, decoration: const InputDecoration(labelText: 'Reason')),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Brand.danger),
          onPressed: () {
            if (_c.text.trim().length < 3) return;
            Navigator.pop(context, _c.text.trim());
          },
          child: Text(widget.status == 'suspended' ? 'Suspend' : 'Reject'),
        ),
      ],
    );
  }
}
