class ChatModel {
  final String userId;
  final String userName;
  final String profileImage;
  final String lastMessage;
  final bool lastFromMe;
  final DateTime time;
  final bool unread;

  ChatModel({
    required this.userId,
    required this.userName,
    required this.profileImage,
    required this.lastMessage,
    required this.time,
    required this.unread,
    this.lastFromMe = false,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    final user = (json["user"] as Map?) ?? const {};
    return ChatModel(
      userId: user["_id"]?.toString() ?? "",
      userName: user["name"]?.toString() ?? "Friend",
      profileImage: user["profileImage"]?.toString() ?? "",
      lastMessage: json["lastMessage"]?.toString() ?? "",
      lastFromMe: json["lastFromMe"] == true,
      time: DateTime.tryParse(json["time"]?.toString() ?? "")?.toLocal() ?? DateTime.now(),
      unread: json["unread"] == true,
    );
  }
}
