import 'package:dio/dio.dart';

import '../../../../core/services/api_service.dart';

class FeedApi {
  Future<Response> getPosts({int page = 1, int limit = 20}) async {
    return await ApiService.dio.get(
      "/posts",
      queryParameters: {"page": page, "limit": limit},
    );
  }
Future<Response> toggleLike(String postId) async {
  return await ApiService.dio.put("/posts/$postId/like");
}

  Future<Response> verifyPost(String postId) {
    return ApiService.dio.put("/posts/$postId/verify");
  }


}
