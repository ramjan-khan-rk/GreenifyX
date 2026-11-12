import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/admin_api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

const issueCategories = ['Illegal Dumping', 'Overflowing Bin', 'Littering', 'Polluted Area', 'Damaged Facility', 'Other'];

IconData issueIcon(String c) => switch (c) {
      'Illegal Dumping' => Icons.delete_forever_rounded,
      'Overflowing Bin' => Icons.delete_outline_rounded,
      'Littering' => Icons.local_drink_rounded,
      'Polluted Area' => Icons.water_damage_rounded,
      'Damaged Facility' => Icons.build_circle_rounded,
      _ => Icons.report_rounded,
    };

Color issueStatusColor(String s) => switch (s) {
      'submitted' => Brand.coral,
      'under_review' => Brand.sun,
      'forwarded' => Brand.sky,
      'resolved' => Brand.eco,
      'rejected' => Brand.muted,
      _ => Brand.muted,
    };

class IssuesPage extends StatefulWidget {
  const IssuesPage({super.key});

  @override
  State<IssuesPage> createState() => _IssuesPageState();
}

class _IssuesPageState extends State<IssuesPage> {
  String _status = 'open';
  String _category = '';
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
      final data = await Session.instance.api.issues(status: _status, category: _category, page: _page);
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _move(Json r, String next) async {
    String note = '';
    String forwardedTo = '';
    if (next != 'under_review') {
      final result = await showDialog<({String note, String to})>(context: context, builder: (_) => _ActionDialog(next: next));
      if (result == null) return;
      note = result.note;
      forwardedTo = result.to;
    }
    final id = r['_id'] as String;
    setState(() => _busy.add(id));
    try {
      final updated = await Session.instance.api.updateIssue(id, next, note: note, forwardedTo: forwardedTo);
      if (!mounted) return;
      final pts = (updated['pointsCredited'] as num?)?.toInt() ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(switch (next) {
          'under_review' => 'Marked under review. The reporter was notified.',
          'forwarded' => 'Recorded as shared with $forwardedTo.',
          'resolved' => pts > 0 ? 'Resolved. Reporter earned $pts Eco Points.' : 'Resolved.',
          _ => 'Report closed.',
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
    final data = _data;
    final counts = data?.counts ?? const <String, int>{};
    final open = (counts['submitted'] ?? 0) + (counts['under_review'] ?? 0) + (counts['forwarded'] ?? 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(
          title: 'Report & Restore',
          subtitle: 'Environmental problems reported by residents, with photo and GPS evidence',
        ),
        if (data != null) ...[
          ResponsiveGrid(minWidth: 200, maxColumns: 4, children: [
            KpiCard(label: 'New', value: Fmt.number(counts['submitted'] ?? 0), icon: Icons.fiber_new_rounded, color: Brand.coral),
            KpiCard(label: 'In progress', value: Fmt.number((counts['under_review'] ?? 0) + (counts['forwarded'] ?? 0)), icon: Icons.pending_actions_rounded, color: Brand.sun),
            KpiCard(label: 'Resolved', value: Fmt.number(counts['resolved'] ?? 0), icon: Icons.task_alt_rounded, color: Brand.eco),
            KpiCard(label: 'Closed', value: Fmt.number(counts['rejected'] ?? 0), icon: Icons.do_not_disturb_on_rounded, color: Brand.muted),
          ]),
          const SizedBox(height: 16),
        ],
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (final s in {
            'open': 'Open ($open)',
            'submitted': 'New',
            'under_review': 'Under review',
            'forwarded': 'Shared',
            'resolved': 'Resolved',
            'rejected': 'Closed',
          }.entries)
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
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(border: Border.all(color: Brand.border), borderRadius: BorderRadius.circular(12), color: Brand.surface),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _category,
                items: [
                  const DropdownMenuItem(value: '', child: Text('All types')),
                  for (final c in issueCategories) DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) {
                  _category = v ?? '';
                  _page = 1;
                  _load();
                },
              ),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        if (_error != null)
          ErrorBox(error: _error!, onRetry: _load)
        else if (data == null)
          const Loading()
        else if (data.page.items.isEmpty)
          Panel(
            child: EmptyState(
              icon: _status == 'open' ? Icons.check_circle_outline_rounded : Icons.inbox_rounded,
              title: _status == 'open' ? 'No open reports' : 'Nothing here',
              message: _status == 'open' ? 'New resident reports appear here.' : null,
            ),
          )
        else ...[
          ResponsiveGrid(
            minWidth: 360,
            maxColumns: 3,
            children: [
              for (final r in data.page.items)
                _IssueCard(r: r, busy: _busy.contains(r['_id']), onMove: (next) => _move(r, next)),
            ],
          ),
          Pager(
            page: data.page.page,
            pages: data.page.pages,
            total: data.page.total,
            limit: data.page.limit,
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

class _IssueCard extends StatelessWidget {
  const _IssueCard({required this.r, required this.busy, required this.onMove});
  final Json r;
  final bool busy;
  final ValueChanged<String> onMove;

  @override
  Widget build(BuildContext context) {
    final status = r['status'] as String? ?? 'submitted';
    final category = r['category'] as String? ?? '';
    final photos = List<String>.from(r['photos'] as List? ?? const []);
    final reporter = Json.from(r['reporter'] as Map? ?? const {});
    final flags = List<String>.from(r['flags'] as List? ?? const []);
    final history = List<Json>.from((r['history'] as List? ?? const []).map((e) => Json.from(e as Map)));
    final loc = Json.from(r['location'] as Map? ?? const {});
    final confirmations = (r['confirmations'] as num?)?.toInt() ?? 0;
    final coords = '${(loc['lat'] as num?)?.toStringAsFixed(5)}, ${(loc['lng'] as num?)?.toStringAsFixed(5)}';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(fit: StackFit.expand, children: [
            if (photos.isNotEmpty)
              Image.network(photos.first, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: Brand.canvas))
            else
              Container(color: Brand.canvas),
            Positioned(
              left: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.94), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(issueIcon(category), size: 14, color: Brand.ink),
                  const SizedBox(width: 5),
                  Text(category, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: issueStatusColor(status), borderRadius: BorderRadius.circular(20)),
                child: Text(r['statusLabel'] as String? ?? status,
                    style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
              ),
            ),
            if (photos.length > 1)
              Positioned(
                right: 10,
                bottom: 10,
                child: StatusPill('+${photos.length - 1} photos', color: Colors.white),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((r['landmark'] as String?)?.isNotEmpty == true ? r['landmark'] as String : 'Location pinned by GPS',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
            const SizedBox(height: 2),
            Row(children: [
              Text('${r['emirate'] ?? ''} · ', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: coords));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coordinates copied')));
                },
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(coords, style: const TextStyle(color: Brand.sky, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 3),
                  const Icon(Icons.copy_rounded, size: 12, color: Brand.sky),
                ]),
              ),
            ]),
            if ((r['description'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Text(r['description'] as String, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(height: 1.45)),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Avatar(name: reporter['name'] as String? ?? '', url: reporter['profileImage'] as String?, size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${reporter['name'] ?? 'Resident'} · ${Fmt.ago(r['createdAt'])}',
                    overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
              if (confirmations > 0)
                Tooltip(
                  message: 'Other residents reported seeing this too',
                  child: StatusPill('+$confirmations confirm', color: Brand.sky),
                ),
            ]),
            if (flags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final f in flags)
                  StatusPill(
                    switch (f) {
                      'duplicate_nearby' => 'Possible duplicate nearby',
                      'duplicate_photo' => 'Photo used before',
                      'low_gps_accuracy' => 'Weak GPS',
                      _ => f,
                    },
                    color: Brand.danger,
                  ),
              ]),
            ],
            const SizedBox(height: 12),
            _Timeline(history: history),
            if ((r['forwardedTo'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text('Shared with: ${r['forwardedTo']}', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
            ],
            const SizedBox(height: 14),
            _Actions(status: status, busy: busy, onMove: onMove),
          ]),
        ),
      ]),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.history});
  final List<Json> history;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (var i = 0; i < history.length; i++)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(color: issueStatusColor(history[i]['status'] as String? ?? ''), shape: BoxShape.circle),
            ),
            if (i < history.length - 1) Container(width: 2, height: 26, color: Brand.border),
          ]),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: '${history[i]['label'] ?? history[i]['status']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                TextSpan(
                  text: '  ${Fmt.date(history[i]['at'])}${history[i]['by'] != null ? ' · ${history[i]['by']}' : ''}',
                  style: const TextStyle(color: Brand.muted, fontSize: 12),
                ),
                if ((history[i]['note'] as String?)?.isNotEmpty == true)
                  TextSpan(text: '\n${history[i]['note']}', style: const TextStyle(fontSize: 12.5, color: Brand.ink)),
              ])),
            ),
          ),
        ]),
    ]);
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.status, required this.busy, required this.onMove});
  final String status;
  final bool busy;
  final ValueChanged<String> onMove;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      if (status == 'submitted' || status == 'rejected')
        OutlinedButton(onPressed: busy ? null : () => onMove('under_review'), child: Text(status == 'rejected' ? 'Reopen' : 'Start review')),
      if (status == 'submitted' || status == 'under_review')
        OutlinedButton(onPressed: busy ? null : () => onMove('forwarded'), child: const Text('Share with partner')),
      if (status == 'submitted' || status == 'under_review' || status == 'forwarded')
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Brand.eco, minimumSize: const Size(64, 40)),
          onPressed: busy ? null : () => onMove('resolved'),
          child: const Text('Resolve'),
        ),
      if (status == 'submitted' || status == 'under_review' || status == 'forwarded')
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Brand.danger),
          onPressed: busy ? null : () => onMove('rejected'),
          child: const Text('Close'),
        ),
    ];
    if (buttons.isEmpty) {
      return const Text('No further action needed.', style: TextStyle(color: Brand.muted, fontSize: 12.5));
    }
    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }
}

class _ActionDialog extends StatefulWidget {
  const _ActionDialog({required this.next});
  final String next;

  @override
  State<_ActionDialog> createState() => _ActionDialogState();
}

class _ActionDialogState extends State<_ActionDialog> {
  final _note = TextEditingController();
  final _to = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    _to.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final forward = widget.next == 'forwarded';
    final resolve = widget.next == 'resolved';
    return AlertDialog(
      title: Text(forward ? 'Share with a partner' : resolve ? 'Mark as resolved' : 'Close report'),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            forward
                ? 'Record who you actually shared this with. The reporter sees this name, so only enter a partner you have contacted.'
                : resolve
                    ? 'Describe how it was confirmed resolved. The reporter sees this note and earns 15 Eco Points.'
                    : 'Tell the reporter why it was closed.',
            style: const TextStyle(height: 1.45),
          ),
          const SizedBox(height: 14),
          if (forward) ...[
            TextField(controller: _to, decoration: const InputDecoration(labelText: 'Partner or authority')),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _note,
            maxLength: 500,
            maxLines: 2,
            decoration: InputDecoration(labelText: forward ? 'Note (optional)' : 'Note for the reporter'),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: resolve ? Brand.eco : forward ? Brand.sky : Brand.danger),
          onPressed: () {
            if (forward && _to.text.trim().isEmpty) return;
            if (!forward && _note.text.trim().length < 3) return;
            Navigator.pop(context, (note: _note.text.trim(), to: _to.text.trim()));
          },
          child: Text(forward ? 'Record as shared' : resolve ? 'Resolve' : 'Close report'),
        ),
      ],
    );
  }
}
