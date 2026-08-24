import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository/challenge_repository.dart';
import '../../domain/models/challenge_model.dart';

final challengeRepositoryProvider =
    Provider<ChallengeRepository>(
  (ref) => ChallengeRepository(),
);

final challengesProvider =
    FutureProvider<List<ChallengeModel>>(
  (ref) {
    return ref
        .read(challengeRepositoryProvider)
        .getChallenges();
  },
);