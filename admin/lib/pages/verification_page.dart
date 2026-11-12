import 'package:flutter/material.dart';

import '../api/admin_api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/campaign_visuals.dart';
import '../widgets/common.dart';

class VerificationPage extends StatefulWidget {
  const VerificationPage({super.key});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  String _status = 'pending';
  int _page = 1;
  Paged? _data;
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
      final data = await Session.instance.api.reports(status: _status, page: _page, limit: 8);
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _review(Json r, bool approve) async {
    String note = '';
    if (approve && r['kind'] == 'survival_check') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Approve ${r['checkpointDays']}-day survival check?'),
          content: Text(
            '${Fmt.number(r['outputCount'] as num?)} living trees will be recorded against this campaign. '
            'Survival checks update the impact record only. No Eco Points are credited.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Brand.eco),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Approve'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    } else if (approve) {
      final attendees = (r['attendees'] as List? ?? const []).length;
      final each = ((r['campaign'] as Map?)?['pointsPerParticipant'] as num?) ?? 0;
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Approve this report?'),
          content: Text(
            r['outcome'] == 'unsuccessful'
                ? 'The activity is recorded as unsuccessful, so no Eco Points will be credited.'
                : '$attendees participant${attendees == 1 ? '' : 's'} will receive ${Fmt.number(each)} Eco Points each '
                    '(${Fmt.number(attendees * each)} in total). Every credit is written to the points ledger and can be reversed.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Brand.eco),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Approve & credit'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    } else {
      final reason = await showDialog<String>(context: context, builder: (_) => const _RejectDialog());
      if (reason == null) return;
      note = reason;
    }

    final id = r['_id'] as String;
    setState(() => _busy.add(id));
    try {
      final updated = await Session.instance.api.reviewReport(id, approve: approve, note: note);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(approve
            ? (updated['kind'] == 'survival_check'
                ? 'Survival check approved. The campaign survival record was updated.'
                : 'Approved. ${Fmt.number(updated['pointsCredited'] as num?)} Eco Points credited.')
            : 'Report rejected. No points were credited.'),
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
    final data = _data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(
          title: 'Field verification',
          subtitle: 'Evidence submitted by authorised verifiers. Eco Points are credited only after approval.',
        ),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in const {'pending': 'Awaiting review', 'flagged': 'Flagged', 'approved': 'Approved', 'rejected': 'Rejected'}.entries)
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
            child: EmptyState(
              icon: _status == 'pending' || _status == 'flagged' ? Icons.task_alt_rounded : Icons.inbox_rounded,
              title: _status == 'pending' || _status == 'flagged' ? 'Nothing waiting' : 'No reports here',
              message: _status == 'pending' ? 'New field reports will appear here as verifiers submit them.' : null,
            ),
          )
        else ...[
          for (final r in data.items) ...[
            _ReportCard(
              r: r,
              busy: _busy.contains(r['_id']),
              onApprove: () => _review(r, true),
              onReject: () => _review(r, false),
            ),
            const SizedBox(height: 16),
          ],
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

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.r, required this.busy, required this.onApprove, required this.onReject});
  final Json r;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final campaign = Json.from(r['campaign'] as Map? ?? const {});
    final verifier = Json.from(r['verifier'] as Map? ?? const {});
    final photos = List<Json>.from((r['photos'] as List? ?? const []).map((e) => Json.from(e as Map)));
    final attendees = List<Json>.from((r['attendees'] as List? ?? const []).map((e) => Json.from(e as Map)));
    final flags = List<String>.from(r['flags'] as List? ?? const []);
    final species = List<String>.from(r['species'] as List? ?? const []);
    final status = r['status'] as String? ?? 'pending';
    final inside = r['withinGeofence'] == true;
    final gps = Json.from(r['gps'] as Map? ?? const {});
    final survival = r['kind'] == 'survival_check';
    final planted = (campaign['verifiedOutput'] as num?) ?? 0;

    final evidence = _Evidence(photos: photos);
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text(campaign['title'] as String? ?? 'Campaign',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17), overflow: TextOverflow.ellipsis),
          ),
          _StatusBadge(status),
        ]),
        const SizedBox(height: 4),
        Text(campaign['locationName'] as String? ?? '', style: const TextStyle(color: Brand.muted, fontSize: 13)),
        if (survival) ...[
          const SizedBox(height: 8),
          StatusPill('Tree survival check · ${r['checkpointDays']} days', color: Brand.eco),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Avatar(name: verifier['name'] as String? ?? '', url: verifier['profileImage'] as String?, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: verifier['name'] as String? ?? 'Verifier', style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: '  ·  submitted ${Fmt.date(r['submittedAt'])}, ${Fmt.ago(r['submittedAt'])}', style: const TextStyle(color: Brand.muted)),
            ])),
          ),
        ]),
        const SizedBox(height: 14),
        _CheckLine(
          ok: inside,
          text: '${Fmt.number(r['distanceM'] as num?)} m from the approved site '
              '(${inside ? 'inside' : 'outside'} the ${campaign['geofenceRadiusM'] ?? '–'} m area)',
        ),
        _CheckLine(
          ok: !flags.contains('low_gps_accuracy'),
          text: gps['accuracyM'] == null ? 'GPS accuracy not reported' : 'GPS accuracy ±${gps['accuracyM']} m',
        ),
        if (!survival)
          _CheckLine(ok: !flags.contains('outside_campaign_dates'), text: 'Server timestamp ${flags.contains('outside_campaign_dates') ? 'outside' : 'within'} campaign dates'),
        _CheckLine(ok: !flags.contains('duplicate_photo'), text: flags.contains('duplicate_photo') ? 'A photo matches an earlier report' : 'Photos are unique'),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          if (survival) ...[
            _Mini('Verified planted', Fmt.number(planted)),
            _Mini('Still alive', Fmt.number(r['outputCount'] as num?)),
            _Mini('Survival', planted > 0 ? '${((r['outputCount'] as num? ?? 0) / planted * 100).round()}%' : '—'),
          ] else ...[
            _Mini('Outcome', '${r['outcome']}'.replaceFirstMapped(RegExp(r'^.'), (m) => m[0]!.toUpperCase())),
            _Mini('Recorded', '${Fmt.number(r['outputCount'] as num?)} ${campaign['outputUnit'] ?? ''}'),
            _Mini('Attendees', Fmt.number(attendees.length)),
          ],
          if (status == 'approved') _Mini('Points credited', Fmt.number(r['pointsCredited'] as num?)),
        ]),
        if (species.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Species: ${species.join(', ')}', style: const TextStyle(fontSize: 13)),
        ],
        if ((r['notes'] as String?)?.isNotEmpty == true) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Brand.canvas, borderRadius: BorderRadius.circular(10)),
            child: Text('“${r['notes']}”', style: const TextStyle(fontStyle: FontStyle.italic, height: 1.45)),
          ),
        ],
        if (attendees.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 30,
            child: Stack(children: [
              for (var i = 0; i < attendees.length && i < 8; i++)
                Positioned(
                  left: i * 22.0,
                  child: Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                    child: Avatar(name: attendees[i]['name'] as String? ?? '', url: attendees[i]['profileImage'] as String?, size: 26),
                  ),
                ),
              if (attendees.length > 8)
                Positioned(
                  left: 8 * 22.0 + 6,
                  top: 6,
                  child: Text('+${attendees.length - 8}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
            ]),
          ),
        ],
        if (flags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final f in flags) StatusPill(flagLabels[f] ?? f, color: Brand.danger),
          ]),
        ],
        if (status != 'pending' && (r['reviewNote'] as String?)?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          Text('Review note: ${r['reviewNote']}', style: const TextStyle(color: Brand.muted)),
        ],
        if (status == 'pending') ...[
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Brand.danger, minimumSize: const Size(0, 44)),
                onPressed: busy ? null : onReject,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Reject'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Brand.eco),
                onPressed: busy ? null : onApprove,
                icon: const Icon(Icons.check_rounded),
                label: Text(survival ? 'Approve' : 'Approve & credit'),
              ),
            ),
          ]),
        ],
      ],
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: flags.isNotEmpty && status == 'pending' ? Brand.danger.withValues(alpha: 0.45) : Brand.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(builder: (context, c) {
          if (c.maxWidth < 760) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [evidence, const SizedBox(height: 16), details]);
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 340, child: evidence),
            const SizedBox(width: 22),
            Expanded(child: details),
          ]);
        }),
      ),
    );
  }
}

class _Evidence extends StatelessWidget {
  const _Evidence({required this.photos});
  final List<Json> photos;

  void _open(BuildContext context, Json p) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(24),
        child: Stack(children: [
          InteractiveViewer(child: Image.network(p['url'] as String, fit: BoxFit.contain)),
          Positioned(
            right: 8,
            top: 8,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(color: Brand.canvas, borderRadius: BorderRadius.circular(12)),
        child: const Center(child: Text('No photos', style: TextStyle(color: Brand.muted))),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in photos)
          SizedBox(
            width: photos.length == 1 ? 340 : 166,
            child: InkWell(
              onTap: () => _open(context, p),
              borderRadius: BorderRadius.circular(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Stack(fit: StackFit.expand, children: [
                    Image.network(p['url'] as String? ?? '',
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(color: Brand.canvas, child: const Icon(Icons.broken_image_outlined, color: Brand.muted))),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Brand.ink.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(6)),
                        child: Text((p['kind'] as String? ?? 'photo').toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CheckLine extends StatelessWidget {
  const _CheckLine({required this.ok, required this.text});
  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded, size: 18, color: ok ? Brand.eco : Brand.danger),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5))),
      ]),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Brand.canvas, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(color: Brand.muted, fontSize: 11.5)),
      ]),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      'approved' => const StatusPill('Approved', color: Brand.eco),
      'rejected' => const StatusPill('Rejected', color: Brand.danger),
      _ => const StatusPill('Awaiting review', color: Brand.sun),
    };
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _ctrl = TextEditingController();
  static const _quick = ['Location does not match the site', 'Photos do not show the activity', 'Count not supported by evidence', 'Duplicate submission'];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject report'),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('The verifier sees this reason. No Eco Points are credited.'),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final q in _quick) ActionChip(label: Text(q), onPressed: () => setState(() => _ctrl.text = q)),
          ]),
          const SizedBox(height: 12),
          TextField(controller: _ctrl, maxLength: 500, maxLines: 2, decoration: const InputDecoration(labelText: 'Reason')),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Brand.danger),
          onPressed: () {
            if (_ctrl.text.trim().length < 3) return;
            Navigator.pop(context, _ctrl.text.trim());
          },
          child: const Text('Reject'),
        ),
      ],
    );
  }
}
