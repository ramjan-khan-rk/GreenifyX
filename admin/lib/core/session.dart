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
  /// A partner login sees only its own organisation (the Partner portal).
  bool get isPartner => admin?['role'] == 'partner';
  /// A third-party auditor sees only the Audit trail.
  bool get isAuditor => admin?['role'] == 'auditor';
  String get adminName => (admin?['name'] as String?)?.trim().isNotEmpty == true ? admin!['name'] as String : 'Admin';

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      if (token != null) {
        api.token = token;
        admin = await _whoAmI();
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
      admin = await _whoAmI();
    } on ApiError catch (e) {
      api.token = null;
      if (e.status == 403 || e.status == 404) {
        throw ApiError('This account does not have admin or partner access.');
      }
      rethrow;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    notifyListeners();
  }

  /// Admin first; otherwise a partner login (scoped to one organisation).
  Future<Json> _whoAmI() async {
    try {
      return await api.me();
    } on ApiError catch (e) {
      if (e.status != 403) rethrow;
      try {
        final p = await api.getJson('/partner/me');
        final partner = Json.from(p['partner'] as Map);
        return {...partner, 'role': 'partner', 'organisation': p['organisation']};
      } on ApiError catch (pe) {
        if (pe.status != 403 && pe.status != 404) rethrow;
        final a = await api.getJson('/audit/me');
        return {...Json.from(a['auditor'] as Map), 'role': 'auditor'};
      }
    }
  }

  Future<void> signOut() async {
    api.token = null;
    admin = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    notifyListeners();
  }
}
