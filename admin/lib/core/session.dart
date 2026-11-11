import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/admin_api.dart';

/// Holds the signed-in admin and the API client. Router listens to it.
class Session extends ChangeNotifier {
  Session._() {
    api.onUnauthorized = signOut;
  }

  static final Session instance = Session._();
  static const _tokenKey = 'gx_admin_token';

  final AdminApi api = AdminApi();
  Json? admin;
  bool restoring = true;

  bool get signedIn => admin != null;
  String get adminName => (admin?['name'] as String?)?.trim().isNotEmpty == true ? admin!['name'] as String : 'Admin';

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      if (token != null) {
        api.token = token;
        admin = await api.me();
      }
    } catch (_) {
      api.token = null;
      admin = null;
    } finally {
      restoring = false;
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password) async {
    final token = await api.login(email.trim(), password);
    api.token = token;
    try {
      admin = await api.me();
    } on ApiError catch (e) {
      api.token = null;
      if (e.status == 403) {
        throw ApiError('This account does not have admin access.');
      }
      rethrow;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    notifyListeners();
  }

  Future<void> signOut() async {
    api.token = null;
    admin = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    notifyListeners();
  }
}
