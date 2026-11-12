import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../api/admin_api.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

const rewardCategories = ['voucher', 'experience', 'donation', 'transport', 'merch'];

class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  List<Json>? _rewards;
  Json _stats = {};
  List<Json>? _redemptions;
  Object? _error;
  String _status = 'issued';
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Session.instance.api.rewards();
      final red = await Session.instance.api.redemptions(status: _status, code: _code.text.trim());
      if (!mounted) return;
      setState(() {
        _rewards = List<Json>.from((r['rewards'] as List? ?? const []).map((e) => Json.from(e as Map)));
        _stats = Json.from(r['stats'] as Map? ?? {});
        _redemptions = red;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _edit([Json? reward]) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => _RewardDialog(reward: reward));
    if (ok == true) _load();
  }

  Future<void> _setRedemption(Json r, String status) async {
    try {
      await Session.instance.api.updateRedemption(r['_id'] as String, status);
      _snack(status == 'used' ? 'Marked as used' : 'Cancelled and points refunded');
      _load();
    } on ApiError catch (e) {
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rewards = _rewards;
    final active = rewards?.where((r) => r['isActive'] != false).length ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Rewards',
        subtitle: 'What members can spend their Eco Points on, and the codes they hold',
        actions: [FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add_rounded), label: const Text('New reward'))],
      ),
      if (_error != null)
        ErrorBox(error: _error!, onRetry: _load)
      else if (rewards == null)
        const Loading()
      else ...[
        ResponsiveGrid(minWidth: 220, maxColumns: 4, children: [
          KpiCard(label: 'Rewards live', value: '$active', icon: Icons.redeem_rounded, color: Brand.coral),
          KpiCard(label: 'Codes issued', value: '${_stats['issued'] ?? 0}', icon: Icons.confirmation_number_rounded, color: Brand.sky),
          KpiCard(label: 'Points redeemed', value: NumberFormat.decimalPattern().format(_stats['pointsRedeemed'] ?? 0), icon: Icons.stars_rounded, color: Brand.sun),
          KpiCard(
            label: 'Partners',
            value: '${rewards.map((r) => r['partner']).where((p) => (p as String?)?.isNotEmpty == true).toSet().length}',
            icon: Icons.handshake_rounded,
            color: Brand.eco,
          ),
        ]),
        const SizedBox(height: 16),
        Panel(
          title: 'Catalogue',
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: rewards.isEmpty
              ? const EmptyState(icon: Icons.redeem_rounded, title: 'No rewards yet', message: 'Add a voucher or experience to get started.')
              : Column(children: [
                  for (final r in rewards)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Brand.border))),
                      child: Row(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 64,
                            height: 44,
                            child: (r['image'] as String? ?? '').isEmpty
                                ? Container(color: Brand.blush, child: const Icon(Icons.redeem_rounded, color: Brand.coral))
                                : Image.network(r['image'] as String, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: Brand.blush)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(r['title'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text(
                              [r['partner'], r['category'], r['stock'] == null ? 'Unlimited' : '${r['stock']} in stock', '${r['redeemedCount'] ?? 0} redeemed']
                                  .where((v) => v != null && '$v'.isNotEmpty)
                                  .join(' · '),
                              style: const TextStyle(color: Brand.muted, fontSize: 12.5),
                            ),
                          ]),
                        ),
                        StatusPill('${r['cost']} pts', color: Brand.sun),
                        const SizedBox(width: 8),
                        Switch(
                          value: r['isActive'] != false,
                          onChanged: (v) async {
                            await Session.instance.api.updateReward(r['_id'] as String, {'isActive': v});
                            _load();
                          },
                        ),
                        IconButton(tooltip: 'Edit', onPressed: () => _edit(r), icon: const Icon(Icons.edit_rounded)),
                      ]),
                    ),
                ]),
        ),
        const SizedBox(height: 16),
        Panel(
          title: 'Redemption codes',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 6, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(
              width: 180,
              child: TextField(
                controller: _code,
                decoration: const InputDecoration(isDense: true, hintText: 'Find code', prefixIcon: Icon(Icons.search_rounded, size: 18)),
                onSubmitted: (_) => _load(),
              ),
            ),
            const SizedBox(width: 8),
            for (final s in ['issued', 'used', 'cancelled'])
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: ChoiceChip(
                  label: Text(s),
                  selected: _status == s,
                  onSelected: (_) {
                    setState(() => _status = s);
                    _load();
                  },
                ),
              ),
          ]),
            const SizedBox(height: 8),
            if ((_redemptions ?? []).isEmpty)
              const EmptyState(icon: Icons.confirmation_number_outlined, title: 'No codes in this view')
            else
              Column(children: [
                  for (final r in _redemptions!)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Brand.border))),
                      child: Row(children: [
                        Avatar(url: (r['user'] as Map?)?['profileImage'] as String?, name: (r['user'] as Map?)?['name'] as String? ?? '?'),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${(r['user'] as Map?)?['name'] ?? 'Member'} · ${r['rewardTitle']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(
                              '${r['cost']} pts · ${DateFormat('d MMM, h:mm a').format(DateTime.tryParse(r['createdAt'] as String? ?? '')?.toLocal() ?? DateTime.now())}',
                              style: const TextStyle(color: Brand.muted, fontSize: 12.5),
                            ),
                          ]),
                        ),
                        SelectableText(r['code'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                        IconButton(
                          tooltip: 'Copy',
                          onPressed: () => Clipboard.setData(ClipboardData(text: r['code'] as String? ?? '')),
                          icon: const Icon(Icons.copy_rounded, size: 18),
                        ),
                        if (r['status'] == 'issued') ...[
                          TextButton(onPressed: () => _setRedemption(r, 'used'), child: const Text('Mark used')),
                          TextButton(
                            style: TextButton.styleFrom(foregroundColor: Brand.danger),
                            onPressed: () => _setRedemption(r, 'cancelled'),
                            child: const Text('Cancel & refund'),
                          ),
                        ] else
                          StatusPill(r['status'] as String? ?? '', color: r['status'] == 'used' ? Brand.eco : Brand.danger),
                      ]),
                    ),
                ]),
          ]),
        ),
      ],
    ]);
  }
}

class _RewardDialog extends StatefulWidget {
  const _RewardDialog({this.reward});
  final Json? reward;

  @override
  State<_RewardDialog> createState() => _RewardDialogState();
}

class _RewardDialogState extends State<_RewardDialog> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.reward?['title'] as String? ?? '');
  late final _partner = TextEditingController(text: widget.reward?['partner'] as String? ?? '');
  late final _desc = TextEditingController(text: widget.reward?['description'] as String? ?? '');
  late final _terms = TextEditingController(text: widget.reward?['terms'] as String? ?? '');
  late final _image = TextEditingController(text: widget.reward?['image'] as String? ?? '');
  late final _cost = TextEditingController(text: '${widget.reward?['cost'] ?? 200}');
  late final _stock = TextEditingController(text: widget.reward?['stock'] == null ? '' : '${widget.reward!['stock']}');
  late String _category = widget.reward?['category'] as String? ?? 'voucher';
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = {
      'title': _title.text.trim(),
      'partner': _partner.text.trim(),
      'description': _desc.text.trim(),
      'terms': _terms.text.trim(),
      'image': _image.text.trim(),
      'category': _category,
      'cost': int.tryParse(_cost.text.trim()) ?? 0,
      'stock': _stock.text.trim().isEmpty ? null : int.tryParse(_stock.text.trim()),
    };
    try {
      final id = widget.reward?['_id'] as String?;
      id == null ? await Session.instance.api.createReward(body) : await Session.instance.api.updateReward(id, body);
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
    return AlertDialog(
      title: Text(widget.reward == null ? 'New reward' : 'Edit reward'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'Title'), validator: (v) => (v ?? '').trim().length < 3 ? 'Required' : null),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _partner, decoration: const InputDecoration(labelText: 'Partner'))),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [for (final c in rewardCategories) DropdownMenuItem(value: c, child: Text(c))],
                    onChanged: (v) => setState(() => _category = v ?? _category),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _cost,
                    inputFormatters: digits,
                    decoration: const InputDecoration(labelText: 'Cost (Eco Points)'),
                    validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1 ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _stock, inputFormatters: digits, decoration: const InputDecoration(labelText: 'Stock', helperText: 'Empty = unlimited'))),
              ]),
              const SizedBox(height: 12),
              TextFormField(controller: _desc, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
              const SizedBox(height: 12),
              TextFormField(controller: _terms, maxLines: 2, decoration: const InputDecoration(labelText: 'Terms')),
              const SizedBox(height: 12),
              TextFormField(controller: _image, decoration: const InputDecoration(labelText: 'Image URL')),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Brand.danger))),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save')),
      ],
    );
  }
}
