class ChatMessageModel {
  final String id;

  final String senderId;
  final String receiverId;

  final String text;

  final bool isRead;

  final DateTime createdAt;

  ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.isRead,
    required this.createdAt,
  });

  factory ChatMessageModel.fromJson(
      Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json["_id"],

      senderId: json["sender"]["_id"],

      receiverId: json["receiver"]["_id"],

      text: json["text"] ?? "",

      isRead: json["isRead"] ?? false,

      createdAt: DateTime.parse(
        json["createdAt"],
      ),
    );
  }
}