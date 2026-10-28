class LeaderboardEntry {
  final String id;
  final String name;
  final String profileImage;
  final int ecoPoints;
  final int level;
  final int streak;

  const LeaderboardEntry({
    required this.id,
    required this.name,
    required this.profileImage,
    required this.ecoPoints,
    required this.level,
    required this.streak,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      id: json["_id"]?.toString() ?? "",
      name: json["name"]?.toString() ?? "GreenifyX member",
      profileImage: json["profileImage"]?.toString() ?? "",
      ecoPoints: json["ecoPoints"] is int
          ? json["ecoPoints"] as int
          : int.tryParse("${json["ecoPoints"]}") ?? 0,
      level: json["level"] is int
          ? json["level"] as int
          : int.tryParse("${json["level"]}") ?? 1,
      streak: json["streak"] is int
          ? json["streak"] as int
          : int.tryParse("${json["streak"]}") ?? 0,
    );
  }
}
