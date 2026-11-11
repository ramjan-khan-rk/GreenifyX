import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import '../../../core/services/api_service.dart';
import '../domain/issue_model.dart';

class IssueApi {
  List<IssueReport> _list(dynamic v) => (v as List? ?? const [])
      .whereType<Map>()
      .map((e) => IssueReport.fromJson(Map<String, dynamic>.from(e)))
      .toList();

  Future<List<IssueReport>> mine() async {
    final res = await ApiService.dio.get("/env-reports/mine");
    return _list(res.data["reports"]);
  }

  Future<List<IssueReport>> nearby({double? lat, double? lng}) async {
    final res = await ApiService.dio.get("/env-reports/nearby", queryParameters: {
      if (lat != null) "lat": lat,
      if (lng != null) "lng": lng,
      "radiusKm": 25,
    });
    return _list(res.data["reports"]);
  }

  Future<void> confirm(String id) => ApiService.dio.post("/env-reports/$id/confirm");

  Future<String> submit({
    required List<File> photos,
    required String category,
    required String description,
    required String landmark,
    required String emirate,
    required double lat,
    required double lng,
    double? accuracyM,
  }) async {
    final form = FormData();
    for (final f in photos) {
      final name = f.path.split(Platform.pathSeparator).last;
      form.files.add(MapEntry(
        "photos",
        await MultipartFile.fromFile(f.path, filename: name, contentType: MediaType("image", name.toLowerCase().endsWith(".png") ? "png" : "jpeg")),
      ));
    }
    form.fields
      ..add(MapEntry("category", category))
      ..add(MapEntry("description", description))
      ..add(MapEntry("landmark", landmark))
      ..add(MapEntry("emirate", emirate))
      ..add(MapEntry("lat", lat.toString()))
      ..add(MapEntry("lng", lng.toString()));
    if (accuracyM != null) form.fields.add(MapEntry("accuracyM", accuracyM.toStringAsFixed(0)));
    final res = await ApiService.dio.post(
      "/env-reports",
      data: form,
      options: Options(sendTimeout: const Duration(minutes: 2), receiveTimeout: const Duration(minutes: 2)),
    );
    return res.data["message"]?.toString() ?? "Report submitted";
  }
}

final issueApiProvider = Provider((ref) => IssueApi());

final myIssuesProvider = FutureProvider<List<IssueReport>>((ref) => ref.read(issueApiProvider).mine());

final nearbyIssuesProvider = FutureProvider<List<IssueReport>>((ref) => ref.read(issueApiProvider).nearby());
