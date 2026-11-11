import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Same palette as the mobile app so both feel like one product.
class Brand {
  Brand._();

  static const Color ink = Color(0xFF2B2440);
  static const Color inkSoft = Color(0xFF3A3256);
  static const Color coral = Color(0xFFE36A4A);
  static const Color sun = Color(0xFFF2B544);
  static const Color cream = Color(0xFFFFF6EF);
  static const Color blush = Color(0xFFFFE8DC);
  static const Color eco = Color(0xFF1F8A70);
  static const Color sky = Color(0xFF4A78B5);

  static const Color surface = Colors.white;
  static const Color canvas = Color(0xFFF8F5F2);
  static const Color border = Color(0xFFECE4DD);
  static const Color muted = Color(0xFF6E6578);
  static const Color danger = Color(0xFFC2413B);

  /// Categorical colours for charts; ordered for contrast against white.
  static const List<Color> series = [eco, coral, sky, sun, Color(0xFF8A5CC2), Color(0xFF3FA7A0), Color(0xFFB0577C), inkSoft];
}

class AdminTheme {
  AdminTheme._();

  static ThemeData light() {
    final text = GoogleFonts.manropeTextTheme().apply(
      bodyColor: Brand.ink,
      displayColor: Brand.ink,
    );
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: Brand.canvas,
      colorScheme: const ColorScheme.light(
        primary: Brand.coral,
        onPrimary: Colors.white,
        secondary: Brand.ink,
        onSecondary: Colors.white,
        tertiary: Brand.sun,
        surface: Brand.surface,
        onSurface: Brand.ink,
        error: Brand.danger,
      ),
      textTheme: text,
      dividerTheme: const DividerThemeData(color: Brand.border, space: 1, thickness: 1),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Brand.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Brand.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Brand.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Brand.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Brand.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Brand.coral, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Brand.coral,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 44),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Brand.ink,
          minimumSize: const Size(64, 40),
          side: const BorderSide(color: Brand.border),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Brand.ink,
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: Brand.ink, borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.manrope(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
