import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import 'api_service.dart';

/// Uploads an audio file (voice note or post soundtrack) and returns its URL.
Future<String> uploadAudioFile(File file, {String? filename}) async {
  final name = filename ?? file.path.split(RegExp(r"[/\\]")).last;
  final lower = name.toLowerCase();
  final sub = lower.endsWith(".mp3")
      ? "mpeg"
      : lower.endsWith(".wav")
          ? "wav"
          : lower.endsWith(".ogg")
              ? "ogg"
              : lower.endsWith(".aac")
                  ? "aac"
                  : "mp4";
  final form = FormData.fromMap({
    "audio": await MultipartFile.fromFile(file.path, filename: name, contentType: MediaType("audio", sub)),
  });
  final res = await ApiService.dio.post(
    "/upload/audio",
    data: form,
    options: Options(sendTimeout: const Duration(minutes: 2), receiveTimeout: const Duration(minutes: 2)),
  );
  return res.data["audioUrl"].toString();
}
