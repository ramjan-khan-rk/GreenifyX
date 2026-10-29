import 'feed_model.dart';

class FeedPage {
  final List<FeedModel> posts;
  final bool hasMore;
  final int page;

  const FeedPage({
    required this.posts,
    required this.hasMore,
    required this.page,
  });
}
