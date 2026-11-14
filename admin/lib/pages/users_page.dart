import 'dart:async';

import 'package:flutter/material.dart';

import '../api/admin_api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

const emirates = ['Abu Dhabi', 'Dubai', 'Sharjah', 'Ajman', 'Umm Al Quwain', 'Ras Al Khaimah', 'Fujairah'];

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _status = 'all';
  String _emirate = '';
  String _sort = 'recent';
  int _page = 1;
  Paged? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await Session.instance.api.users(
        q: _search.text.trim(),
        status: _status,
        emirate: _emirate,
        sort: _sort,
        page: _page,
      );
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _page = 1;
      _load();
    });
  }

  Future<void> _open(Json user) async {
    final changed = await showDialog<bool>(context: context, builder: (_) => _UserDialog(id: user['_id'] as String));
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Users',
          subtitle: data == null ? 'Community members' : '${Fmt.number(data.total)} members match these filters',
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 300,
                    child: TextField(
                      controller: _search,
                      onChanged: _onSearch,
                      decoration: const InputDecoration(
                        hintText: 'Search name, email or phone',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'all', label: Text('All')),
                      ButtonSegment(value: 'active', label: Text('Active')),
                      ButtonSegment(value: 'suspended', label: Text('Suspended')),
                      ButtonSegment(value: 'verifiers', label: Text('Verifiers')),
                      ButtonSegment(value: 'residents', label: Text('UAE PASS')),
                      ButtonSegment(value: 'admins', label: Text('Admins')),
                    ],
                    selected: {_status},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) {
                      _status = s.first;
                      _page = 1;
                      _load();
                    },
                  ),
                  _Dropdown(
                    value: _emirate,
                    items: {'': 'All emirates', for (final e in emirates) e: e},
                    onChanged: (v) {
                      _emirate = v;
                      _page = 1;
                      _load();
                    },
                  ),
                  _Dropdown(
                    value: _sort,
                    items: const {'recent': 'Newest first', 'points': 'Most Eco Points'},
                    onChanged: (v) {
                      _sort = v;
                      _page = 1;
                      _load();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_error != null)
                ErrorBox(error: _error!, onRetry: _load)
              else if (data == null)
                const Loading()
              else if (data.items.isEmpty)
                const EmptyState(icon: Icons.person_search_rounded, title: 'No users found', message: 'Try a different search or filter.')
              else
                AnimatedOpacity(
                  opacity: _loading ? 0.5 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: Column(children: [
                    const _HeaderRow(),
                    for (final u in data.items) _UserRow(user: u, onTap: () => _open(u)),
                  ]),
                ),
              if (data != null && data.total > 0)
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
          ),
        ),
      ],
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({required this.value, required this.items, required this.onChanged});
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(border: Border.all(color: Brand.border), borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          borderRadius: BorderRadius.circular(12),
          items: [for (final e in items.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) => onChanged(v ?? ''),
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: Brand.muted, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.4);
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Brand.border))),
      child: Row(children: [
        const Expanded(flex: 4, child: Text('MEMBER', style: style)),
        if (wide) const Expanded(flex: 2, child: Text('EMIRATE', style: style)),
        const Expanded(flex: 2, child: Text('ECO POINTS', style: style)),
        if (wide) const Expanded(flex: 2, child: Text('JOINED', style: style)),
        const Expanded(flex: 2, child: Text('STATUS', style: style)),
      ]),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user, required this.onTap});
  final Json user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final name = (user['name'] as String?)?.isNotEmpty == true ? user['name'] as String : 'Unnamed';
    final contact = (user['email'] as String?)?.isNotEmpty == true ? user['email'] as String : (user['phone'] as String? ?? '');
    final suspended = user['isSuspended'] == true;
    final admin = user['role'] == 'admin';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Brand.border))),
        child: Row(children: [
          Expanded(
            flex: 4,
            child: Row(children: [
              Avatar(name: name, url: user['profileImage'] as String?),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(contact, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Brand.muted, fontSize: 12)),
                ]),
              ),
            ]),
          ),
          if (wide)
            Expanded(
              flex: 2,
              child: Text((user['emirate'] as String?)?.isNotEmpty == true ? user['emirate'] as String : '—'),
            ),
          Expanded(flex: 2, child: Text(Fmt.number(user['ecoPoints'] as num?), style: const TextStyle(fontWeight: FontWeight.w700))),
          if (wide) Expanded(flex: 2, child: Text(Fmt.date(user['createdAt']))),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: admin
                  ? const StatusPill('Admin', color: Brand.coral)
                  : user['role'] == 'verifier' && !suspended
                      ? const StatusPill('Verifier', color: Brand.sky)
                      : suspended
                      ? const StatusPill('Suspended', color: Brand.danger)
                      : const StatusPill('Active', color: Brand.eco),
            ),
          ),
        ]),
      ),
    );
  }
}

class _UserDialog extends StatefulWidget {
  const _UserDialog({required this.id});
  final String id;

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  late Future<Json> _future = Session.instance.api.user(widget.id);
  bool _busy = false;
  bool _changed = false;

  Future<void> _toggleVerifier(Json user, bool on) async {
    setState(() => _busy = true);
    try {
      await Session.instance.api.setRole(widget.id, on ? 'verifier' : 'user');
      _changed = true;
      setState(() => _future = Session.instance.api.user(widget.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(on ? 'Now an authorised field verifier' : 'Field verifier access removed')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(Json user) async {
    final suspend = user['isSuspended'] != true;
    String reason = '';
    if (suspend) {
      final result = await showDialog<String>(context: context, builder: (_) => const _ReasonDialog());
      if (result == null) return;
      reason = result;
    }
    setState(() => _busy = true);
    try {
      await Session.instance.api.setSuspended(widget.id, suspend, reason: reason);
      _changed = true;
      setState(() => _future = Session.instance.api.user(widget.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(suspend ? 'Account suspended' : 'Account restored')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: FutureBuilder<Json>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Loading();
            if (snap.hasError) {
              return Padding(padding: const EdgeInsets.all(24), child: Text(snap.error.toString()));
            }
            final u = snap.data!;
            final stats = Json.from(u['stats'] as Map? ?? const {});
            final name = (u['name'] as String?)?.isNotEmpty == true ? u['name'] as String : 'Unnamed';
            final suspended = u['isSuspended'] == true;
            final admin = u['role'] == 'admin';
            final t = Theme.of(context).textTheme;
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Avatar(name: name, url: u['profileImage'] as String?, size: 56),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        Text([u['email'], u['phone']].where((v) => (v as String?)?.isNotEmpty == true).join(' · '),
                            style: const TextStyle(color: Brand.muted)),
                      ]),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(_changed),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ]),
                  if ((u['bio'] as String?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 14),
                    Text(u['bio'] as String, style: const TextStyle(height: 1.5)),
                  ],
                  const SizedBox(height: 20),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    _Stat('Eco Points', Fmt.number(u['ecoPoints'] as num?)),
                    _Stat('Posts', Fmt.number(stats['posts'] as num?)),
                    _Stat('Verified', Fmt.number(stats['verified'] as num?)),
                    _Stat('Challenges', Fmt.number(stats['challenges'] as num?)),
                    _Stat('Friends', Fmt.number(u['friendsCount'] as num?)),
                    _Stat('Streak', '${u['streak'] ?? 0} days'),
                  ]),
                  const SizedBox(height: 16),
                  _Line('Emirate', (u['emirate'] as String?)?.isNotEmpty == true ? u['emirate'] as String : 'Not set'),
                  _Line('Joined', Fmt.date(u['createdAt'])),
                  _Line('Level', '${u['level'] ?? 1}'),
                  if (suspended && (u['suspendedReason'] as String?)?.isNotEmpty == true)
                    _Line('Suspension reason', u['suspendedReason'] as String),
                  if (!admin) ...[
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(color: Brand.canvas, borderRadius: BorderRadius.circular(12)),
                      child: SwitchListTile(
                        value: u['role'] == 'verifier',
                        onChanged: _busy || suspended ? null : (on) => _toggleVerifier(u, on),
                        title: const Text('Field verifier', style: TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: const Text('Can be assigned to campaigns and submit on-site evidence'),
                        secondary: const Icon(Icons.verified_user_rounded, color: Brand.sky),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (admin)
                    const Text('Admin accounts are managed with the make-admin script.', style: TextStyle(color: Brand.muted))
                  else
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: suspended ? Brand.eco : Brand.danger),
                      onPressed: _busy ? null : () => _toggle(u),
                      icon: Icon(suspended ? Icons.lock_open_rounded : Icons.block_rounded),
                      label: Text(suspended ? 'Restore account' : 'Suspend account'),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Brand.canvas, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        Text(label, style: const TextStyle(color: Brand.muted, fontSize: 12)),
      ]),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(width: 150, child: Text(label, style: const TextStyle(color: Brand.muted))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Suspend this account?'),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('They will be signed out of the app and hidden from the leaderboard. You can restore them any time.'),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Reason (internal)'),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Brand.danger),
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: const Text('Suspend'),
        ),
      ],
    );
  }
}
