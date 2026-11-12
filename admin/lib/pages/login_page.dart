import 'package:flutter/material.dart';

import '../api/admin_api.dart';
import '../core/session.dart';
import '../core/theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Session.instance.signIn(_email.text, _password.text);
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not sign in. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final form = _buildForm(context);
    return Scaffold(
      backgroundColor: Brand.cream,
      body: wide
          ? Row(children: [const Expanded(child: _BrandPanel()), Expanded(child: Center(child: form))])
          : Center(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: form)),
    );
  }

  Widget _buildForm(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Sign in to Admin', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('Use an account with admin access.', style: t.bodyMedium?.copyWith(color: Brand.muted)),
              const SizedBox(height: 28),
              TextFormField(
                controller: _email,
                autofillHints: const [AutofillHints.email],
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
                validator: (v) => (v == null || !v.contains('@')) ? 'Enter your email' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Brand.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded, color: Brand.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: Brand.danger, fontWeight: FontWeight.w600))),
                  ]),
                ),
              ],
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      color: Brand.ink,
      padding: const EdgeInsets.all(56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset('assets/brand/app_icon_rounded.png', width: 40, height: 40),
            ),
            const SizedBox(width: 12),
            Text('GreenifyX', style: t.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          ]),
          const Spacer(),
          Text('Small actions.\nBig impact.',
              style: t.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.1)),
          const SizedBox(height: 16),
          Text(
            'Track verified eco actions, community growth and estimated CO₂ savings across all seven emirates.',
            style: t.titleMedium?.copyWith(color: Colors.white.withValues(alpha: 0.7), height: 1.5),
          ),
          const SizedBox(height: 28),
          Wrap(spacing: 10, runSpacing: 10, children: const [
            _Chip(Icons.verified_rounded, 'Community-verified actions'),
            _Chip(Icons.co2_rounded, 'CO₂ impact estimates'),
            _Chip(Icons.shield_rounded, 'Moderation'),
          ]),
          const Spacer(),
          Text('UAE pilot', style: TextStyle(color: Colors.white.withValues(alpha: 0.45))),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: Brand.sun),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
