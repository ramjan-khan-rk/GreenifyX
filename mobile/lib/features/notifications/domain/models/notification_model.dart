class AppNotification {
  final String id;
  final String type;
  final String title;
  final String message;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json["_id"] ?? "",
      type: json["type"] ?? "",
      title: json["title"] ?? "Update",
      message: json["message"] ?? "",
      isRead: json["isRead"] ?? false,
    );
  }
}
