import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/admin_api.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  String? _text;
  String _mode = '';
  String? _running;
  Object? _error;
  int _days = 30;

  Future<void> _run(String kind) async {
    setState(() {
      _running = kind;
      _error = null;
    });
    try {
      final r = await Session.instance.api.insights(kind, days: _days);
      if (mounted) {
        setState(() {
          _text = r.text;
          _mode = r.mode;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _running = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader(
        title: 'AI insights',
        subtitle: 'Reports and summaries written from your live, verified data',
      ),
      ResponsiveGrid(minWidth: 340, maxColumns: 2, children: [
        _ActionCard(
          icon: Icons.description_rounded,
          color: Brand.eco,
          title: 'Draft impact report',
          text: 'A sponsor-ready summary of verified outcomes, tree survival, community reports and rewards.',
          busy: _running == 'impact_report',
          extra: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 7, label: Text('7 days')),
              ButtonSegment(value: 30, label: Text('30 days')),
              ButtonSegment(value: 90, label: Text('90 days')),
            ],
            selected: {_days},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _days = s.first),
          ),
          onRun: _running == null ? () => _run('impact_report') : null,
        ),
        _ActionCard(
          icon: Icons.fact_check_rounded,
          color: Brand.coral,
          title: 'Summarise verification queue',
          text: 'Which field reports look risky, which passed every check, and what to review first.',
          busy: _running == 'verification_queue',
          onRun: _running == null ? () => _run('verification_queue') : null,
        ),
      ]),
      const SizedBox(height: 16),
      if (_error != null) ErrorBox(error: _error!, onRetry: () => _run('impact_report')),
      if (_text != null)
        Panel(
          title: 'Result',
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            StatusPill(_mode == 'ai' ? 'Written by AI' : 'Generated from template', color: _mode == 'ai' ? Brand.eco : Brand.muted),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _text!));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied. Paste into an email or document.')));
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy'),
            ),
          ]),
          child: SelectionArea(child: _MarkdownLite(_text!)),
        ),
      if (_text == null && _error == null)
        const Panel(
          child: EmptyState(
            icon: Icons.auto_awesome_rounded,
            title: 'Pick an action above',
            message: 'Every figure comes from approved, verified records. Nothing is invented.',
          ),
        ),
    ]);
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
    required this.busy,
    required this.onRun,
    this.extra,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String text;
  final bool busy;
  final VoidCallback? onRun;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
        ]),
        const SizedBox(height: 10),
        Text(text, style: const TextStyle(color: Brand.muted, height: 1.45)),
        if (extra != null) ...[const SizedBox(height: 12), extra!],
        const SizedBox(height: 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: color),
          onPressed: onRun,
          icon: busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.auto_awesome_rounded, size: 18),
          label: Text(busy ? 'Working…' : 'Generate'),
        ),
      ]),
    );
  }
}

/// Renders the small markdown subset the reports use: headings, bullets, italics lines.
class _MarkdownLite extends StatelessWidget {
  const _MarkdownLite(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final widgets = <Widget>[];
    for (final raw in text.split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
      } else if (line.startsWith('# ')) {
        widgets.add(Text(line.substring(2), style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)));
      } else if (line.startsWith('## ') || line.startsWith('### ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: Text(line.replaceFirst(RegExp(r'^#+ '), ''),
              style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: Brand.coral)),
        ));
      } else if (RegExp(r'^\s*[-*] ').hasMatch(line)) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.only(top: 7), child: Icon(Icons.circle, size: 6, color: Brand.eco)),
            const SizedBox(width: 10),
            Expanded(child: Text(_clean(line.replaceFirst(RegExp(r'^\s*[-*] '), '')), style: const TextStyle(height: 1.5))),
          ]),
        ));
      } else if (line.startsWith('_') && line.endsWith('_')) {
        widgets.add(Text(line.substring(1, line.length - 1),
            style: const TextStyle(color: Brand.muted, fontStyle: FontStyle.italic, height: 1.5)));
      } else {
        widgets.add(Text(_clean(line), style: const TextStyle(height: 1.55)));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  static String _clean(String s) => s.replaceAll('**', '');
}
