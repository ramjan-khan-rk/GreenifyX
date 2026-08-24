import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ApiService.initialize();

  runApp(
    const ProviderScope(
      child: GreenifyX(),
    ),
  );
}

class GreenifyX extends StatelessWidget {

  const GreenifyX({super.key});


  @override
  Widget build(BuildContext context) {

    return MaterialApp.router(

      debugShowCheckedModeBanner: false,

      title: "GreenifyX",

      theme: AppTheme.lightTheme,

      routerConfig: AppRouter.router,

    );

  }

}