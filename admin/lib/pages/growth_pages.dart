import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../api/admin_api.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'users_page.dart' show emirates;

/* ======================= Sponsored challenges ======================= */

class SponsoredPage extends StatefulWidget {
  const SponsoredPage({super.key});

  @override
  State<SponsoredPage> createState() => _SponsoredPageState();
}

class _SponsoredPageState extends State<SponsoredPage> {
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
      final items = await Session.instance.api.sponsored();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _edit([Json? c]) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => _SponsoredDialog(c: c));
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    num sum(String k) => items?.fold<num>(0, (s, c) => s + ((c[k] as num?) ?? 0)) ?? 0;
    final now = DateTime.now();
    final live = items?.where((c) => c['isActive'] != false && (DateTime.tryParse(c['endsAt'] as String? ?? '') ?? now).isAfter(now)).length ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Sponsored challenges',
        subtitle: 'Brand-funded city-wide challenges — the GreenifyX revenue line. Track reach and results for each sponsor.',
        actions: [FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add_rounded), label: const Text('New sponsored challenge'))],
      ),
      if (items != null) ...[
        ResponsiveGrid(minWidth: 200, maxColumns: 5, children: [
          KpiCard(label: 'Live challenges', value: '$live', icon: Icons.campaign_rounded, color: Brand.coral),
          KpiCard(label: 'Impressions', value: NumberFormat.compact().format(sum('impressions')), icon: Icons.visibility_rounded, color: Brand.sky),
          KpiCard(label: 'Participants', value: '${sum('participants')}', icon: Icons.people_alt_rounded, color: Brand.eco),
          KpiCard(label: 'Posts generated', value: '${sum('postsGenerated')}', icon: Icons.photo_library_rounded, color: Brand.sun),
          KpiCard(label: 'Sponsor budget', value: 'AED ${NumberFormat.compact().format(sum('budgetAed'))}', icon: Icons.payments_rounded, color: Brand.ink),
        ]),
        const SizedBox(height: 16),
      ],
      if (_error != null)
        ErrorBox(error: _error!, onRetry: _load)
      else if (items == null)
        const Loading()
      else if (items.isEmpty)
        const Panel(child: EmptyState(icon: Icons.campaign_outlined, title: 'No sponsored challenges yet', message: 'Create one for a brand partner — e.g. "Refill Rally by AquaPure".'))
      else
        for (final c in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Panel(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 120,
                    height: 80,
                    child: (c['coverImage'] as String? ?? '').isEmpty
                        ? Container(color: Brand.blush)
                        : Image.network(c['coverImage'] as String, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: Brand.blush)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${(c['sponsor'] as Map?)?['name'] ?? ''}', style: const TextStyle(color: Brand.coral, fontWeight: FontWeight.w800, fontSize: 12.5)),
                    Text(c['title'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                    const SizedBox(height: 4),
                    Text(
                      '${c['target']}× ${(c['activity'] as String? ?? '').isEmpty ? 'any action' : c['activity']}${(c['hashtag'] as String? ?? '').isEmpty ? '' : ' · #${c['hashtag']}'} · +${c['rewardPoints']} pts'
                      ' · ${DateFormat('d MMM').format(DateTime.parse(c['startsAt'] as String).toLocal())} – ${DateFormat('d MMM').format(DateTime.parse(c['endsAt'] as String).toLocal())}',
                      style: const TextStyle(color: Brand.muted, fontSize: 12.5),
                    ),
                    const SizedBox(height: 10),
                    Wrap(spacing: 18, runSpacing: 8, children: [
                      _Metric('Impressions', '${c['impressions'] ?? 0}'),
                      _Metric('Joined', '${c['participants'] ?? 0}'),
                      _Metric('Conversion', '${c['conversion'] ?? 0}%'),
                      _Metric('Completed', '${c['completed'] ?? 0}'),
                      _Metric('Posts', '${c['postsGenerated'] ?? 0}'),
                      _Metric('Points paid', '${c['pointsPaid'] ?? 0}'),
                    ]),
                  ]),
                ),
                Column(children: [
                  Switch(
                    value: c['isActive'] != false,
                    onChanged: (v) async {
                      await Session.instance.api.updateSponsored(c['_id'] as String, {'isActive': v});
                      _load();
                    },
                  ),
                  IconButton(tooltip: 'Edit', onPressed: () => _edit(c), icon: const Icon(Icons.edit_rounded)),
                ]),
              ]),
            ),
          ),
    ]);
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        Text(label, style: const TextStyle(color: Brand.muted, fontSize: 11.5)),
      ]);
}

class _SponsoredDialog extends StatefulWidget {
  const _SponsoredDialog({this.c});
  final Json? c;

  @override
  State<_SponsoredDialog> createState() => _SponsoredDialogState();
}

class _SponsoredDialogState extends State<_SponsoredDialog> {
  late final Json _sp = Json.from((widget.c?['sponsor'] ?? {}) as Map);
  late final _title = TextEditingController(text: widget.c?['title'] as String? ?? '');
  late final _desc = TextEditingController(text: widget.c?['description'] as String? ?? '');
  late final _sponsor = TextEditingController(text: _sp['name'] as String? ?? '');
  late final _logo = TextEditingController(text: _sp['logo'] as String? ?? '');
  late final _color = TextEditingController(text: _sp['color'] as String? ?? '#1F8A70');
  late final _cover = TextEditingController(text: widget.c?['coverImage'] as String? ?? '');
  late final _activity = TextEditingController(text: widget.c?['activity'] as String? ?? '');
  late final _hashtag = TextEditingController(text: widget.c?['hashtag'] as String? ?? '');
  late final _target = TextEditingController(text: '${widget.c?['target'] ?? 5}');
  late final _reward = TextEditingController(text: '${widget.c?['rewardPoints'] ?? 100}');
  late final _prize = TextEditingController(text: widget.c?['prize'] as String? ?? '');
  late final _maxWinners = TextEditingController(text: '${widget.c?['maxWinners'] ?? 0}');
  late final _budget = TextEditingController(text: '${widget.c?['budgetAed'] ?? 0}');
  late DateTime _start = DateTime.tryParse(widget.c?['startsAt'] as String? ?? '')?.toLocal() ?? DateTime.now();
  late DateTime _end = DateTime.tryParse(widget.c?['endsAt'] as String? ?? '')?.toLocal() ?? DateTime.now().add(const Duration(days: 30));
  late final Set<String> _emirates = {...((widget.c?['emirates'] as List?) ?? []).map((e) => e.toString())};
  bool _saving = false;
  String? _error;

  Future<void> _pick(bool start) async {
    final d = await showDatePicker(context: context, initialDate: start ? _start : _end, firstDate: DateTime(2025), lastDate: DateTime(2030));
    if (d != null) setState(() => start ? _start = d : _end = DateTime(d.year, d.month, d.day, 23, 59));
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = {
      'title': _title.text.trim(),
      'description': _desc.text.trim(),
      'sponsor': {'name': _sponsor.text.trim(), 'logo': _logo.text.trim(), 'color': _color.text.trim()},
      'coverImage': _cover.text.trim(),
      'activity': _activity.text.trim(),
      'hashtag': _hashtag.text.trim(),
      'target': int.tryParse(_target.text) ?? 5,
      'rewardPoints': int.tryParse(_reward.text) ?? 100,
      'prize': _prize.text.trim(),
      'maxWinners': int.tryParse(_maxWinners.text) ?? 0,
      'budgetAed': int.tryParse(_budget.text) ?? 0,
      'startsAt': _start.toUtc().toIso8601String(),
      'endsAt': _end.toUtc().toIso8601String(),
      'emirates': _emirates.toList(),
    };
    try {
      final id = widget.c?['_id'] as String?;
      id == null ? await Session.instance.api.createSponsored(body) : await Session.instance.api.updateSponsored(id, body);
      if (mounted) Navigator.pop(context, true);
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.digitsOnly];
    Widget row(List<Widget> c) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [for (var i = 0; i < c.length; i++) ...[if (i > 0) const SizedBox(width: 12), Expanded(child: c[i])]]),
        );
    return AlertDialog(
      title: Text(widget.c == null ? 'New sponsored challenge' : 'Edit sponsored challenge'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            row([TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title'))]),
            row([TextField(controller: _desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Description'))]),
            row([
              TextField(controller: _sponsor, decoration: const InputDecoration(labelText: 'Sponsor name')),
              TextField(controller: _logo, decoration: const InputDecoration(labelText: 'Sponsor logo URL')),
              TextField(controller: _color, decoration: const InputDecoration(labelText: 'Brand colour #hex')),
            ]),
            row([TextField(controller: _cover, decoration: const InputDecoration(labelText: 'Cover image URL'))]),
            row([
              TextField(controller: _activity, decoration: const InputDecoration(labelText: 'Activity name (empty = any)')),
              TextField(controller: _hashtag, decoration: const InputDecoration(labelText: 'Hashtag (without #)')),
            ]),
            row([
              TextField(controller: _target, inputFormatters: digits, decoration: const InputDecoration(labelText: 'Posts to finish')),
              TextField(controller: _reward, inputFormatters: digits, decoration: const InputDecoration(labelText: 'Eco Points reward')),
              TextField(controller: _maxWinners, inputFormatters: digits, decoration: const InputDecoration(labelText: 'Max winners (0 = all)')),
              TextField(controller: _budget, inputFormatters: digits, decoration: const InputDecoration(labelText: 'Budget AED')),
            ]),
            row([TextField(controller: _prize, decoration: const InputDecoration(labelText: 'Prize text (e.g. AED 25 voucher)'))]),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => _pick(true), icon: const Icon(Icons.event_rounded), label: Text('Starts ${DateFormat('d MMM yyyy').format(_start)}'))),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton.icon(onPressed: () => _pick(false), icon: const Icon(Icons.event_available_rounded), label: Text('Ends ${DateFormat('d MMM yyyy').format(_end)}'))),
            ]),
            const SizedBox(height: 12),
            const Text('Emirates (none = all UAE)', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in emirates) FilterChip(label: Text(e), selected: _emirates.contains(e), onSelected: (v) => setState(() => v ? _emirates.add(e) : _emirates.remove(e))),
            ]),
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
}

/* ======================= Verified badges ======================= */

class BadgesPage extends StatefulWidget {
  const BadgesPage({super.key});

  @override
  State<BadgesPage> createState() => _BadgesPageState();
}

class _BadgesPageState extends State<BadgesPage> {
  List<Json>? _users;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final u = await Session.instance.api.badgeUsers();
      if (mounted) setState(() => _users = u);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _decide(Json u, String action, {String? type}) async {
    try {
      await Session.instance.api.decideBadge(u['_id'] as String, action, type: type);
      _load();
    } on ApiError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = _users;
    final pending = users?.where((u) => (u['badgeRequest'] as Map?)?['status'] == 'pending').toList() ?? [];
    final verified = users?.where((u) => (u['verifiedBadge'] as String? ?? '').isNotEmpty).toList() ?? [];
    Widget row(Json u, {required bool isPending}) {
      final req = Json.from((u['badgeRequest'] ?? {}) as Map);
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Brand.border))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Avatar(url: u['profileImage'] as String?, name: u['name'] as String? ?? '?'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(u['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                if (!isPending) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified_rounded, size: 16, color: Color(0xFF1D9BF0))),
              ]),
              Text('${u['email'] ?? ''} · ${u['followers']} followers · level ${u['level']}', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
              if (isPending && (req['note'] as String? ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('“${req['note']}”', style: const TextStyle(fontStyle: FontStyle.italic))),
              if (isPending && (req['links'] as String? ?? '').isNotEmpty) SelectableText(req['links'] as String, style: const TextStyle(color: Brand.sky, fontSize: 12.5)),
            ]),
          ),
          StatusPill(isPending ? 'wants: ${req['type']}' : u['verifiedBadge'] as String, color: isPending ? Brand.sun : Brand.sky),
          const SizedBox(width: 8),
          if (isPending) ...[
            FilledButton(onPressed: () => _decide(u, 'approve', type: req['type'] as String?), child: const Text('Approve')),
            const SizedBox(width: 6),
            TextButton(style: TextButton.styleFrom(foregroundColor: Brand.danger), onPressed: () => _decide(u, 'reject'), child: const Text('Reject')),
          ] else
            TextButton(style: TextButton.styleFrom(foregroundColor: Brand.danger), onPressed: () => _decide(u, 'revoke'), child: const Text('Revoke')),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader(title: 'Verified badges', subtitle: 'Approve blue ticks for creators, organisations, verifiers and official accounts'),
      if (_error != null)
        ErrorBox(error: _error!, onRetry: _load)
      else if (users == null)
        const Loading()
      else ...[
        Panel(
          title: 'Requests (${pending.length})',
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: pending.isEmpty ? const EmptyState(icon: Icons.inbox_outlined, title: 'No pending requests') : Column(children: [for (final u in pending) row(u, isPending: true)]),
        ),
        const SizedBox(height: 16),
        Panel(
          title: 'Verified (${verified.length})',
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: verified.isEmpty ? const EmptyState(icon: Icons.verified_outlined, title: 'No verified accounts yet') : Column(children: [for (final u in verified) row(u, isPending: false)]),
        ),
      ],
    ]);
  }
}

/* ======================= Public ESG report ======================= */

class EsgReportPage extends StatefulWidget {
  const EsgReportPage({super.key, required this.token});
  final String token;

  @override
  State<EsgReportPage> createState() => _EsgReportPageState();
}

class _EsgReportPageState extends State<EsgReportPage> {
  Json? _r;
  String? _error;

  @override
  void initState() {
    super.initState();
    Session.instance.api.publicEsg(widget.token).then((r) {
      if (mounted) setState(() => _r = r);
    }).catchError((e) {
      if (mounted) setState(() => _error = e is ApiError ? e.message : 'Report not available');
    });
  }

  String _csv(Json r) {
    final t = Json.from(r['totals'] as Map);
    final b = StringBuffer('Metric,Value\n');
    for (final e in t.entries) {
      b.writeln('${e.key},${e.value}');
    }
    b.writeln('\nTop members,Actions,Volunteer hours,CO2 kg');
    for (final m in (r['topMembers'] as List)) {
      final mm = m as Map;
      b.writeln('"${mm['name']}",${mm['verifiedActions']},${mm['volunteerHours']},${mm['co2Kg']}');
    }
    b.writeln('\nCampaign,Emirate,Output,Participants,Status');
    for (final c in (r['campaigns'] as List)) {
      final cc = c as Map;
      b.writeln('"${cc['title']}",${cc['emirate']},${cc['output']},${cc['participants']},${cc['status']}');
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    final org = r == null ? <String, dynamic>{} : Json.from(r['organisation'] as Map);
    final t = r == null ? <String, dynamic>{} : Json.from(r['totals'] as Map);
    String d(Object? iso) {
      final x = DateTime.tryParse('$iso')?.toLocal();
      return x == null ? '' : DateFormat('d MMM yyyy').format(x);
    }

    return Scaffold(
      backgroundColor: Brand.canvas,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: _error != null
                ? Padding(padding: const EdgeInsets.all(60), child: Text(_error!, style: const TextStyle(fontSize: 18)))
                : r == null
                    ? const Padding(padding: EdgeInsets.all(60), child: CircularProgressIndicator())
                    : Container(
                        padding: const EdgeInsets.all(36),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Brand.border)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/brand/app_icon_rounded.png', width: 40, height: 40)),
                            const SizedBox(width: 12),
                            const Text('GreenifyX', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                            const Spacer(),
                            OutlinedButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _csv(r)));
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV copied — paste into Excel or Google Sheets')));
                              },
                              icon: const Icon(Icons.table_view_rounded),
                              label: const Text('Copy CSV'),
                            ),
                            const SizedBox(width: 8),
                            const Tooltip(message: 'Use your browser: Ctrl+P → Save as PDF', child: Icon(Icons.print_rounded, color: Brand.muted)),
                          ]),
                          const SizedBox(height: 26),
                          const Text('ENVIRONMENTAL IMPACT REPORT (ESG)', style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.w800, color: Brand.eco)),
                          const SizedBox(height: 6),
                          Text('${org['name']}', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Brand.ink)),
                          Text('${org['type']} · ${org['emirate'] ?? ''} · ${d((r['period'] as Map)['from'])} – ${d((r['period'] as Map)['to'])}', style: const TextStyle(color: Brand.muted)),
                          const SizedBox(height: 26),
                          ResponsiveGrid(minWidth: 180, maxColumns: 4, children: [
                            KpiCard(label: 'Members', value: '${t['members']}', icon: Icons.people_alt_rounded, color: Brand.sky, caption: '${t['participationRate']}% took verified action'),
                            KpiCard(label: 'Verified actions', value: '${t['verifiedActions']}', icon: Icons.verified_rounded, color: Brand.eco),
                            KpiCard(label: 'Volunteer hours', value: '${t['volunteerHours']}', icon: Icons.schedule_rounded, color: Brand.coral),
                            KpiCard(label: 'Trees planted', value: '${t['treesPlanted']}', icon: Icons.park_rounded, color: const Color(0xFF56AB2F)),
                            KpiCard(label: 'Waste collected', value: '${t['wasteKg']} kg', icon: Icons.recycling_rounded, color: Brand.sun),
                            KpiCard(label: 'CO₂ avoided (est.)', value: '${t['co2Kg']} kg', icon: Icons.co2_rounded, color: Brand.ink),
                            KpiCard(label: 'Campaigns', value: '${t['campaigns']}', icon: Icons.forest_rounded, color: Brand.eco),
                          ]),
                          const SizedBox(height: 26),
                          const Text('Top contributors', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                          const SizedBox(height: 8),
                          for (final m in (r['topMembers'] as List).cast<Map>())
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(children: [
                                Expanded(child: Text('${m['name']}')),
                                Text('${m['verifiedActions']} actions · ${m['volunteerHours']} h · ${m['co2Kg']} kg CO₂', style: const TextStyle(color: Brand.muted)),
                              ]),
                            ),
                          if ((r['campaigns'] as List).isNotEmpty) ...[
                            const SizedBox(height: 22),
                            const Text('Campaigns', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                            const SizedBox(height: 8),
                            for (final c in (r['campaigns'] as List).cast<Map>())
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(children: [
                                  Expanded(child: Text('${c['title']} · ${c['emirate']}')),
                                  Text('${c['output']} · ${c['participants']} people · ${c['status']}', style: const TextStyle(color: Brand.muted)),
                                ]),
                              ),
                          ],
                          const SizedBox(height: 26),
                          Text('Methodology: ${r['methodology']}', style: const TextStyle(color: Brand.muted, fontSize: 12.5, height: 1.5)),
                          Text('Generated ${d(r['generatedAt'])} by GreenifyX.', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
                        ]),
                      ),
          ),
        ),
      ),
    );
  }
}

/* ======================= Invite landing ======================= */

class JoinInvitePage extends StatelessWidget {
  const JoinInvitePage({super.key, required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.cream,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.asset('assets/brand/app_icon_rounded.png', width: 72, height: 72)),
                const SizedBox(height: 18),
                const Text("You're invited to GreenifyX 🌱", textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text('Join the UAE community taking real, verified action for the planet. Use this code when you sign up — you and your friend both get bonus Eco Points.',
                    textAlign: TextAlign.center, style: TextStyle(color: Brand.muted, height: 1.5)),
                const SizedBox(height: 20),
                SelectableText(code.toUpperCase(), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 4, color: Brand.coral)),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Clipboard.setData(ClipboardData(text: code.toUpperCase())),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy code'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
