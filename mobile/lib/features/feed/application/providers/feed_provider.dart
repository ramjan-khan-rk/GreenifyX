import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/feed_repository.dart';
import '../../domain/models/feed_model.dart';
import '../../domain/models/feed_page.dart';

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository();
});

class FeedNotifier extends AsyncNotifier<FeedPage> {
  @override
  Future<FeedPage> build() => _fetch(page: 1);

  Future<FeedPage> _fetch({
    required int page,
    List<FeedModel> prior = const [],
  }) async {
    final next = await ref.read(feedRepositoryProvider).getPostsPage(page: page);
    return FeedPage(
      posts: [...prior, ...next.posts],
      hasMore: next.hasMore,
      page: page,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(page: 1));
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore) return;
    state = await AsyncValue.guard(
      () => _fetch(page: current.page + 1, prior: current.posts),
    );
  }
}

final feedProvider = AsyncNotifierProvider<FeedNotifier, FeedPage>(FeedNotifier.new);
