import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../api/admin_api.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

Color _statusColor(String s) => switch (s) {
      'contacted' => Brand.sky,
      'converted' => Brand.eco,
      'closed' => Brand.muted,
      _ => Brand.coral,
    };

/// Leads from the public "GreenifyX for organisations" website.
class EnquiriesPage extends StatefulWidget {
  const EnquiriesPage({super.key});

  @override
  State<EnquiriesPage> createState() => _EnquiriesPageState();
}

class _EnquiriesPageState extends State<EnquiriesPage> {
  List<Json>? _items;
  Object? _error;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final items = await Session.instance.api.enquiries();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _set(Json e, String status) async {
    try {
      await Session.instance.api.updateEnquiry(e['_id'] as String, {'status': status});
      _load();
    } on ApiError catch (err) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final shown = items?.where((e) => _status.isEmpty || e['status'] == _status).toList();
    int count(String s) => items?.where((e) => e['status'] == s).length ?? 0;
    final siteUrl = '${Uri.base.origin}/#/for-organisations';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Website enquiries',
        subtitle: 'Organisations that asked for GreenifyX on the public website',
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: siteUrl));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied $siteUrl')));
            },
            icon: const Icon(Icons.link_rounded),
            label: const Text('Copy website link'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(onPressed: () => context.go('/for-organisations'), icon: const Icon(Icons.public_rounded), label: const Text('Open website')),
        ],
      ),
      ResponsiveGrid(minWidth: 200, maxColumns: 4, children: [
        KpiCard(label: 'New', value: '${count('new')}', icon: Icons.mark_email_unread_rounded, color: Brand.coral),
        KpiCard(label: 'Contacted', value: '${count('contacted')}', icon: Icons.call_made_rounded, color: Brand.sky),
        KpiCard(label: 'Converted', value: '${count('converted')}', icon: Icons.handshake_rounded, color: Brand.eco),
        KpiCard(label: 'Total', value: '${items?.length ?? 0}', icon: Icons.inbox_rounded, color: Brand.muted),
      ]),
      const SizedBox(height: 16),
      Wrap(spacing: 8, children: [
        for (final s in const ['', 'new', 'contacted', 'converted', 'closed'])
          ChoiceChip(label: Text(s.isEmpty ? 'All' : s), selected: _status == s, onSelected: (_) => setState(() => _status = s)),
      ]),
      const SizedBox(height: 16),
      if (_error != null)
        ErrorBox(error: _error!, onRetry: _load)
      else if (shown == null)
        const Loading()
      else if (shown.isEmpty)
        const Panel(child: EmptyState(icon: Icons.inbox_outlined, title: 'No enquiries yet', message: 'Share the website link with organisations you meet.'))
      else
        Panel(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(children: [
            for (final e in shown)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Brand.border))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Avatar(name: e['organisation'] as String? ?? '?'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${e['organisation']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text('${e['type']} · ${e['emirate']} · ${e['size']} people', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
                      const SizedBox(height: 6),
                      SelectableText('${e['contactName']} · ${e['email']}${(e['phone'] as String? ?? '').isEmpty ? '' : ' · ${e['phone']}'}'),
                      if ((e['interests'] as List?)?.isNotEmpty == true)
                        Text('Interested in: ${(e['interests'] as List).join(', ')}', style: const TextStyle(fontSize: 12.5)),
                      if ((e['message'] as String? ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('“${e['message']}”', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13)),
                        ),
                      Text(DateFormat('d MMM yyyy, h:mm a').format(DateTime.tryParse(e['createdAt'] as String? ?? '')?.toLocal() ?? DateTime.now()),
                          style: const TextStyle(color: Brand.muted, fontSize: 12)),
                    ]),
                  ),
                  StatusPill(e['status'] as String? ?? 'new', color: _statusColor(e['status'] as String? ?? 'new')),
                  PopupMenuButton<String>(
                    tooltip: 'Update status',
                    onSelected: (s) => _set(e, s),
                    itemBuilder: (_) => [
                      for (final s in const ['new', 'contacted', 'converted', 'closed']) PopupMenuItem(value: s, child: Text('Mark $s')),
                    ],
                  ),
                ]),
              ),
          ]),
        ),
    ]);
  }
}
