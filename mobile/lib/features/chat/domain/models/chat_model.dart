class ChatModel {
  final String userId;
  final String userName;
  final String profileImage;
  final String lastMessage;
  final DateTime time;
  final bool unread;

  ChatModel({
    required this.userId,
    required this.userName,
    required this.profileImage,
    required this.lastMessage,
    required this.time,
    required this.unread,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      userId: json["user"]["_id"],
      userName: json["user"]["name"],
      profileImage: json["user"]["profileImage"] ?? "",
      lastMessage: json["lastMessage"] ?? "",
      time: DateTime.parse(json["time"]),
      unread: json["unread"] ?? false,
    );
  }
}