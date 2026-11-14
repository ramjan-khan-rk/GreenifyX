import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/api_service.dart';
import '../domain/models/login_response.dart';

class UaePassException implements Exception {
  UaePassException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// UAE PASS sign-in through the system browser. The server talks to UAE PASS
/// and sends the browser back to `greenifyx://uaepass?code=…` with a one-time code.
class UaePassAuth {
  UaePassAuth._();

  static bool? _enabled;

  /// Whether the server has UAE PASS switched on (cached after the first check).
  static Future<bool> enabled() async {
    if (_enabled != null) return _enabled!;
    try {
      final r = await ApiService.dio.get("/auth/uaepass/status");
      return _enabled = r.data["enabled"] == true;
    } catch (_) {
      return false;
    }
  }

  static const _errors = {
    "expired": "That sign-in took too long. Please try again.",
    "cancelled": "UAE PASS sign-in was cancelled.",
    "suspended": "This account is suspended.",
    "no_profile": "UAE PASS didn't share your profile. Please try again.",
    "failed": "UAE PASS sign-in didn't work. Please try again.",
  };

  static Future<String?> _browser(String url) async {
    try {
      final back = await FlutterWebAuth2.authenticate(url: url, callbackUrlScheme: "greenifyx");
      final q = Uri.parse(back).queryParameters;
      if (q["error"] != null) throw UaePassException(_errors[q["error"]] ?? _errors["failed"]!);
      return q["code"];
    } on UaePassException {
      rethrow;
    } catch (_) {
      return null; // closed the browser
    }
  }

  /// Returns null if the person closed the browser.
  static Future<LoginResponse?> signIn() async {
    final code = await _browser("${AppConfig.apiBaseUrl}/auth/uaepass/start");
    if (code == null) return null;
    final r = await ApiService.dio.post("/auth/uaepass/exchange", data: {"code": code});
    return LoginResponse.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  /// Link UAE PASS to the signed-in account (makes it a verified resident). Returns true when linked.
  static Future<bool> link() async {
    final r = await ApiService.dio.post("/auth/uaepass/link");
    final code = await _browser(r.data["url"].toString());
    if (code == null) return false;
    // The code also signs in; we only needed the link, so swap it to close the step.
    await ApiService.dio.post("/auth/uaepass/exchange", data: {"code": code});
    return true;
  }
}
