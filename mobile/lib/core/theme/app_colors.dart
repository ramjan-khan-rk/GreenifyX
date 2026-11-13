import 'package:flutter/material.dart';

/// Brand colours are fixed. Neutral colours (text, surfaces, borders) follow
/// light or dark mode: the app sets [isDark] before every rebuild.
class AppColors {
  AppColors._();

  static bool isDark = false;

  // ---- Brand (same in both modes) ----
  static const Color joy = Color(0xFFE36A4A);
  static const Color sun = Color(0xFFF2B544);
  static const Color eco = Color(0xFF1F8A70);
  static const Color primary = joy;
  static const Color accent = sun;
  static const Color sky = Color(0xFFD9E6F5);
  static const Color success = eco;
  static const Color error = Color(0xFFE5534B);

  /// Deep brand ink for dark backgrounds/badges that must stay dark in both modes.
  static const Color inkFixed = Color(0xFF2B2440);

  // ---- Neutrals (light / dark) ----
  static Color get ink => isDark ? const Color(0xFFF3F0F8) : const Color(0xFF2B2440);
  static Color get text => ink;
  static Color get navy => ink;
  static Color get forest => ink;
  static Color get subtitle => isDark ? const Color(0xFFA59EB3) : const Color(0xFF6E6578);
  static Color get border => isDark ? const Color(0xFF2E2A3A) : const Color(0xFFF0E2D8);
  static Color get background => isDark ? const Color(0xFF0D0C12) : const Color(0xFFFFF6EF);
  static Color get cream => background;
  static Color get card => isDark ? const Color(0xFF18161F) : Colors.white;
  static Color get surface => card;
  static Color get surfaceAlt => isDark ? const Color(0xFF211E2B) : const Color(0xFFF7F1EB);
  static Color get blush => isDark ? const Color(0xFF3A2620) : const Color(0xFFFFE8DC);
  static Color get mint => blush;
  static Color get primaryLight => blush;
}
