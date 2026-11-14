import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/i18n/app_locale.dart';
import 'core/services/translation_service.dart';

import 'core/routes/app_router.dart';
import 'core/session/session_controller.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/widgets/app_banners.dart';
import 'core/services/api_service.dart';
import 'core/services/push_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Friends' calls ring even when the app is closed (handled in the background).
  try {
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
  } catch (_) {}

  await ApiService.initialize();
  await AppLocale.load();
  await TranslationService.load();
  await ThemeController.load();
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

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, themeMode, _) => ValueListenableBuilder<Locale>(
        valueListenable: AppLocale.current,
        builder: (context, locale, _) => MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: "GreenifyX",
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          locale: locale,
          supportedLocales: const [Locale("en"), Locale("ar")],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: AppRouter.router,
          // Language or light/dark change: rebuild every screen with the new palette and direction.
          builder: (context, child) {
            final dark = Theme.of(context).brightness == Brightness.dark;
            AppColors.isDark = dark;
            return AppBanners(child: KeyedSubtree(key: ValueKey("${locale.languageCode}-$dark"), child: child ?? const SizedBox()));
          },
        ),
      ),
    );

  }

}