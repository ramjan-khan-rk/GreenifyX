import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static final ThemeData lightTheme = _build();

  static ThemeData _build() {
    final text = GoogleFonts.manropeTextTheme().apply(bodyColor: AppColors.text, displayColor: AppColors.text);
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.navy,
        onSecondary: Colors.white,
        tertiary: AppColors.accent,
        surface: AppColors.card,
        onSurface: AppColors.text,
        error: AppColors.error,
        surfaceContainerHighest: AppColors.blush,
      ),
      textTheme: text.copyWith(
        headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.2),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.6,
        shadowColor: Colors.black12,
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.forest,
        titleTextStyle: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.forest),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primary.withValues(alpha: 0.14),
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? AppColors.primary : AppColors.subtitle, size: 24),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => GoogleFonts.manrope(
            fontSize: 11.5,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
            color: s.contains(WidgetState.selected) ? AppColors.primary : AppColors.subtitle,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.joy,
        unselectedItemColor: AppColors.ink,
        type: BottomNavigationBarType.fixed,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.navy,
        contentTextStyle: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: const BorderSide(color: AppColors.border),
        labelStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: AppColors.ink),
        selectedColor: AppColors.primary.withValues(alpha: 0.14),
        backgroundColor: Colors.white,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
      listTileTheme: const ListTileThemeData(iconColor: AppColors.primary),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 50),
          elevation: 0,
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 15.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border),
          minimumSize: const Size(64, 46),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}
