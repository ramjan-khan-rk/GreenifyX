import '../../domain/models/comment_model.dart';
import '../api/comment_api.dart';

class CommentRepository {
  final CommentApi _api = CommentApi();

  Future<List<CommentModel>> getComments(
    String postId,
  ) async {
    final response = await _api.getComments(postId);

    return response
        .map<CommentModel>(
          (json) => CommentModel.fromJson(json),
        )
        .toList();
  }

  Future<void> addComment(
    String postId,
    String text,
  ) async {
    await _api.addComment(postId, text);
  }
}