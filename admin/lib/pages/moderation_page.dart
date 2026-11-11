import 'package:flutter/material.dart';

import '../api/admin_api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class ModerationPage extends StatefulWidget {
  const ModerationPage({super.key});

  @override
  State<ModerationPage> createState() => _ModerationPageState();
}

class _ModerationPageState extends State<ModerationPage> {
  String _filter = 'reported';
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
      final data = await Session.instance.api.posts(filter: _filter, page: _page, limit: 12);
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _act(Json post, String action) async {
    final id = post['_id'] as String;
    setState(() => _busy.add(id));
    try {
      await Session.instance.api.moderate(id, action);
      if (!mounted) return;
      final msg = {'hide': 'Post hidden from the app', 'restore': 'Post restored', 'dismiss': 'Reports dismissed'}[action]!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
          title: 'Moderation',
          subtitle: 'Review reported posts and keep the community trustworthy',
        ),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final f in const {
            'reported': 'Reported',
            'hidden': 'Hidden',
            'unverified': 'Awaiting verification',
            'all': 'All posts',
          }.entries)
            ChoiceChip(
              label: Text(f.value),
              selected: _filter == f.key,
              onSelected: (_) {
                setState(() {
                  _filter = f.key;
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
              icon: _filter == 'reported' ? Icons.verified_user_rounded : Icons.inbox_rounded,
              title: _filter == 'reported' ? 'All clear' : 'Nothing here',
              message: _filter == 'reported' ? 'No posts are waiting for review.' : null,
            ),
          )
        else ...[
          ResponsiveGrid(
            minWidth: 300,
            maxColumns: 3,
            children: [
              for (final p in data.items)
                _PostCard(post: p, busy: _busy.contains(p['_id']), onAction: (a) => _act(p, a)),
            ],
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

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.busy, required this.onAction});
  final Json post;
  final bool busy;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final user = post['user'] is Map ? Json.from(post['user'] as Map) : const <String, dynamic>{};
    final name = (user['name'] as String?)?.isNotEmpty == true ? user['name'] as String : 'Unknown';
    final hidden = post['isHidden'] == true;
    final reports = List<Json>.from((post['reports'] as List? ?? const []).map((e) => Json.from(e as Map)));
    final isVideo = post['mediaType'] == 'video';
    final reasons = <String, int>{};
    for (final r in reports) {
      final key = (r['reason'] as String?)?.isNotEmpty == true ? r['reason'] as String : 'Other';
      reasons[key] = (reasons[key] ?? 0) + 1;
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(fit: StackFit.expand, children: [
              if (isVideo)
                Container(color: Brand.ink, child: const Icon(Icons.play_circle_rounded, color: Colors.white, size: 48))
              else
                Image.network(
                  post['image'] as String? ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: Brand.canvas,
                    child: const Icon(Icons.image_not_supported_outlined, color: Brand.muted),
                  ),
                ),
              Positioned(
                left: 10,
                top: 10,
                child: Wrap(spacing: 6, children: [
                  if (hidden) const _Badge('Hidden', Brand.ink),
                  if (reports.isNotEmpty) _Badge('${reports.length} report${reports.length == 1 ? '' : 's'}', Brand.danger),
                  if (post['isVerified'] == true) const _Badge('Verified', Brand.eco),
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Avatar(name: name, url: user['profileImage'] as String?, size: 28),
                const SizedBox(width: 8),
                Expanded(child: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                Text(Fmt.ago(post['createdAt']), style: const TextStyle(color: Brand.muted, fontSize: 12)),
              ]),
              const SizedBox(height: 10),
              Text(post['activity'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
              if ((post['description'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(post['description'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Brand.muted)),
              ],
              if (reasons.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final r in reasons.entries) StatusPill('${r.key} ×${r.value}', color: Brand.danger),
                ]),
              ],
              const SizedBox(height: 14),
              Row(children: [
                if (hidden)
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Brand.eco),
                      onPressed: busy ? null : () => onAction('restore'),
                      child: const Text('Restore'),
                    ),
                  )
                else ...[
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Brand.danger),
                      onPressed: busy ? null : () => onAction('hide'),
                      child: const Text('Hide'),
                    ),
                  ),
                  if (reports.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: busy ? null : () => onAction('dismiss'),
                        child: const Text('Keep'),
                      ),
                    ),
                  ],
                ],
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}
