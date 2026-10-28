import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/application/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_restore);
  }

  Future<void> _restore() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    final user = await ref.read(authProvider.notifier).restoreSession();
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
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
