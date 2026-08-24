import '../../domain/models/challenge_model.dart';
import '../api/challenge_api.dart';

class ChallengeRepository {
  final ChallengeApi api = ChallengeApi();

  Future<List<ChallengeModel>> getChallenges() async {
    final data = await api.getChallenges();

    return data
        .map<ChallengeModel>(
          (e) => ChallengeModel.fromJson(e),
        )
        .toList();
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
    await api.createChallenge(
      friendId: friendId,
      title: title,
      description: description,
      activity: activity,
      category: category,
      difficulty: difficulty,
      target: target,
      deadline: deadline,
    );
  }

  Future<void> acceptChallenge(
    String challengeId,
  ) async {
    await api.acceptChallenge(challengeId);
  }

  Future<void> rejectChallenge(
    String challengeId,
  ) async {
    await api.rejectChallenge(challengeId);
  }

  Future<void> updateProgress(
    String challengeId,
  ) async {
    await api.updateProgress(challengeId);
  }
}
