import '../../domain/models/feed_model.dart';
import '../api/feed_api.dart';

class FeedRepository {
  final FeedApi _api = FeedApi();

  Future<List<FeedModel>> getPosts() async {
    final response = await _api.getPosts();

    final List posts = response.data["posts"];

    return posts
        .map((e) => FeedModel.fromJson(e))
        .toList();
  }
  Future<void> toggleLike(String postId) async {
  await _api.toggleLike(postId);
}
}