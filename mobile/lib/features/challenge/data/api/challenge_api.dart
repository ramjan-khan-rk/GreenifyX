import '../../../../core/services/api_service.dart';

class ChallengeApi {
  Future<List<dynamic>> getChallenges() async {
    final response = await ApiService.dio.get(
      "/challenges",
    );

    return response.data["challenges"];
  }

  Future<void> createChallenge({
    required String friendId,
    required String title,
    required String description,
    required String activity,
    required String category,
    required String difficulty,
    required int target,
    required DateTime deadline,
  }) async {
    await ApiService.dio.post(
      "/challenges/create",
      data: {
        "friendId": friendId,
        "title": title,
        "description": description,
        "activity": activity,
        "category": category,
        "difficulty": difficulty,
        "target": target,
        "deadline": deadline.toIso8601String(),
      },
    );
  }

  Future<void> acceptChallenge(
    String challengeId,
  ) async {
    await ApiService.dio.put(
      "/challenges/accept/$challengeId",
    );
  }

  Future<void> rejectChallenge(
    String challengeId,
  ) async {
    await ApiService.dio.put(
      "/challenges/reject/$challengeId",
    );
  }

  Future<void> updateProgress(
    String challengeId,
  ) async {
    await ApiService.dio.put(
      "/challenges/progress/$challengeId",
    );
  }
}
