import 'package:dio/dio.dart';

import '../../../../core/services/api_service.dart';

class CommentApi {
  Future<List<dynamic>> getComments(String postId) async {
    final response = await ApiService.dio.get(
      "/comments/$postId",
    );

    return response.data["comments"];
  }

  Future<void> addComment(
    String postId,
    String text,
  ) async {
    await ApiService.dio.post(
      "/comments/$postId",
      data: {
        "text": text,
      },
    );
  }
}