import '../../../../core/utils/eco_points.dart';

class UserModel {
  final String id;
  final String phone;
  final String name;
  final String profileImage;
  final String bio;

  final int ecoPoints;
  final int level;
  final int streak;

  final bool isProfileCompleted;

  const UserModel({
    required this.id,
    required this.phone,
    required this.name,
    required this.profileImage,
    required this.bio,
    required this.ecoPoints,
    required this.level,
    required this.streak,
    required this.isProfileCompleted,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json["_id"] ?? "",
      phone: json["phone"] ?? "",
      name: json["name"] ?? "",
      profileImage: json["profileImage"] ?? "",
      bio: json["bio"] ?? "",
      ecoPoints: parseEcoPoints(json),
      level: json["level"] ?? 1,
      streak: json["streak"] ?? 0,
      isProfileCompleted: json["isProfileCompleted"] ?? false,
    );
  }
}
