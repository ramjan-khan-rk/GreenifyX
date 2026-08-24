import 'package:dio/dio.dart';

import '../../../../core/services/api_service.dart';

class FeedApi {
  Future<Response> getPosts() async {
    return await ApiService.dio.get("/posts");

  }
Future<Response> toggleLike(String postId) async {
  return await ApiService.dio.put("/posts/$postId/like");
}


}
