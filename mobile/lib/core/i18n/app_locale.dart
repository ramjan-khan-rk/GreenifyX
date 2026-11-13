import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'strings_ar.dart';

/// App language (English / Arabic). Arabic switches the whole UI to right-to-left.
class AppLocale {
  AppLocale._();

  static const _storage = FlutterSecureStorage();
  static const _key = "app_language";

  static final ValueNotifier<Locale> current = ValueNotifier(const Locale("en"));

  static bool get isArabic => current.value.languageCode == "ar";

  static Future<void> load() async {
    try {
      final code = await _storage.read(key: _key);
      if (code == "ar" || code == "en") current.value = Locale(code!);
    } catch (_) {}
  }

  static Future<void> set(String code) async {
    if (code != "ar" && code != "en") return;
    current.value = Locale(code);
    try {
      await _storage.write(key: _key, value: code);
    } catch (_) {}
  }
}

/// Translate an English UI string. Falls back to English when no Arabic entry exists.
String tr(String en) => AppLocale.isArabic ? (stringsAr[en] ?? en) : en;
