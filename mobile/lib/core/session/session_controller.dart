import 'package:flutter/foundation.dart';

import '../services/storage_service.dart';

class SessionController extends ChangeNotifier {
  SessionController._();

  static final SessionController instance = SessionController._();

  bool hasToken = false;

  Future<void> syncFromStorage() async {
    final token = await StorageService.getToken();
    setHasToken(token != null && token.isNotEmpty);
  }

  void setHasToken(bool value) {
    if (hasToken == value) return;
    hasToken = value;
    notifyListeners();
  }
}

const authPublicLocations = {
  "/login",
  "/register",
  "/forgot-password",
};

const authProtectedLocations = {
  "/home",
  "/complete-profile",
};

String? authRedirect({
  required bool hasToken,
  required String location,
}) {
  if (location == "/") {
    return null;
  }
  if (!hasToken && authProtectedLocations.contains(location)) {
    return "/login";
  }
  if (hasToken && authPublicLocations.contains(location)) {
    return "/home";
  }
  return null;
}
