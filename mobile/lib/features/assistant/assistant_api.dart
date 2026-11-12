import 'dart:io';

import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http_parser/http_parser.dart';

import '../../core/services/api_service.dart';

class ChatTurn {
  final String role; // user | assistant
  final String text;
  final List<Map<String, dynamic>> cards;
  const ChatTurn(this.role, this.text, [this.cards = const []]);
}

class SnapOutcome {
  final bool aiAvailable;
  final Map<String, dynamic>? result;
  final List<Map<String, dynamic>> places;
  const SnapOutcome(this.aiAvailable, this.result, this.places);
}

List<Map<String, dynamic>> _maps(dynamic v) =>
    (v as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

/// Best-effort location without prompting twice; null when unavailable.
Future<Position?> quietPosition() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return null;
    return await Geolocator.getLastKnownPosition() ??
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 10)),
        );
  } catch (_) {
    return null;
  }
}

class AssistantApi {
  Future<ChatTurn> ask(List<ChatTurn> history, {Position? at}) async {
    final res = await ApiService.dio.post(
      "/assistant/chat",
      data: {
        "messages": [for (final t in history) {"role": t.role, "text": t.text}],
        if (at != null) "lat": at.latitude,
        if (at != null) "lng": at.longitude,
      },
      options: Options(receiveTimeout: const Duration(seconds: 60)),
    );
    return ChatTurn("assistant", res.data["reply"]?.toString() ?? "", _maps(res.data["cards"]));
  }

  Future<SnapOutcome> snap(File photo, {Position? at}) async {
    final name = photo.path.split(Platform.pathSeparator).last;
    final form = FormData.fromMap({
      "photos": await MultipartFile.fromFile(photo.path, filename: name, contentType: MediaType("image", "jpeg")),
      if (at != null) "lat": at.latitude.toString(),
      if (at != null) "lng": at.longitude.toString(),
    });
    final res = await ApiService.dio.post(
      "/assistant/snap",
      data: form,
      options: Options(sendTimeout: const Duration(minutes: 1), receiveTimeout: const Duration(minutes: 1)),
    );
    final r = res.data["result"];
    return SnapOutcome(res.data["aiAvailable"] == true, r is Map ? Map<String, dynamic>.from(r) : null, _maps(res.data["places"]));
  }

  Future<List<Map<String, dynamic>>> guideItems() async {
    final res = await ApiService.dio.get("/assistant/guide");
    return _maps(res.data["items"]);
  }

  Future<SnapOutcome> guide(String key, {Position? at}) async {
    final res = await ApiService.dio.get("/assistant/guide", queryParameters: {
      "key": key,
      if (at != null) "lat": at.latitude,
      if (at != null) "lng": at.longitude,
    });
    return SnapOutcome(false, Map<String, dynamic>.from(res.data["result"] as Map), _maps(res.data["places"]));
  }
}
