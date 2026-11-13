class AppNotification {
  final String id;
  final String type;
  final String title;
  final String message;
  final bool isRead;
  final String senderId;
  final String senderName;
  final String senderImage;
  final String referenceId;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    this.senderId = "",
    this.senderName = "",
    this.senderImage = "",
    this.referenceId = "",
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final sender = json["sender"];
    final s = sender is Map ? sender : const {};
    return AppNotification(
      id: json["_id"]?.toString() ?? "",
      type: json["type"]?.toString() ?? "",
      title: json["title"]?.toString() ?? "Update",
      message: json["message"]?.toString() ?? "",
      isRead: json["isRead"] == true,
      senderId: sender is Map ? (s["_id"]?.toString() ?? "") : (sender?.toString() ?? ""),
      senderName: s["name"]?.toString() ?? "",
      senderImage: s["profileImage"]?.toString() ?? "",
      referenceId: json["referenceId"]?.toString() ?? "",
      createdAt: DateTime.tryParse(json["createdAt"]?.toString() ?? "")?.toLocal() ?? DateTime.now(),
    );
  }
}
