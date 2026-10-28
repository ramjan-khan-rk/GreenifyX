import 'package:flutter_test/flutter_test.dart';
import 'package:greenifyx/features/home/domain/models/leaderboard_entry.dart';

void main() {
  test("parses leaderboard JSON", () {
    final entry = LeaderboardEntry.fromJson({
      "_id": "u1",
      "name": "Aisha",
      "profileImage": "https://example.com/a.jpg",
      "ecoPoints": 120,
      "level": 3,
      "streak": 4,
    });

    expect(entry.id, "u1");
    expect(entry.name, "Aisha");
    expect(entry.ecoPoints, 120);
    expect(entry.level, 3);
    expect(entry.streak, 4);
  });

  test("falls back when fields are missing", () {
    final entry = LeaderboardEntry.fromJson({});
    expect(entry.name, "GreenifyX member");
    expect(entry.ecoPoints, 0);
    expect(entry.level, 1);
  });
}
