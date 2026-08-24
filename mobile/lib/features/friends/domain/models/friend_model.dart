class FriendModel {
  final String id;
  final String name;
  final String bio;
  final String profileImage;

  final int ecoScore;
  final int karamCount;
  final int level;
  final int streak;

  FriendModel({
    required this.id,
    required this.name,
    required this.bio,
    required this.profileImage,
    required this.ecoScore,
    required this.karamCount,
    required this.level,
    required this.streak,
  });

  factory FriendModel.fromJson(Map<String, dynamic> json) {
    return FriendModel(
      id: json["_id"] ?? "",
      name: json["name"] ?? "",
      bio: json["bio"] ?? "",
      profileImage: json["profileImage"] ?? "",
      ecoScore: json["ecoScore"] ?? 0,
      karamCount: json["karamCount"] ?? 0,
      level: json["level"] ?? 1,
      streak: json["streak"] ?? 0,
    );
  }
}