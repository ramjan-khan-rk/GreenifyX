import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/app_locale.dart';
import 'api_service.dart';

/// Auto-translate for posts and comments, with a member-chosen language.
class TranslationService {
  TranslationService._();

  static const languages = {
    "en": "English",
    "ar": "العربية",
    "hi": "हिन्दी",
    "ur": "اردو",
    "tl": "Tagalog",
    "ml": "മലയാളം",
  };

  static const _key = "translate_to";

  /// Empty means "same as the app language".
  static final ValueNotifier<String> chosen = ValueNotifier("");
  static final Map<String, String> _cache = {};

  static String get target => chosen.value.isNotEmpty ? chosen.value : (AppLocale.isArabic ? "ar" : "en");

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      chosen.value = p.getString(_key) ?? "";
    } catch (_) {}
  }

  static Future<void> set(String code) async {
    chosen.value = code;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, code);
    } catch (_) {}
  }

  static String _script(String s) {
    var arabic = 0, devanagari = 0, malayalam = 0, latin = 0;
    for (final c in s.runes) {
      if (c >= 0x0600 && c <= 0x06FF) {
        arabic++;
      } else if (c >= 0x0900 && c <= 0x097F) {
        devanagari++;
      } else if (c >= 0x0D00 && c <= 0x0D7F) {
        malayalam++;
      } else if ((c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A)) {
        latin++;
      }
    }
    final best = [("arabic", arabic), ("devanagari", devanagari), ("malayalam", malayalam), ("latin", latin)]..sort((a, b) => b.$2.compareTo(a.$2));
    return best.first.$2 == 0 ? "other" : best.first.$1;
  }

  static const _targetScript = {"en": "latin", "tl": "latin", "ar": "arabic", "ur": "arabic", "hi": "devanagari", "ml": "malayalam"};

  /// Show "See translation" only when the text is in a different script from the reader's language.
  static bool worthOffering(String text) {
    final s = _script(text);
    return s != "other" && s != _targetScript[target];
  }

  static Future<String> translate(String text) async {
    final to = target;
    final key = "$to:$text";
    final hit = _cache[key];
    if (hit != null) return hit;
    final r = await ApiService.dio.post("/translate", data: {"text": text, "to": to});
    final out = r.data["text"]?.toString() ?? text;
    _cache[key] = out;
    return out;
  }
}
