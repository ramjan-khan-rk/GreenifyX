import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/admin_api.dart';
import '../core/session.dart';
import '../core/theme.dart';
import 'users_page.dart' show emirates;

const _orgTypes = ['Company', 'School', 'University', 'NGO', 'Community', 'Government'];
const _interests = ['Tree planting', 'Beach & desert clean-ups', 'Staff engagement', 'ESG reporting', 'Recycling pickups', 'Events & workshops'];

/// Public marketing site: "GreenifyX for organisations".
class PublicSitePage extends StatefulWidget {
  const PublicSitePage({super.key});

  @override
  State<PublicSitePage> createState() => _PublicSitePageState();
}

class _PublicSitePageState extends State<PublicSitePage> {
  final _scroll = ScrollController();
  final _formKey = GlobalKey();
  Json? _stats;

  @override
  void initState() {
    super.initState();
    Session.instance.api.publicStats().then((s) {
      if (mounted) setState(() => _stats = s);
    }).catchError((_) {});
  }

  void _toForm() {
    final ctx = _formKey.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final wide = w >= 900;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        controller: _scroll,
        child: Column(children: [
          _NavBar(onCta: _toForm, wide: wide),
          _Hero(wide: wide, onCta: _toForm),
          _Section(child: _StatsRow(stats: _stats, wide: wide)),
          _Section(
            color: Brand.canvas,
            child: Column(children: [
              const _Heading(kicker: 'HOW IT WORKS', title: 'From pledge to proof in three steps'),
              const SizedBox(height: 32),
              _Grid(wide: wide, children: const [
                _Step(n: '1', title: 'Register your organisation', body: 'Tell us who you are. We verify every organisation before it gets the trusted badge.'),
                _Step(n: '2', title: 'Invite your people', body: 'Staff, students or members join with your private code and take part in verified campaigns.'),
                _Step(n: '3', title: 'See verified impact', body: 'Field verifiers confirm attendance with GPS and photos. Your dashboard updates live.'),
              ]),
            ]),
          ),
          _Section(
            child: Column(children: [
              const _Heading(kicker: 'WHAT YOU GET', title: 'Everything your green programme needs'),
              const SizedBox(height: 32),
              _Grid(wide: wide, children: const [
                _Feature(icon: Icons.forest_rounded, color: Brand.eco, title: 'Verified campaigns', body: 'Tree planting, clean-ups and recycling drives with geofenced, photo-verified attendance.'),
                _Feature(icon: Icons.leaderboard_rounded, color: Brand.coral, title: 'Team dashboard', body: 'Members, verified Eco Points, trees and kg collected, with a fair per-member leaderboard.'),
                _Feature(icon: Icons.insights_rounded, color: Brand.sky, title: 'ESG-ready numbers', body: 'Indicative CO₂ saved, tree survival checks and an auditable points ledger for your reports.'),
                _Feature(icon: Icons.redeem_rounded, color: Brand.sun, title: 'Rewards that motivate', body: 'Staff spend points on vouchers, experiences and transport credit from UAE partners.'),
                _Feature(icon: Icons.local_shipping_rounded, color: Color(0xFF56AB2F), title: 'Recycling pickups', body: 'Doorstep collection of plastic, paper, e-waste and more, weighed and credited.'),
                _Feature(icon: Icons.event_rounded, color: Color(0xFF7F53AC), title: 'Events calendar', body: 'Publish workshops and green days; members RSVP in the app and get reminders.'),
              ]),
            ]),
          ),
          _Section(
            color: Brand.ink,
            child: Column(children: [
              const _Heading(kicker: 'BUILT FOR THE UAE', title: 'For every kind of organisation', light: true),
              const SizedBox(height: 24),
              Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
                for (final t in const ['Companies', 'Schools', 'Universities', 'NGOs', 'Communities', 'Government entities'])
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white24)),
                    child: Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
              ]),
              const SizedBox(height: 20),
              Text('All seven emirates · English and Arabic · Verified by authorised field teams',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
            ]),
          ),
          _Section(key: _formKey, color: Brand.cream, child: const _EnquiryForm()),
          const _Footer(),
        ]),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.onCta, required this.wide});
  final VoidCallback onCta;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Brand.border))),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/brand/app_icon_rounded.png', width: 36, height: 36)),
            const SizedBox(width: 10),
            const Text('GreenifyX', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Brand.ink, letterSpacing: -0.4)),
            const Spacer(),
            if (wide) TextButton(onPressed: () => context.go('/login'), child: const Text('Admin sign in')),
            const SizedBox(width: 8),
            FilledButton(onPressed: onCta, child: const Text('Register your organisation')),
          ]),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.wide, required this.onCta});
  final bool wide;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    final text = Column(crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(30)),
        child: const Text('🇦🇪  The UAE’s verified green action platform', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      const SizedBox(height: 20),
      Text(
        'Turn your green goals into verified impact.',
        textAlign: wide ? TextAlign.start : TextAlign.center,
        style: TextStyle(color: Colors.white, fontSize: wide ? 54 : 36, height: 1.08, fontWeight: FontWeight.w800, letterSpacing: -1.2),
      ),
      const SizedBox(height: 18),
      Text(
        'GreenifyX helps companies, schools and communities run tree plantings, clean-ups and recycling programmes, with every action checked on site and every point on the record.',
        textAlign: wide ? TextAlign.start : TextAlign.center,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 18, height: 1.5),
      ),
      const SizedBox(height: 28),
      Wrap(spacing: 12, runSpacing: 12, alignment: wide ? WrapAlignment.start : WrapAlignment.center, children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Brand.sun, foregroundColor: Brand.ink, minimumSize: const Size(0, 54), padding: const EdgeInsets.symmetric(horizontal: 26)),
          onPressed: onCta,
          icon: const Icon(Icons.business_rounded),
          label: const Text('Register your organisation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54), minimumSize: const Size(0, 54), padding: const EdgeInsets.symmetric(horizontal: 22)),
          onPressed: onCta,
          icon: const Icon(Icons.calendar_month_rounded),
          label: const Text('Book a demo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ]),
    ]);
    final art = Container(
      width: 340,
      height: 340,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white12, width: 30),
      ),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(44),
          child: Image.asset('assets/brand/app_icon_rounded.png', width: 180, height: 180),
        ),
      ),
    );
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: wide ? 96 : 64),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF0E5A3A), Color(0xFF1F8A70), Color(0xFF2B2440)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: wide
              ? Row(children: [Expanded(child: text), const SizedBox(width: 48), art])
              : text,
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats, required this.wide});
  final Json? stats;
  final bool wide;

  String _fmt(num? v) {
    final n = (v ?? 0).toDouble();
    if (n >= 1e6) return '${(n / 1e6).toStringAsFixed(1)}M';
    if (n >= 1e3) return '${(n / 1e3).toStringAsFixed(n >= 1e4 ? 0 : 1)}K';
    return n.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final s = stats ?? {};
    final items = [
      ('Members', _fmt(s['members'] as num?), Icons.people_alt_rounded, Brand.sky),
      ('Verified organisations', _fmt(s['organisations'] as num?), Icons.verified_rounded, Brand.eco),
      ('Trees planted', _fmt(s['treesPlanted'] as num?), Icons.park_rounded, const Color(0xFF56AB2F)),
      ('Kg waste collected', _fmt(s['wasteKg'] as num?), Icons.recycling_rounded, Brand.coral),
    ];
    return Column(children: [
      const _Heading(kicker: 'LIVE IMPACT', title: 'Numbers straight from the platform'),
      const SizedBox(height: 28),
      _Grid(wide: wide, columns: 4, children: [
        for (final i in items)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: Brand.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: i.$4.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(i.$3, color: i.$4),
              ),
              const SizedBox(height: 18),
              Text(stats == null ? '—' : i.$2, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Brand.ink, letterSpacing: -1)),
              const SizedBox(height: 4),
              Text(i.$1, style: const TextStyle(color: Brand.muted, fontWeight: FontWeight.w600)),
            ]),
          ),
      ]),
    ]);
  }
}

class _EnquiryForm extends StatefulWidget {
  const _EnquiryForm();

  @override
  State<_EnquiryForm> createState() => _EnquiryFormState();
}

class _EnquiryFormState extends State<_EnquiryForm> {
  final _form = GlobalKey<FormState>();
  final _org = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _site = TextEditingController();
  final _msg = TextEditingController();
  String _type = 'Company';
  String _emirate = 'Dubai';
  String _size = '50–250';
  final _picked = <String>{};
  bool _sending = false;
  String? _done;
  String? _error;

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final msg = await Session.instance.api.sendEnquiry({
        'organisation': _org.text.trim(),
        'type': _type,
        'emirate': _emirate,
        'size': _size,
        'contactName': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'website': _site.text.trim(),
        'interests': _picked.toList(),
        'message': _msg.text.trim(),
      });
      setState(() => _done = msg);
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done != null) {
      return Column(children: [
        const Icon(Icons.check_circle_rounded, color: Brand.eco, size: 64),
        const SizedBox(height: 16),
        const Text('Request received', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Brand.ink)),
        const SizedBox(height: 8),
        Text(_done!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Brand.muted)),
      ]);
    }
    final wide = MediaQuery.of(context).size.width >= 760;
    Widget pair(Widget a, Widget b) => wide
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 14), Expanded(child: b)])
        : Column(children: [a, const SizedBox(height: 14), b]);
    String? req(String? v) => (v ?? '').trim().length < 2 ? 'Required' : null;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Column(children: [
        const _Heading(kicker: 'GET STARTED', title: 'Bring GreenifyX to your organisation'),
        const SizedBox(height: 10),
        const Text('Free pilot for the first 3 months. We reply within 2 working days.', style: TextStyle(color: Brand.muted, fontSize: 16)),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 30, offset: Offset(0, 12))],
          ),
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              pair(
                TextFormField(controller: _org, decoration: const InputDecoration(labelText: 'Organisation name'), validator: req),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [for (final t in _orgTypes) DropdownMenuItem(value: t, child: Text(t))],
                  onChanged: (v) => setState(() => _type = v ?? _type),
                ),
              ),
              const SizedBox(height: 14),
              pair(
                DropdownButtonFormField<String>(
                  initialValue: _emirate,
                  decoration: const InputDecoration(labelText: 'Emirate'),
                  items: [for (final e in emirates) DropdownMenuItem(value: e, child: Text(e))],
                  onChanged: (v) => setState(() => _emirate = v ?? _emirate),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _size,
                  decoration: const InputDecoration(labelText: 'People'),
                  items: [for (final s in const ['1–50', '50–250', '250–1,000', '1,000+']) DropdownMenuItem(value: s, child: Text(s))],
                  onChanged: (v) => setState(() => _size = v ?? _size),
                ),
              ),
              const SizedBox(height: 14),
              pair(
                TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Your name'), validator: req),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Work email'),
                  validator: (v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid email',
                ),
              ),
              const SizedBox(height: 14),
              pair(
                TextFormField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone (optional)')),
                TextFormField(controller: _site, decoration: const InputDecoration(labelText: 'Website (optional)')),
              ),
              const SizedBox(height: 18),
              const Text('What are you interested in?', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final i in _interests)
                  FilterChip(
                    label: Text(i),
                    selected: _picked.contains(i),
                    onSelected: (v) => setState(() => v ? _picked.add(i) : _picked.remove(i)),
                  ),
              ]),
              const SizedBox(height: 18),
              TextFormField(controller: _msg, maxLines: 4, decoration: const InputDecoration(labelText: 'Anything else? (optional)')),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Brand.danger))),
              const SizedBox(height: 22),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                onPressed: _sending ? null : _submit,
                child: Text(_sending ? 'Sending…' : 'Send request', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 10),
              const Text('By sending this form you agree to be contacted about GreenifyX.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: Brand.muted)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        color: Brand.ink,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Wrap(alignment: WrapAlignment.spaceBetween, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset('assets/brand/app_icon_rounded.png', width: 28, height: 28)),
                const SizedBox(width: 10),
                const Text('GreenifyX', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              ]),
              Text('© ${DateTime.now().year} GreenifyX · Built by Ramjan Khan · hello@greenifyx.ae',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
            ]),
          ),
        ),
      );
}

/* ---------- layout helpers ---------- */

class _Section extends StatelessWidget {
  const _Section({super.key, required this.child, this.color = Colors.white});
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: color,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 72),
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1120), child: child)),
      );
}

class _Heading extends StatelessWidget {
  const _Heading({required this.kicker, required this.title, this.light = false});
  final String kicker;
  final String title;
  final bool light;

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(kicker, style: TextStyle(color: light ? Brand.sun : Brand.coral, fontWeight: FontWeight.w800, letterSpacing: 1.6, fontSize: 13)),
        const SizedBox(height: 10),
        Text(title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: light ? Colors.white : Brand.ink, letterSpacing: -0.8, height: 1.15)),
      ]);
}

class _Grid extends StatelessWidget {
  const _Grid({required this.wide, required this.children, this.columns = 3});
  final bool wide;
  final List<Widget> children;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 900 ? columns : c.maxWidth >= 560 ? 2 : 1;
      const gap = 18.0;
      final itemW = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(spacing: gap, runSpacing: gap, children: [for (final w in children) SizedBox(width: itemW, child: w)]);
    });
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.title, required this.body});
  final String n;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Brand.coral, Brand.sun])),
            child: Text(n, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
          ),
          const SizedBox(height: 18),
          Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Brand.ink)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(color: Brand.muted, height: 1.5, fontSize: 15)),
        ]),
      );
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.color, required this.title, required this.body});
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: Brand.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 18),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Brand.ink)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(color: Brand.muted, height: 1.5, fontSize: 15)),
        ]),
      );
}

/// Where Stripe sends people after paying for a partner reward.
class PaymentResultPage extends StatelessWidget {
  const PaymentResultPage({super.key, required this.success});
  final bool success;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.cream,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(success ? Icons.check_circle_rounded : Icons.info_rounded, size: 64, color: success ? Brand.eco : Brand.sun),
                const SizedBox(height: 16),
                Text(success ? 'Payment received' : 'Payment cancelled',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Brand.ink)),
                const SizedBox(height: 10),
                Text(
                  success
                      ? 'Go back to the GreenifyX app. Your reward code appears in Rewards → My codes.'
                      : 'No money was taken. You can go back to the GreenifyX app and try again.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Brand.muted, fontSize: 16, height: 1.5),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
