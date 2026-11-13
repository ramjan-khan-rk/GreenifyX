import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/app_locale.dart';
import '../../../../core/services/server_wake.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_status.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../../auth/domain/models/user_model.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  /// null = normal spinner, "waking" = friendly wait message, "failed" = retry.
  String? _phase;

  @override
  void initState() {
    super.initState();
    Future.microtask(_restore);
  }

  Future<void> _restore() async {
    setState(() => _phase = null);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    // Wake the server first so the first screen loads instead of erroring.
    await ServerWake.instance.ensureAwake(onSlow: () {
      if (mounted) setState(() => _phase = "waking");
    });
    if (!mounted) return;

    final UserModel? user;
    try {
      user = await ref.read(authProvider.notifier).restoreSession();
    } catch (_) {
      // Network trouble: keep them signed in and let them try again.
      if (mounted) setState(() => _phase = "failed");
      return;
    }
    if (!mounted) return;

    if (user == null) {
      context.go("/login");
      return;
    }

    if (!user.isProfileCompleted) {
      context.go("/complete-profile");
      return;
    }

    context.go("/home");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const BrandLockup(markSize: 96),
              const SizedBox(height: 28),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: switch (_phase) {
                  "failed" => Column(key: const ValueKey("failed"), children: [
                      Icon(Icons.cloud_off_rounded, color: AppColors.subtitle, size: 30),
                      const SizedBox(height: 10),
                      Text(tr("Can't reach GreenifyX right now"),
                          textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
                      const SizedBox(height: 4),
                      Text(tr("Check your internet and try again. You're still signed in."),
                          textAlign: TextAlign.center, style: TextStyle(color: AppColors.subtitle)),
                      const SizedBox(height: 16),
                      FilledButton.icon(onPressed: _restore, icon: const Icon(Icons.refresh_rounded), label: Text(tr("Try again"))),
                    ]),
                  "waking" => Column(key: const ValueKey("waking"), children: [
                      const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary)),
                      const SizedBox(height: 16),
                      Text(tr("Getting everything ready…"),
                          textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
                      const SizedBox(height: 4),
                      Text(tr("This can take up to a minute the first time."),
                          textAlign: TextAlign.center, style: TextStyle(color: AppColors.subtitle)),
                    ]),
                  _ => const SizedBox(
                      key: ValueKey("spin"),
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                    ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
