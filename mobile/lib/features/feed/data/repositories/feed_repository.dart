import '../../domain/models/feed_model.dart';
import '../../domain/models/feed_page.dart';
import '../api/feed_api.dart';

class FeedRepository {
  final FeedApi _api = FeedApi();

  Future<FeedPage> getPostsPage({int page = 1, int limit = 20}) async {
    final response = await _api.getPosts(page: page, limit: limit);
    final List posts = response.data["posts"] ?? [];
    return FeedPage(
      posts: posts.map((e) => FeedModel.fromJson(e)).toList(),
      hasMore: response.data["hasMore"] == true,
      page: page,
    );
  }
  Future<void> toggleLike(String postId) async {
  await _api.toggleLike(postId);
}

  Future<bool> toggleSave(String postId) async {
    final r = await _api.toggleSave(postId);
    return r.data["saved"] == true;
  }

  Future<void> verifyPost(String postId) async {
    await _api.verifyPost(postId);
  }

  Future<void> reportPost(String postId, String reason) async {
    await _api.reportPost(postId, reason);
  }
}