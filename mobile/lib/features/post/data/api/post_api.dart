import 'package:dio/dio.dart';

import '../../../../core/services/api_service.dart';

class PostApi {
  Future<Response> createPost(FormData data) async {
    return await ApiService.dio.post(
      "/posts/create",
      data: data,
    );
  }

  Future<Response> getPosts() async {
    return await ApiService.dio.get("/posts");
  }
}