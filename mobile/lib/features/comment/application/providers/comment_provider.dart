import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/comment_repository.dart';
import '../../domain/models/comment_model.dart';

final commentRepositoryProvider = Provider(
  (ref) => CommentRepository(),
);

final commentProvider = FutureProvider.family<
    List<CommentModel>, String>((ref, postId) async {
  return ref
      .read(commentRepositoryProvider)
      .getComments(postId);
});