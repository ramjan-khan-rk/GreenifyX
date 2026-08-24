import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/friend_repository.dart';
import '../../domain/models/friend_model.dart';

final friendRepositoryProvider =
Provider(
  (ref) => FriendRepository(),
);

final friendsProvider =
FutureProvider<List<FriendModel>>((ref) {

  return ref
      .read(friendRepositoryProvider)
      .getFriends();

});

final requestsProvider =
FutureProvider<List<FriendModel>>((ref) {

  return ref
      .read(friendRepositoryProvider)
      .getRequests();

});