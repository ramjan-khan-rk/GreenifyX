import '../../../../core/utils/eco_points.dart';

class ProfileModel {
  final String id;
  final String name;
  final String bio;
  final String profileImage;

  final int ecoPoints;
  final int streak;
  final int level;
  final int friendsCount;

  ProfileModel({
    required this.id,
    required this.name,
    required this.bio,
    required this.profileImage,
    required this.ecoPoints,
    required this.streak,
    required this.level,
    required this.friendsCount,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json["_id"] ?? "",
      name: json["name"] ?? "",
      bio: json["bio"] ?? "",
      profileImage: json["profileImage"] ?? "",
      ecoPoints: parseEcoPoints(json),
      streak: json["streak"] ?? 0,
      level: json["level"] ?? 1,
      friendsCount: json["friendsCount"] ?? 0,
    );
  }
}
