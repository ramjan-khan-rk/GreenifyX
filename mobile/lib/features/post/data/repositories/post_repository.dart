import 'package:dio/dio.dart';

import '../api/post_api.dart';

class PostRepository {
  final PostApi _api = PostApi();

  Future<void> createPost(FormData formData) async {
    await _api.createPost(formData);
  }

  Future getPosts() async {
    return await _api.getPosts();
  }
}