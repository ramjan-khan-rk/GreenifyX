class FeedModel {
  final String id;
  final String name;
  final String? profileImage;
  final String image;
  final String description;
  final String activity;
  final int ecoPoints;
  final int likes;
  final int comments;
  final bool isLiked;
  final bool isVerified;

  FeedModel({
    required this.id,
    required this.name,
    this.profileImage,
    required this.image,
    required this.description,
    required this.activity,
    required this.ecoPoints,
    required this.likes,
    required this.comments,
    required this.isLiked,
    required this.isVerified,
  });

  factory FeedModel.fromJson(Map<String, dynamic> json) {
    final user = json["user"] ?? {};

    return FeedModel(
      id: json["_id"] ?? "",
      name: user["name"] ?? "Greenify User",
      profileImage: user["profileImage"],
      image: json["image"] ?? "",
      description: json["description"] ?? "",
      activity: json["activity"] ?? "",
      ecoPoints: json["ecoPoints"] ?? 0,
      likes: json["likesCount"] ?? 0,
      comments: json["commentsCount"] ?? 0,
      isLiked: json["isLiked"] ?? false,
      isVerified: json["isVerified"] ?? false,
    );
  }
}