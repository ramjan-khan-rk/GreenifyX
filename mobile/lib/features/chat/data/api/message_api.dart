import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../../../../core/services/api_service.dart';

class MessageApi {
  Future<List<dynamic>> getMessages(String userId) async {
    final response = await ApiService.dio.get("/messages/$userId");
    return response.data["messages"];
  }

  Future<List<dynamic>> getChats() async {
    final response = await ApiService.dio.get("/messages");
    return response.data["chats"];
  }

  Future<void> sendMessage({required String receiverId, String text = "", String? audio, String? image, int durationSec = 0}) async {
    await ApiService.dio.post("/messages", data: {
      "receiverId": receiverId,
      "text": text,
      "audio": ?audio,
      "image": ?image,
      if (audio != null) "durationSec": durationSec,
    });
  }

  Future<String> uploadAudio(File file) async {
    final form = FormData.fromMap({
      "audio": await MultipartFile.fromFile(file.path, filename: "voice.m4a", contentType: MediaType("audio", "mp4")),
    });
    final res = await ApiService.dio.post(
      "/upload/audio",
      data: form,
      options: Options(sendTimeout: const Duration(minutes: 1), receiveTimeout: const Duration(minutes: 1)),
    );
    return res.data["audioUrl"].toString();
  }

  Future<String> uploadImage(File file) async {
    final form = FormData.fromMap({
      "image": await MultipartFile.fromFile(file.path, filename: file.path.split(RegExp(r"[/\\]")).last),
    });
    final res = await ApiService.dio.post(
      "/upload/image",
      data: form,
      options: Options(sendTimeout: const Duration(minutes: 1), receiveTimeout: const Duration(minutes: 1)),
    );
    return res.data["imageUrl"].toString();
  }

  Future<Map<String, dynamic>> presence(String userId) async {
    final res = await ApiService.dio.get("/messages/presence/$userId");
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> markRead(String userId) => ApiService.dio.put("/messages/read/$userId");
}
