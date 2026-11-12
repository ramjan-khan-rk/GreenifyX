import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/api_service.dart';

typedef Json = Map<String, dynamic>;

List<Json> _maps(dynamic v) => (v as List? ?? const []).whereType<Map>().map((e) => Json.from(e)).toList();

class OrgApi {
  Future<List<Json>> mine() async => _maps((await ApiService.dio.get("/orgs/mine")).data["organizations"]);

  Future<Json> join(String code) async =>
      Json.from((await ApiService.dio.post("/orgs/join", data: {"code": code})).data["organization"] as Map);

  Future<String> register(Json body) async => (await ApiService.dio.post("/orgs", data: body)).data["message"]?.toString() ?? "Submitted";

  Future<void> leave(String id) => ApiService.dio.post("/orgs/$id/leave");

  Future<Json> dashboard(String id) async => Json.from((await ApiService.dio.get("/orgs/$id/dashboard")).data as Map);

  Future<List<Json>> leaderboard() async => _maps((await ApiService.dio.get("/orgs/leaderboard")).data["organizations"]);
}

final orgApiProvider = Provider((ref) => OrgApi());
final myOrgsProvider = FutureProvider<List<Json>>((ref) => ref.read(orgApiProvider).mine());
final orgLeaderboardProvider = FutureProvider<List<Json>>((ref) => ref.read(orgApiProvider).leaderboard());
final orgDashboardProvider = FutureProvider.family<Json, String>((ref, id) => ref.read(orgApiProvider).dashboard(id));
