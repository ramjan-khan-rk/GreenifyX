import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../../core/services/api_service.dart';

typedef Json = Map<String, dynamic>;

List<Json> maps(dynamic v) => (v as List? ?? const []).map((e) => Json.from(e as Map)).toList();

/// Discover, stories, reels, creators, battles, companion and communities.
class SocialApi {
  static final _d = ApiService.dio;

  static Future<Json> forYou({int page = 1}) async => Json.from((await _d.get("/discover/foryou", queryParameters: {"page": page})).data as Map);
  static Future<Json> reels({int page = 1, String? sound}) async =>
      Json.from((await _d.get("/discover/reels", queryParameters: {"page": page, "sound": ?sound})).data as Map);
  static Future<void> view(String postId) async {
    try {
      await _d.post("/discover/posts/$postId/view");
    } catch (_) {}
  }

  static Future<List<Json>> sounds() async => maps((await _d.get("/discover/sounds")).data["sounds"]);
  static Future<Json> creator(String id) async => Json.from((await _d.get("/discover/creators/$id")).data as Map);
  static Future<bool> follow(String id) async => (await _d.post("/discover/creators/$id/follow")).data["following"] == true;
  static Future<void> setInterests(List<String> list) async => _d.put("/discover/interests", data: {"interests": list});

  static Future<List<Json>> stories() async => maps((await _d.get("/stories")).data["groups"]);
  static Future<void> viewStory(String id) async {
    try {
      await _d.post("/stories/$id/view");
    } catch (_) {}
  }

  static Future<bool> likeStory(String id) async => (await _d.post("/stories/$id/like")).data["liked"] == true;
  static Future<Json> storyViewers(String id) async => Json.from((await _d.get("/stories/$id/viewers")).data as Map);
  static Future<void> deleteStory(String id) async => _d.delete("/stories/$id");
  static Future<void> createStory({required File file, required bool video, String caption = "", String look = "natural", String? musicUrl, String musicTitle = ""}) async {
    final name = file.path.split(RegExp(r"[/\\]")).last;
    await _d.post(
      "/stories",
      data: FormData.fromMap({
        "caption": caption,
        "look": look,
        "musicUrl": ?musicUrl,
        "musicTitle": musicTitle,
        "image": await MultipartFile.fromFile(file.path,
            filename: name, contentType: video ? MediaType("video", name.toLowerCase().endsWith(".mov") ? "quicktime" : "mp4") : MediaType("image", "jpeg")),
      }),
      options: Options(sendTimeout: const Duration(minutes: 3), receiveTimeout: const Duration(minutes: 3)),
    );
  }

  static Future<Json> battle(String league) async => Json.from((await _d.get("/battles", queryParameters: {"league": league})).data as Map);
  static Future<Json> companion() async => Json.from((await _d.get("/companion/today", options: Options(receiveTimeout: const Duration(seconds: 25)))).data as Map);
  static Future<void> setGoal(int points, int actions) async => _d.post("/companion/goal", data: {"points": points, "actions": actions});

  static Future<Json> communities({String? category, String? q, bool mine = false}) async => Json.from(
      (await _d.get("/communities", queryParameters: {"category": ?category, "q": ?q, if (mine) "mine": "1"})).data as Map);
  static Future<Json> community(String id) async => Json.from((await _d.get("/communities/$id")).data as Map);
  static Future<Json> createCommunity(Json body) async => Json.from((await _d.post("/communities", data: body)).data["community"] as Map);
  static Future<bool> joinCommunity(String id) async => (await _d.post("/communities/$id/join")).data["isMember"] == true;
  static Future<void> hostChallenge(String id, Json body) async => _d.post("/communities/$id/challenges", data: body);
  static Future<void> joinChallenge(String id, String challengeId) async => _d.post("/communities/$id/challenges/$challengeId/join");
  static Future<void> hostEvent(String id, Json body) async => _d.post("/communities/$id/events", data: body);
  static Future<Json> analytics() async => Json.from((await _d.get("/creator/analytics")).data as Map);

  static Future<Json> groupMessages(String id, {String? before}) async =>
      Json.from((await _d.get("/communities/$id/messages", queryParameters: {"before": ?before})).data as Map);
  static Future<Json> sendGroupMessage(String id, Json body) async => Json.from((await _d.post("/communities/$id/messages", data: body)).data["message"] as Map);
}
