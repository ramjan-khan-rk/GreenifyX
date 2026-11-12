import '../../core/services/api_service.dart';

class SettingsApi {
  Future<Map<String, dynamic>> load() async {
    final r = await ApiService.dio.get("/users/me/settings");
    return Map<String, dynamic>.from(r.data["settings"] as Map);
  }

  Future<void> save({Map<String, bool>? prefs, String? language}) async {
    await ApiService.dio.patch("/users/me/settings", data: {
      "notificationPrefs": ?prefs,
      "language": ?language,
    });
  }

  Future<void> changePassword(String current, String next) async {
    await ApiService.dio.post("/users/me/password", data: {"currentPassword": current, "newPassword": next});
  }

  Future<void> deleteAccount(String password) async {
    await ApiService.dio.delete("/users/me", data: {"password": password});
  }
}
