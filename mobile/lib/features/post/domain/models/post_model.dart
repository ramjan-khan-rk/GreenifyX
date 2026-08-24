class PostModel {
  final String id;
  final String image;
  final String description;
  final String activity;
  final int ecoPoints;

  PostModel({
    required this.id,
    required this.image,
    required this.description,
    required this.activity,
    required this.ecoPoints,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json["_id"] ?? "",
      image: json["image"] ?? "",
      description: json["description"] ?? "",
      activity: json["activity"] ?? "",
      ecoPoints: json["ecoPoints"] ?? 0,
    );
  }
}