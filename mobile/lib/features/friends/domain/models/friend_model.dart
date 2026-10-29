import '../../../../core/utils/eco_points.dart';

class FriendModel {
  final String id;
  final String name;
  final String bio;
  final String profileImage;
  final int ecoPoints;
  final int level;
  final int streak;

  FriendModel({
    required this.id,
    required this.name,
    required this.bio,
    required this.profileImage,
    required this.ecoPoints,
    required this.level,
    required this.streak,
  });

  factory FriendModel.fromJson(Map<String, dynamic> json) {
    return FriendModel(
      id: json["_id"] ?? "",
      name: json["name"] ?? "",
      bio: json["bio"] ?? "",
      profileImage: json["profileImage"] ?? "",
      ecoPoints: parseEcoPoints(json),
      level: json["level"] ?? 1,
      streak: json["streak"] ?? 0,
    );
  }
}
