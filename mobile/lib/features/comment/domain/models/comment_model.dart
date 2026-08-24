class CommentModel {
  final String id;
  final String name;
  final String? profileImage;
  final String text;

  CommentModel({
    required this.id,
    required this.name,
    this.profileImage,
    required this.text,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final user = json["user"] ?? {};

    return CommentModel(
      id: json["_id"] ?? "",
      name: user["name"] ?? "Greenify User",
      profileImage: user["profileImage"],
      text: json["text"] ?? "",
    );
  }
}