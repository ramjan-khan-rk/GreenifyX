class ChallengeModel {
  final String id;

  final String title;

  final String description;

  final String activity;

  final String category;

  final String difficulty;

  final int target;

  final int creatorProgress;

  final int friendProgress;

  final int ecoReward;

  final int karmaReward;

  final String status;

  final DateTime deadline;

  final String creatorId;

  final String creatorName;

  final String creatorImage;

  final String friendId;

  final String friendName;

  final String friendImage;

  final String? winnerId;

  ChallengeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.activity,
    required this.category,
    required this.difficulty,
    required this.target,
    required this.creatorProgress,
    required this.friendProgress,
    required this.ecoReward,
    required this.karmaReward,
    required this.status,
    required this.deadline,
    required this.creatorId,
    required this.creatorName,
    required this.creatorImage,
    required this.friendId,
    required this.friendName,
    required this.friendImage,
    this.winnerId,
  });

  factory ChallengeModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ChallengeModel(
      id: json["_id"] ?? "",

      title: json["title"] ?? "",

      description: json["description"] ?? "",

      activity: json["activity"] ?? "",

      category: json["category"] ?? "",

      difficulty: json["difficulty"] ?? "",

      target: json["target"] ?? 0,

      creatorProgress:
          json["creatorProgress"] ?? 0,

      friendProgress:
          json["friendProgress"] ?? 0,

      ecoReward:
          json["ecoReward"] ?? 0,

      karmaReward:
          json["karmaReward"] ?? 0,

      status:
          json["status"] ?? "pending",

      deadline: DateTime.parse(
        json["deadline"],
      ),

      creatorId:
          json["creator"]?["_id"] ?? "",

      creatorName:
          json["creator"]?["name"] ?? "",

      creatorImage:
          json["creator"]?["profileImage"] ?? "",

      friendId:
          json["friend"]?["_id"] ?? "",

      friendName:
          json["friend"]?["name"] ?? "",

      friendImage:
          json["friend"]?["profileImage"] ?? "",

      winnerId:
          json["winner"]?.toString(),
    );
  }
}