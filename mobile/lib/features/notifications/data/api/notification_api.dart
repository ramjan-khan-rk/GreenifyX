import '../../../../core/services/api_service.dart';
import '../../domain/models/notification_model.dart';

class NotificationApi {
  Future<List<AppNotification>> list() async {
    final response = await ApiService.dio.get("/notifications");
    final items = response.data["notifications"] as List? ?? [];
    return items
        .map((item) => AppNotification.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> markRead(String id) async {
    await ApiService.dio.put("/notifications/$id/read");
  }

  Future<void> markAllRead() async {
    await ApiService.dio.put("/notifications/read-all");
  }

  /// Grouped, bundled inbox: {groups:[{label, items}], unreadByCategory, unread}.
  Future<Map<String, dynamic>> inbox(String category) async {
    final r = await ApiService.dio.get("/notifications/inbox", queryParameters: {"category": category});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<void> bulk(List<String> ids, String action) async {
    await ApiService.dio.post("/notifications/bulk", data: {"ids": ids, "action": action});
  }
}
