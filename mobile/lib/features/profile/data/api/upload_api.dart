import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/services/api_service.dart';

class UploadApi {
  Future<String> uploadImage(File image) async {
    final formData = FormData.fromMap({
      "image": await MultipartFile.fromFile(
        image.path,
        filename: image.path.split("/").last,
      ),
    });

    final response = await ApiService.dio.post(
      "/upload/image",
      data: formData,
    );

    return response.data["imageUrl"];
  }
}