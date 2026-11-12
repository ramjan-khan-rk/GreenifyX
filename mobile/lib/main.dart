import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/i18n/app_locale.dart';

import 'core/routes/app_router.dart';
import 'core/session/session_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ApiService.initialize();
  await AppLocale.load();
  await SessionController.instance.syncFromStorage();

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

    return ValueListenableBuilder<Locale>(
      valueListenable: AppLocale.current,
      builder: (context, locale, _) => MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: "GreenifyX",
        theme: AppTheme.lightTheme,
        locale: locale,
        supportedLocales: const [Locale("en"), Locale("ar")],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: AppRouter.router,
        // Rebuild every screen when the language flips so all text and layout direction update.
        builder: (context, child) => KeyedSubtree(key: ValueKey(locale.languageCode), child: child ?? const SizedBox()),
      ),
    );

  }

}