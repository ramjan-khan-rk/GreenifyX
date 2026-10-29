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
}
