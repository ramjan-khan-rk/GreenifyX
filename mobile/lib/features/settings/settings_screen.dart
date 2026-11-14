import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/theme_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/widgets/user_avatar.dart';
import '../auth/application/providers/auth_provider.dart';
import '../chat/application/providers/chats_provider.dart';
import '../friends/application/providers/friend_provider.dart';
import '../profile/application/providers/my_profile_provider.dart';
import '../profile/application/providers/profile_provider.dart';
import '../profile/presentation/screens/edit_profile_screen.dart';
import 'legal_screen.dart';
import 'settings_api.dart';
import '../../core/i18n/app_locale.dart';
import '../../core/services/translation_service.dart';
import '../../core/services/push_service.dart';
import '../voice/greeny.dart';
import '../growth/growth_screens.dart';
import '../auth/data/uae_pass_auth.dart';
import '../../core/services/api_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _api = SettingsApi();
  final Map<String, bool> _prefs = {"messages": true, "calls": true, "social": true, "campaigns": true, "points": true};
  String _language = "en";
  bool _loaded = false;

  static const _prefLabels = {
    "messages": ("Messages", Icons.chat_bubble_outline_rounded),
    "calls": ("Calls", Icons.call_outlined),
    "social": ("Friends, likes & comments", Icons.favorite_border_rounded),
    "campaigns": ("Campaigns & events", Icons.campaign_outlined),
    "points": ("Eco Points & rewards", Icons.stars_outlined),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await _api.load();
      final p = Map<String, dynamic>.from(s["notificationPrefs"] as Map? ?? {});
      if (!mounted) return;
      setState(() {
        for (final k in _prefs.keys.toList()) {
          _prefs[k] = p[k] != false;
        }
        _language = AppLocale.current.value.languageCode;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _togglePref(String key, bool v) async {
    setState(() => _prefs[key] = v);
    try {
      await _api.save(prefs: {key: v});
    } catch (e) {
      if (mounted) {
        setState(() => _prefs[key] = !v);
        _snack(friendlyError(e));
      }
    }
  }

  Future<void> _setLanguage(String lang) async {
    final old = _language;
    setState(() => _language = lang);
    try {
      await _api.save(language: lang);
      await AppLocale.set(lang);
      _snack(lang == "ar" ? "تم حفظ اللغة العربية" : "Language saved");
    } catch (e) {
      if (mounted) {
        setState(() => _language = old);
        _snack(friendlyError(e));
      }
    }
  }

  Future<void> _logout() async {
    await PushService.instance.unregister();
    await ref.read(profileProvider.notifier).logout();
    await ref.read(authProvider.notifier).logout();
    ref.invalidate(myProfileProvider);
    ref.invalidate(friendsProvider);
    ref.invalidate(requestsProvider);
    ref.invalidate(chatsProvider);
    if (mounted) context.go(AppRoutes.login);
  }

  Future<void> _changePassword() async {
    final cur = TextEditingController();
    final next = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr("Change password"), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(controller: cur, obscureText: true, decoration: InputDecoration(labelText: tr("Current password"))),
          const SizedBox(height: 12),
          TextField(
            controller: next,
            obscureText: true,
            decoration: InputDecoration(labelText: tr("New password"), helperText: tr("At least 8 characters with letters and a number")),
          ),
          const SizedBox(height: 18),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr("Update password"))),
        ]),
      ),
    );
    if (ok != true) return;
    try {
      await _api.changePassword(cur.text, next.text);
      _snack("Password updated");
    } catch (e) {
      _snack(friendlyError(e));
    }
  }

  Future<void> _deleteAccount() async {
    final pw = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr("Delete your account?")),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(tr("Your profile, posts and points will be removed. This can't be undone.")),
          const SizedBox(height: 14),
          TextField(controller: pw, obscureText: true, decoration: InputDecoration(labelText: tr("Confirm with your password"))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr("Cancel"))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr("Delete")),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteAccount(pw.text);
      await _logout();
    } catch (e) {
      _snack(friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr("Settings"))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          profile.maybeWhen(
            data: (u) => _Card(children: [
              ListTile(
                contentPadding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                leading: UserAvatar(imageUrl: u.profileImage, name: u.name, radius: 28),
                title: Text(u.name.isEmpty ? tr("Add your name") : u.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                subtitle: Text(u.bio.isEmpty ? tr("Add a bio so friends know you") : u.bio, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
              ),
            ]),
            orElse: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
          ),
          const _Label("Account"),
          _Card(children: [
            _Row(icon: Icons.person_outline_rounded, title: tr("Edit profile"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()))),
            _Row(icon: Icons.lock_outline_rounded, title: tr("Change password"), onTap: _changePassword),
            const _UaePassRow(),
          ]),
          const _Label("Greeny voice assistant"),
          _Card(children: [
            ValueListenableBuilder<bool>(
              valueListenable: Greeny.instance.handsFree,
              builder: (_, on, _) => SwitchListTile(
                secondary: const Icon(Icons.mic_rounded, color: AppColors.eco),
                title: Text(tr("Hands-free \"Hey Greeny\""), style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(tr("Listens for \"Hey Greeny\" while the app is open")),
                value: on,
                onChanged: (v) => Greeny.instance.setHandsFree(v),
              ),
            ),
            _Row(icon: Icons.record_voice_over_rounded, title: "Try Greeny now", onTap: () => Greeny.instance.open(context)),
          ]),
          const _Label("Grow"),
          _Card(children: [
            _Row(icon: Icons.card_giftcard_rounded, title: "Invite friends", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InviteScreen()))),
            _Row(icon: Icons.verified_rounded, title: "Get verified", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BadgeRequestScreen()))),
          ]),
          const _Label("Notifications"),
          _Card(children: [
            for (final e in _prefLabels.entries)
              SwitchListTile(
                secondary: Icon(e.value.$2, color: AppColors.ink),
                title: Text(tr(e.value.$1), style: const TextStyle(fontWeight: FontWeight.w600)),
                value: _prefs[e.key] ?? true,
                onChanged: _loaded ? (v) => _togglePref(e.key, v) : null,
              ),
          ]),
          const _Label("Language"),
          _Card(children: [
            for (final l in const [("en", "English"), ("ar", "العربية")])
              ListTile(
                leading: Icon(Icons.translate_rounded, color: AppColors.ink),
                title: Text(l.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: _language == l.$1 ? const Icon(Icons.check_circle_rounded, color: AppColors.eco) : null,
                onTap: () => _setLanguage(l.$1),
              ),
          ]),
          const _Label("Translate posts into"),
          _Card(children: [
            ValueListenableBuilder<String>(
              valueListenable: TranslationService.chosen,
              builder: (context, chosen, _) => Column(children: [
                ListTile(
                  leading: Icon(Icons.g_translate_rounded, color: AppColors.ink),
                  title: Text(tr("Same as the app"), style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: chosen.isEmpty ? const Icon(Icons.check_circle_rounded, color: AppColors.eco) : null,
                  onTap: () => TranslationService.set(""),
                ),
                for (final l in TranslationService.languages.entries)
                  ListTile(
                    leading: const SizedBox(width: 24),
                    title: Text(l.value, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: chosen == l.key ? const Icon(Icons.check_circle_rounded, color: AppColors.eco) : null,
                    onTap: () => TranslationService.set(l.key),
                  ),
              ]),
            ),
          ]),
          const _Label("Appearance"),
          _Card(children: [
            ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemeController.mode,
              builder: (context, mode, _) => Padding(
                padding: const EdgeInsets.all(12),
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(selectedBackgroundColor: AppColors.primary.withValues(alpha: 0.16)),
                  segments: [
                    ButtonSegment(value: ThemeMode.system, icon: const Icon(Icons.brightness_auto_rounded), label: Text(tr("Auto"))),
                    ButtonSegment(value: ThemeMode.light, icon: const Icon(Icons.light_mode_rounded), label: Text(tr("Light"))),
                    ButtonSegment(value: ThemeMode.dark, icon: const Icon(Icons.dark_mode_rounded), label: Text(tr("Dark"))),
                  ],
                  selected: {mode},
                  onSelectionChanged: (v) {
                    HapticFeedback.selectionClick();
                    ThemeController.set(v.first);
                  },
                ),
              ),
            ),
          ]),
          const _Label("About"),
          _Card(children: [
            _Row(icon: Icons.privacy_tip_outlined, title: tr("Privacy policy"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LegalScreen.privacy))),
            _Row(icon: Icons.description_outlined, title: tr("Terms of use"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LegalScreen.terms))),
            ListTile(leading: const Icon(Icons.info_outline_rounded), title: Text(tr("Version")), trailing: const Text("1.0.0")),
          ]),
          const SizedBox(height: 20),
          _Card(children: [
            _Row(icon: Icons.logout_rounded, title: tr("Log out"), onTap: _logout),
            _Row(icon: Icons.delete_outline_rounded, title: tr("Delete account"), danger: true, onTap: _deleteAccount),
          ]),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 22, 8, 8),
        child: Text(tr(text).toUpperCase(), style: TextStyle(fontSize: 12, letterSpacing: 0.8, fontWeight: FontWeight.w800, color: AppColors.subtitle)),
      );
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});
  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 14, offset: Offset(0, 4))],
        ),
        child: Column(children: children),
      );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool danger;
  const _Row({required this.icon, required this.title, required this.onTap, this.danger = false});
  @override
  Widget build(BuildContext context) {
    final c = danger ? AppColors.error : AppColors.ink;
    return ListTile(
      leading: Icon(icon, color: c),
      title: Text(tr(title), style: TextStyle(color: c, fontWeight: FontWeight.w600)),
      trailing: danger ? null : const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

/// Link UAE PASS to this account; shows "Verified resident" once linked.
class _UaePassRow extends StatefulWidget {
  const _UaePassRow();
  @override
  State<_UaePassRow> createState() => _UaePassRowState();
}

class _UaePassRowState extends State<_UaePassRow> {
  bool? _enabled;
  bool _verified = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final on = await UaePassAuth.enabled();
    var verified = false;
    try {
      final r = await ApiService.dio.get("/users/me");
      verified = r.data["user"]?["isVerifiedResident"] == true;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _enabled = on;
      _verified = verified;
    });
  }

  Future<void> _link() async {
    setState(() => _busy = true);
    try {
      final ok = await UaePassAuth.link();
      if (ok) await _load();
      if (mounted && ok) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(_verified ? "UAE PASS linked. You're a verified resident." : "UAE PASS linked."))));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_enabled != true) return const SizedBox.shrink();
    return ListTile(
      leading: Icon(_verified ? Icons.verified_user_rounded : Icons.fingerprint_rounded, color: _verified ? AppColors.eco : AppColors.ink),
      title: Text(_verified ? tr("Verified resident (UAE PASS)") : tr("Link UAE PASS"), style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600)),
      subtitle: _verified ? null : Text(tr("Confirms you're a UAE resident for official campaigns")),
      trailing: _verified ? null : (_busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right_rounded)),
      onTap: _verified || _busy ? null : _link,
    );
  }
}
