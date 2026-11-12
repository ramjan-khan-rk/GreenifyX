import 'package:flutter/material.dart';

import '../api/admin_api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});

  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> {
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
      final data = await Session.instance.api.challenges(status: _status, page: _page);
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(title: 'Challenges', subtitle: 'Friend-to-friend eco challenges across the community'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in const {'': 'All', 'ongoing': 'Ongoing', 'pending': 'Pending', 'completed': 'Completed', 'expired': 'Expired'}.entries)
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
          const Panel(child: EmptyState(icon: Icons.emoji_events_outlined, title: 'No challenges here'))
        else ...[
          ResponsiveGrid(
            minWidth: 340,
            maxColumns: 3,
            children: [for (final c in data.items) _ChallengeCard(c)],
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

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard(this.c);
  final Json c;

  String _name(dynamic u) => u is Map && (u['name'] as String?)?.isNotEmpty == true ? u['name'] as String : 'Unknown';

  @override
  Widget build(BuildContext context) {
    final status = c['status'] as String? ?? '';
    final target = (c['target'] as num?)?.toDouble() ?? 1;
    final winner = c['winner'];
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(c['title'] as String? ?? '',
                overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          StatusPill(status.isEmpty ? '—' : '${status[0].toUpperCase()}${status.substring(1)}', color: statusColor(status)),
        ]),
        const SizedBox(height: 6),
        Text('${c['activity']} · ${c['difficulty']} · ${Fmt.number(c['ecoReward'] as num?)} pts reward',
            style: const TextStyle(color: Brand.muted, fontSize: 13)),
        const SizedBox(height: 16),
        _Progress(name: _name(c['creator']), value: (c['creatorProgress'] as num?)?.toDouble() ?? 0, target: target, color: Brand.coral),
        const SizedBox(height: 10),
        _Progress(name: _name(c['friend']), value: (c['friendProgress'] as num?)?.toDouble() ?? 0, target: target, color: Brand.sky),
        const SizedBox(height: 14),
        Row(children: [
          const Icon(Icons.event_rounded, size: 16, color: Brand.muted),
          const SizedBox(width: 6),
          Text('Deadline ${Fmt.date(c['deadline'])}', style: const TextStyle(color: Brand.muted, fontSize: 13)),
          const Spacer(),
          if (winner is Map) ...[
            const Icon(Icons.emoji_events_rounded, size: 16, color: Brand.sun),
            const SizedBox(width: 4),
            Text(_name(winner), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ]),
      ]),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.name, required this.value, required this.target, required this.color});
  final String name;
  final double value;
  final double target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        Text('${value.toInt()} / ${target.toInt()}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: target == 0 ? 0 : (value / target).clamp(0, 1),
          minHeight: 8,
          backgroundColor: Brand.canvas,
          color: color,
        ),
      ),
    ]);
  }
}
