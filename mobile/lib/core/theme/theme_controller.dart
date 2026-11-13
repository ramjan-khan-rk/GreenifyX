import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light / dark / follow-the-phone, remembered on the device.
class ThemeController {
  ThemeController._();
  static final mode = ValueNotifier<ThemeMode>(ThemeMode.system);
  static const _key = "theme_mode";

  static Future<void> load() async {
    try {
      final v = (await SharedPreferences.getInstance()).getString(_key);
      mode.value = switch (v) { "light" => ThemeMode.light, "dark" => ThemeMode.dark, _ => ThemeMode.system };
    } catch (_) {}
  }

  static Future<void> set(ThemeMode m) async {
    mode.value = m;
    try {
      (await SharedPreferences.getInstance()).setString(_key, m.name);
    } catch (_) {}
  }
}
