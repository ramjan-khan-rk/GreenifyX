import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/feed_repository.dart';
import '../../domain/models/feed_model.dart';

final feedProvider =
    FutureProvider<List<FeedModel>>((ref) async {
  return FeedRepository().getPosts();
});
final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository();
});