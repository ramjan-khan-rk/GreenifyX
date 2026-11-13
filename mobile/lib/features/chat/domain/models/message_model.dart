class ChatMessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final String type; // text | image | audio
  final String image;
  final String audio;
  final int durationSec;
  final bool isRead;
  final DateTime createdAt;

  ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.isRead,
    required this.createdAt,
    this.type = "text",
    this.image = "",
    this.audio = "",
    this.durationSec = 0,
  });

  static String _id(dynamic v) => v is Map ? (v["_id"]?.toString() ?? "") : (v?.toString() ?? "");

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json["_id"]?.toString() ?? "",
      senderId: _id(json["sender"]),
      receiverId: _id(json["receiver"]),
      text: json["text"]?.toString() ?? "",
      type: json["messageType"]?.toString() ?? "text",
      image: json["image"]?.toString() ?? "",
      audio: json["audio"]?.toString() ?? "",
      durationSec: (json["durationSec"] as num?)?.toInt() ?? 0,
      isRead: json["isRead"] == true,
      createdAt: DateTime.tryParse(json["createdAt"]?.toString() ?? "")?.toLocal() ?? DateTime.now(),
    );
  }
}
