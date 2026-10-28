import '../../../../core/utils/eco_points.dart';

class SearchUserModel {
  final String id;
  final String name;
  final String profileImage;
  final int ecoPoints;
  final int level;

  final bool isFriend;
  final bool requestSent;
  final bool requestReceived;

  SearchUserModel({
    required this.id,
    required this.name,
    required this.profileImage,
    required this.ecoPoints,
    required this.level,
    required this.isFriend,
    required this.requestSent,
    required this.requestReceived,
  });

  factory SearchUserModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return SearchUserModel(
      id: json["_id"] ?? "",
      name: json["name"] ?? "",
      profileImage: json["profileImage"] ?? "",
      ecoPoints: parseEcoPoints(json),
      level: json["level"] ?? 1,
      isFriend: json["isFriend"] ?? false,
      requestSent: json["requestSent"] ?? false,
      requestReceived: json["requestReceived"] ?? false,
    );
  }
}
