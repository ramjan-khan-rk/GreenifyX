import '../../../../core/utils/eco_points.dart';

class ProfileModel {
  final String id;
  final String name;
  final String bio;
  final String profileImage;
  final String email;

  final int ecoPoints;
  final int streak;
  final int level;
  final int friendsCount;
  final List<String> badges;

  ProfileModel({
    required this.id,
    required this.name,
    required this.bio,
    required this.profileImage,
    required this.email,
    required this.ecoPoints,
    required this.streak,
    required this.level,
    required this.friendsCount,
    this.badges = const [],
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json["_id"] ?? "",
      name: json["name"] ?? "",
      bio: json["bio"] ?? "",
      profileImage: json["profileImage"] ?? "",
      email: json["email"] ?? "",
      ecoPoints: parseEcoPoints(json),
      streak: json["streak"] ?? 0,
      level: json["level"] ?? 1,
      friendsCount: json["friendsCount"] ?? 0,
      badges: (json["badges"] as List?)
              ?.map((item) => item.toString())
              .toList() ??
          const [],
    );
  }
}
