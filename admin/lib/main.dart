import 'package:flutter/material.dart';

import 'core/router.dart';
import 'core/session.dart';
import 'core/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Session.instance.restore();
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GreenifyX Admin',
      debugShowCheckedModeBanner: false,
      theme: AdminTheme.light(),
      routerConfig: adminRouter,
      builder: (context, child) => ListenableBuilder(
        listenable: Session.instance,
        builder: (context, _) => Session.instance.restoring
            ? const Scaffold(
                backgroundColor: Brand.cream,
                body: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
              )
            : child ?? const SizedBox.shrink(),
      ),
    );
  }
}
