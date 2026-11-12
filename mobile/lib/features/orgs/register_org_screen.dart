import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/emirates.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/friendly_error.dart';
import 'org_api.dart';
import 'org_widgets.dart';

class RegisterOrgScreen extends ConsumerStatefulWidget {
  const RegisterOrgScreen({super.key});

  @override
  ConsumerState<RegisterOrgScreen> createState() => _RegisterOrgScreenState();
}

class _RegisterOrgScreenState extends ConsumerState<RegisterOrgScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _website = TextEditingController();
  final _reg = TextEditingController();
  final _email = TextEditingController();
  String _type = orgTypes.first;
  String _emirate = "Dubai";
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _description, _website, _reg, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final msg = await ref.read(orgApiProvider).register({
        "name": _name.text.trim(),
        "type": _type,
        "emirate": _emirate,
        "description": _description.text.trim(),
        "website": _website.text.trim(),
        "registrationRef": _reg.text.trim(),
        "contactEmail": _email.text.trim(),
      });
      messenger.showSnackBar(SnackBar(content: Text(msg)));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text("Register organisation", style: AppTextStyles.title)),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), children: [
          const Text(
            "Companies, schools, universities, NGOs and communities can register. Every organisation is verified before it gets the trusted badge.",
            style: TextStyle(color: AppColors.subtitle, height: 1.45),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: "Organisation name"),
            validator: (v) => (v == null || v.trim().length < 3) ? "Enter the name" : null,
          ),
          const SizedBox(height: 14),
          Text("Type", style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in orgTypes)
              ChoiceChip(avatar: Icon(orgIcon(t), size: 16), label: Text(t), selected: _type == t, onSelected: (_) => setState(() => _type = t)),
          ]),
          const SizedBox(height: 14),
          Text("Emirate", style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in kEmirates) ChoiceChip(label: Text(e), selected: _emirate == e, onSelected: (_) => setState(() => _emirate = e)),
          ]),
          const SizedBox(height: 14),
          TextFormField(controller: _description, maxLines: 3, maxLength: 600, decoration: const InputDecoration(labelText: "About (optional)")),
          TextFormField(controller: _website, decoration: const InputDecoration(labelText: "Website (optional)")),
          const SizedBox(height: 14),
          TextFormField(
            controller: _reg,
            decoration: const InputDecoration(labelText: "Trade licence / registration number", helperText: "Used only to verify your organisation"),
          ),
          const SizedBox(height: 14),
          TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: "Work contact email")),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(onPressed: _saving ? null : _submit, child: Text(_saving ? "Submitting…" : "Submit for verification")),
          ),
        ),
      ),
    );
  }
}
