import 'package:flutter/material.dart';

import '../api/admin_api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

const _typeLabels = {
  'campaign_verified': 'Campaign verified',
  'post_verified': 'Post verified',
  'challenge_won': 'Challenge won',
  'report_resolved': 'Report resolved',
  'reversal': 'Reversal',
  'adjustment': 'Adjustment',
};

Color _typeColor(String t) => switch (t) {
      'campaign_verified' => Brand.eco,
      'post_verified' => Brand.sky,
      'challenge_won' => Brand.sun,
      'report_resolved' => Brand.coral,
      'reversal' => Brand.danger,
      _ => Brand.muted,
    };

class PointsPage extends StatefulWidget {
  const PointsPage({super.key});

  @override
  State<PointsPage> createState() => _PointsPageState();
}

class _PointsPageState extends State<PointsPage> {
  String _type = '';
  int _page = 1;
  ({Paged page, int credited, int reversed})? _data;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await Session.instance.api.transactions(type: _type, page: _page);
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _reverse(Json t) async {
    final reason = await showDialog<String>(context: context, builder: (_) => _ReverseDialog(tx: t));
    if (reason == null) return;
    try {
      await Session.instance.api.reverseTransaction(t['_id'] as String, reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reversed ${Fmt.number(t['amount'] as num?)} points. A reversal entry was added to the ledger.')),
      );
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(
          title: 'Eco Points ledger',
          subtitle: 'Every credit and reversal, with who triggered it and why',
        ),
        if (data != null) ...[
          ResponsiveGrid(maxColumns: 3, minWidth: 240, children: [
            KpiCard(label: 'Points credited', value: Fmt.compact(data.credited), icon: Icons.add_circle_rounded, color: Brand.eco),
            KpiCard(label: 'Points reversed', value: Fmt.compact(data.reversed), icon: Icons.undo_rounded, color: Brand.danger),
            KpiCard(label: 'Net in circulation', value: Fmt.compact(data.credited - data.reversed), icon: Icons.account_balance_wallet_rounded, color: Brand.sun),
          ]),
          const SizedBox(height: 16),
        ],
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in {'': 'All', ..._typeLabels}.entries)
            ChoiceChip(
              label: Text(e.value),
              selected: _type == e.key,
              onSelected: (_) {
                setState(() {
                  _type = e.key;
                  _page = 1;
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
        else if (data.page.items.isEmpty)
          const Panel(child: EmptyState(icon: Icons.receipt_long_rounded, title: 'No transactions yet'))
        else
          Panel(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(children: [
              for (final t in data.page.items) _TxRow(t: t, onReverse: () => _reverse(t)),
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
            ]),
          ),
      ],
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({required this.t, required this.onReverse});
  final Json t;
  final VoidCallback onReverse;

  @override
  Widget build(BuildContext context) {
    final user = Json.from(t['user'] as Map? ?? const {});
    final type = t['type'] as String? ?? '';
    final amount = (t['amount'] as num?) ?? 0;
    final reversed = t['status'] == 'reversed';
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final by = (t['createdBy'] as Map?)?['name'] as String?;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Brand.border))),
      child: Row(children: [
        Avatar(name: user['name'] as String? ?? '', url: user['profileImage'] as String?),
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user['name'] as String? ?? 'Unknown user', style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
            Text(t['reason'] as String? ?? '', style: const TextStyle(color: Brand.muted, fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        if (wide)
          Expanded(
            flex: 2,
            child: Align(alignment: Alignment.centerLeft, child: StatusPill(_typeLabels[type] ?? type, color: _typeColor(type))),
          ),
        if (wide)
          Expanded(
            flex: 2,
            child: Text(by == null ? 'System' : 'by $by', style: const TextStyle(color: Brand.muted, fontSize: 12.5), overflow: TextOverflow.ellipsis),
          ),
        SizedBox(
          width: 90,
          child: Text(Fmt.date(t['createdAt']), style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
        ),
        SizedBox(
          width: 80,
          child: Text(
            '${amount > 0 ? '+' : ''}${Fmt.number(amount)}',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: amount < 0 ? Brand.danger : Brand.eco,
              decoration: reversed ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
        SizedBox(
          width: 48,
          child: amount > 0 && !reversed
              ? IconButton(tooltip: 'Reverse', onPressed: onReverse, icon: const Icon(Icons.undo_rounded, size: 20))
              : reversed
                  ? const Tooltip(message: 'Reversed', child: Icon(Icons.block_rounded, size: 18, color: Brand.muted))
                  : const SizedBox.shrink(),
        ),
      ]),
    );
  }
}

class _ReverseDialog extends StatefulWidget {
  const _ReverseDialog({required this.tx});
  final Json tx;

  @override
  State<_ReverseDialog> createState() => _ReverseDialogState();
}

class _ReverseDialogState extends State<_ReverseDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = (widget.tx['user'] as Map?)?['name'] ?? 'this user';
    return AlertDialog(
      title: const Text('Reverse Eco Points?'),
      content: SizedBox(
        width: 400,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${Fmt.number(widget.tx['amount'] as num?)} points will be removed from $user. '
              'The original entry stays in the ledger and a reversal entry is added with your name.'),
          const SizedBox(height: 14),
          TextField(controller: _ctrl, maxLength: 300, decoration: const InputDecoration(labelText: 'Reason (required)')),
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
          child: const Text('Reverse'),
        ),
      ],
    );
  }
}
