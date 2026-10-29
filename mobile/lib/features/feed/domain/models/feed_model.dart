class FeedModel {
  final String id;
  final String userId;
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
  final String pointsStatus;

  FeedModel({
    required this.id,
    required this.userId,
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
    this.pointsStatus = "unverified_self_reported",
  });

  factory FeedModel.fromJson(Map<String, dynamic> json) {
    final user = json["user"] ?? {};

    return FeedModel(
      id: json["_id"] ?? "",
      userId: user["_id"] ?? "",
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
      pointsStatus: json["pointsStatus"]?.toString() ??
          ((json["isVerified"] == true)
              ? "verified"
              : "unverified_self_reported"),
    );
  }
}