import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/session.dart';
import '../core/theme.dart';
import 'common.dart';

class NavItem {
  const NavItem(this.path, this.label, this.icon);
  final String path;
  final String label;
  final IconData icon;
}

const navItems = [
  NavItem('/', 'Overview', Icons.space_dashboard_rounded),
  NavItem('/campaigns', 'Campaigns', Icons.forest_rounded),
  NavItem('/verification', 'Verification', Icons.fact_check_rounded),
  NavItem('/impact', 'Impact', Icons.eco_rounded),
  NavItem('/points', 'Eco Points', Icons.account_balance_wallet_rounded),
  NavItem('/users', 'Users', Icons.people_alt_rounded),
  NavItem('/moderation', 'Moderation', Icons.shield_rounded),
  NavItem('/challenges', 'Challenges', Icons.emoji_events_rounded),
];

/// Sidebar on wide screens, drawer on narrow ones. Content scrolls independently.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final sidebar = _Sidebar(location: location, closeOnTap: !wide);

    return Scaffold(
      drawer: wide ? null : Drawer(width: 268, backgroundColor: Brand.ink, child: sidebar),
      appBar: wide
          ? null
          : AppBar(
              backgroundColor: Brand.ink,
              foregroundColor: Colors.white,
              title: const _Logo(),
            ),
      body: Row(
        children: [
          if (wide) SizedBox(width: 248, child: ColoredBox(color: Brand.ink, child: sidebar)),
          Expanded(
            child: SelectionArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(wide ? 32 : 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset('assets/brand/app_icon_rounded.png', width: 30, height: 30),
        ),
        const SizedBox(width: 10),
        const Text('GreenifyX', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: Brand.coral, borderRadius: BorderRadius.circular(6)),
          child: const Text('ADMIN', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
        ),
      ],
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.location, required this.closeOnTap});
  final String location;
  final bool closeOnTap;

  bool _active(String path) => path == '/' ? location == '/' : location.startsWith(path);

  @override
  Widget build(BuildContext context) {
    final session = Session.instance;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(padding: EdgeInsets.only(left: 8), child: _Logo()),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text('UAE pilot · Asia/Dubai',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12)),
            ),
            const SizedBox(height: 28),
            for (final item in navItems)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _NavTile(
                  item: item,
                  active: _active(item.path),
                  onTap: () {
                    if (closeOnTap) Navigator.of(context).pop();
                    context.go(item.path);
                  },
                ),
              ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Avatar(name: session.adminName, url: session.admin?['profileImage'] as String?, size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(session.adminName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        Text((session.admin?['email'] as String?) ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sign out',
                    onPressed: session.signOut,
                    icon: Icon(Icons.logout_rounded, color: Colors.white.withValues(alpha: 0.8), size: 20),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.active, required this.onTap});
  final NavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? Colors.white : Colors.white.withValues(alpha: 0.68);
    return Material(
      color: active ? Colors.white.withValues(alpha: 0.10) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(item.icon, size: 20, color: active ? Brand.sun : fg),
              const SizedBox(width: 12),
              Text(item.label, style: TextStyle(color: fg, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
