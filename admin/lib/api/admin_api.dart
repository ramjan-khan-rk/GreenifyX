import 'package:dio/dio.dart';

import '../core/config.dart';

typedef Json = Map<String, dynamic>;

class ApiError implements Exception {
  ApiError(this.message, {this.status});
  final String message;
  final int? status;

  @override
  String toString() => message;
}

/// A page of results from a list endpoint.
class Paged {
  Paged({required this.items, required this.total, required this.page, required this.limit});
  final List<Json> items;
  final int total;
  final int page;
  final int limit;

  int get pages => total == 0 ? 1 : ((total + limit - 1) ~/ limit);
}

class AdminApi {
  AdminApi({String? token}) : _token = token {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final t = _token;
          if (t != null && t.isNotEmpty) options.headers['Authorization'] = 'Bearer $t';
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AdminConfig.apiBase,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  String? _token;
  set token(String? value) => _token = value;

  /// Called when the API says the session is no longer valid.
  void Function()? onUnauthorized;

  Future<Json> _send(Future<Response<dynamic>> Function() call) async {
    try {
      final res = await call();
      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      throw ApiError('Unexpected response from server');
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      final serverMessage = body is Map ? body['message']?.toString() : null;
      if (status == 401) onUnauthorized?.call();
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw ApiError('Cannot reach the server. It may be waking up, try again in a moment.');
      }
      throw ApiError(serverMessage ?? 'Request failed (${status ?? 'network'})', status: status);
    }
  }

  Paged _paged(Json data, String key) => Paged(
        items: List<Json>.from((data[key] as List? ?? const []).map((e) => Json.from(e as Map))),
        total: (data['total'] as num?)?.toInt() ?? 0,
        page: (data['page'] as num?)?.toInt() ?? 1,
        limit: (data['limit'] as num?)?.toInt() ?? 20,
      );

  Future<String> login(String email, String password) async {
    final data = await _send(() => _dio.post('/auth/login', data: {'email': email, 'password': password}));
    final token = data['token']?.toString();
    if (token == null || token.isEmpty) throw ApiError('Login failed');
    return token;
  }

  Future<Json> me() async => Json.from((await _send(() => _dio.get('/admin/me')))['admin'] as Map);

  Future<Json> stats() => _send(() => _dio.get('/admin/stats'));

  Future<Paged> users({String q = '', String status = 'all', String emirate = '', String sort = 'recent', int page = 1, int limit = 20}) async {
    final data = await _send(() => _dio.get('/admin/users', queryParameters: {
          if (q.isNotEmpty) 'q': q,
          'status': status,
          if (emirate.isNotEmpty) 'emirate': emirate,
          'sort': sort,
          'page': page,
          'limit': limit,
        }));
    return _paged(data, 'users');
  }

  Future<Json> user(String id) async => Json.from((await _send(() => _dio.get('/admin/users/$id')))['user'] as Map);

  Future<Json> setSuspended(String id, bool suspended, {String reason = ''}) async {
    final data = await _send(() => _dio.patch('/admin/users/$id/status', data: {'suspended': suspended, 'reason': reason}));
    return Json.from(data['user'] as Map);
  }

  Future<Paged> posts({String filter = 'all', String q = '', int page = 1, int limit = 20}) async {
    final data = await _send(() => _dio.get('/admin/posts', queryParameters: {
          'filter': filter,
          if (q.isNotEmpty) 'q': q,
          'page': page,
          'limit': limit,
        }));
    return _paged(data, 'posts');
  }

  Future<Json> moderate(String id, String action) async {
    final data = await _send(() => _dio.patch('/admin/posts/$id/moderate', data: {'action': action}));
    return Json.from(data['post'] as Map);
  }

  Future<String> setRole(String id, String role) async {
    final data = await _send(() => _dio.patch('/admin/users/$id/role', data: {'role': role}));
    return data['role']?.toString() ?? role;
  }

  // ---- Campaigns & verification ----

  Future<Paged> campaigns({String status = '', String q = '', int page = 1, int limit = 20}) async {
    final data = await _send(() => _dio.get('/admin/campaigns', queryParameters: {
          if (status.isNotEmpty) 'status': status,
          if (q.isNotEmpty) 'q': q,
          'page': page,
          'limit': limit,
        }));
    return _paged(data, 'campaigns');
  }

  Future<Json> createCampaign(Json body) async =>
      Json.from((await _send(() => _dio.post('/admin/campaigns', data: body)))['campaign'] as Map);

  Future<Json> updateCampaign(String id, Json body) async =>
      Json.from((await _send(() => _dio.patch('/admin/campaigns/$id', data: body)))['campaign'] as Map);

  Future<Json> setCampaignVerifiers(String id, List<String> verifierIds) async => Json.from(
      (await _send(() => _dio.put('/admin/campaigns/$id/verifiers', data: {'verifierIds': verifierIds})))['campaign'] as Map);

  Future<List<Json>> verifiers() async {
    final data = await _send(() => _dio.get('/admin/verifiers'));
    return List<Json>.from((data['verifiers'] as List? ?? const []).map((e) => Json.from(e as Map)));
  }

  Future<Paged> reports({String status = 'pending', int page = 1, int limit = 12}) async {
    final data = await _send(() => _dio.get('/admin/reports', queryParameters: {'status': status, 'page': page, 'limit': limit}));
    return _paged(data, 'reports');
  }

  Future<Json> reviewReport(String id, {required bool approve, String note = ''}) async => Json.from((await _send(
          () => _dio.patch('/admin/reports/$id/review', data: {'decision': approve ? 'approve' : 'reject', 'note': note})))['report']
      as Map);

  Future<({Paged page, int credited, int reversed})> transactions({String type = '', int page = 1, int limit = 25}) async {
    final data = await _send(() => _dio.get('/admin/points', queryParameters: {
          if (type.isNotEmpty) 'type': type,
          'page': page,
          'limit': limit,
        }));
    final totals = Json.from(data['totals'] as Map? ?? const {});
    return (
      page: _paged(data, 'transactions'),
      credited: (totals['credited'] as num?)?.toInt() ?? 0,
      reversed: (totals['reversed'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> reverseTransaction(String id, String reason) async {
    await _send(() => _dio.post('/admin/points/$id/reverse', data: {'reason': reason}));
  }

  // ---- Report & Restore ----

  Future<({Paged page, Map<String, int> counts})> issues({String status = 'open', String category = '', int page = 1, int limit = 12}) async {
    final data = await _send(() => _dio.get('/admin/env-reports', queryParameters: {
          'status': status,
          if (category.isNotEmpty) 'category': category,
          'page': page,
          'limit': limit,
        }));
    final counts = <String, int>{};
    (data['counts'] as Map? ?? const {}).forEach((k, v) => counts[k.toString()] = (v as num).toInt());
    return (page: _paged(data, 'reports'), counts: counts);
  }

  Future<Json> updateIssue(String id, String status, {String note = '', String forwardedTo = ''}) async => Json.from((await _send(
          () => _dio.patch('/admin/env-reports/$id/status', data: {'status': status, 'note': note, 'forwardedTo': forwardedTo})))['report']
      as Map);

  // ---- Eco places (Smart Eco Map) ----

  Future<List<Json>> places() async {
    final data = await _send(() => _dio.get('/admin/places'));
    return List<Json>.from((data['places'] as List? ?? const []).map((e) => Json.from(e as Map)));
  }

  Future<Json> createPlace(Json body) async =>
      Json.from((await _send(() => _dio.post('/admin/places', data: body)))['place'] as Map);

  Future<Json> updatePlace(String id, Json body) async =>
      Json.from((await _send(() => _dio.patch('/admin/places/$id', data: body)))['place'] as Map);

  // ---- AI copilot ----

  Future<({String text, String mode})> insights(String kind, {int days = 30}) async {
    final data = await _send(() => _dio.post(
          '/admin/ai/insights',
          data: {'kind': kind, 'days': days},
          options: Options(receiveTimeout: const Duration(seconds: 90)),
        ));
    return (text: data['text']?.toString() ?? '', mode: data['mode']?.toString() ?? 'template');
  }

  // ---- Organisations ----

  Future<({Paged page, Map<String, int> counts})> orgs({String status = '', int page = 1}) async {
    final data = await _send(() => _dio.get('/admin/orgs', queryParameters: {
          if (status.isNotEmpty) 'status': status,
          'page': page,
        }));
    final counts = <String, int>{};
    (data['counts'] as Map? ?? const {}).forEach((k, v) => counts[k.toString()] = (v as num).toInt());
    return (page: _paged(data, 'organizations'), counts: counts);
  }

  Future<Json> setOrgStatus(String id, String status, {String note = ''}) async => Json.from(
      (await _send(() => _dio.patch('/admin/orgs/$id/status', data: {'status': status, 'note': note})))['organization'] as Map);

  Future<List<Json>> orgOptions() async {
    final data = await _send(() => _dio.get('/admin/orgs/options'));
    return List<Json>.from((data['organizations'] as List? ?? const []).map((e) => Json.from(e as Map)));
  }

  Future<Paged> challenges({String status = '', int page = 1, int limit = 20}) async {
    final data = await _send(() => _dio.get('/admin/challenges', queryParameters: {
          if (status.isNotEmpty) 'status': status,
          'page': page,
          'limit': limit,
        }));
    return _paged(data, 'challenges');
  }

  // ---- Rewards ----
  List<Json> _maps(dynamic v) => List<Json>.from((v as List? ?? const []).map((e) => Json.from(e as Map)));

  Future<Json> rewards() async => await _send(() => _dio.get('/admin/rewards'));

  Future<void> createReward(Json body) async => _send(() => _dio.post('/admin/rewards', data: body));

  Future<void> updateReward(String id, Json body) async => _send(() => _dio.patch('/admin/rewards/$id', data: body));

  Future<List<Json>> redemptions({String status = '', String code = ''}) async => _maps((await _send(() => _dio.get(
        '/admin/redemptions',
        queryParameters: {if (status.isNotEmpty) 'status': status, if (code.isNotEmpty) 'code': code},
      )))['redemptions']);

  Future<void> updateRedemption(String id, String status) async =>
      _send(() => _dio.patch('/admin/redemptions/$id', data: {'status': status}));

  // ---- Recycling pickups ----
  Future<Json> pickups({String status = ''}) async =>
      await _send(() => _dio.get('/admin/pickups', queryParameters: {if (status.isNotEmpty) 'status': status}));

  Future<void> updatePickup(String id, Json body) async => _send(() => _dio.patch('/admin/pickups/$id', data: body));

  // ---- Events ----
  Future<List<Json>> events() async => _maps((await _send(() => _dio.get('/admin/events')))['events']);

  Future<void> createEvent(Json body) async => _send(() => _dio.post('/admin/events', data: body));

  Future<void> updateEvent(String id, Json body) async => _send(() => _dio.patch('/admin/events/$id', data: body));

  // ---- Eco activities ----
  Future<List<Json>> activities() async => _maps((await _send(() => _dio.get('/admin/activities')))['activities']);

  Future<void> createActivity(Json body) async => _send(() => _dio.post('/admin/activities', data: body));

  Future<void> updateActivity(String id, Json body) async => _send(() => _dio.patch('/admin/activities/$id', data: body));

  // ---- Public website (no login) ----
  Future<Json> publicStats() async => await _send(() => _dio.get('/public/stats'));

  Future<String> sendEnquiry(Json body) async =>
      (await _send(() => _dio.post('/public/org-enquiry', data: body)))['message']?.toString() ?? 'Thank you!';

  // ---- Website enquiries (admin) ----
  Future<List<Json>> enquiries() async => _maps((await _send(() => _dio.get('/admin/enquiries')))['enquiries']);

  Future<void> updateEnquiry(String id, Json body) async => _send(() => _dio.patch('/admin/enquiries/$id', data: body));

  // ---- QR check-in points ----
  Future<List<Json>> checkpoints() async => _maps((await _send(() => _dio.get('/admin/checkpoints')))['checkpoints']);

  Future<void> createCheckpoint(Json body) async => _send(() => _dio.post('/admin/checkpoints', data: body));

  Future<void> updateCheckpoint(String id, Json body) async => _send(() => _dio.patch('/admin/checkpoints/$id', data: body));

  // ---- Public certificate check ----
  Future<Json> certificate(String code) async => Json.from((await _send(() => _dio.get('/public/certificates/$code')))['certificate'] as Map);

  // ---- Verified badges ----
  Future<List<Json>> badgeUsers() async => _maps((await _send(() => _dio.get('/admin/badges')))['users']);

  Future<void> decideBadge(String userId, String action, {String? type}) async =>
      _send(() => _dio.patch('/admin/badges/$userId', data: {'action': action, 'type': ?type}));

  // ---- Sponsored challenges ----
  Future<List<Json>> sponsored() async => _maps((await _send(() => _dio.get('/admin/sponsored')))['challenges']);

  Future<void> createSponsored(Json body) async => _send(() => _dio.post('/admin/sponsored', data: body));

  Future<void> updateSponsored(String id, Json body) async => _send(() => _dio.patch('/admin/sponsored/$id', data: body));

  // ---- ESG ----
  Future<Json> orgEsg(String orgId) async => await _send(() => _dio.get('/admin/orgs/$orgId/esg'));

  Future<Json> publicEsg(String token) async => Json.from((await _send(() => _dio.get('/public/esg/$token')))['report'] as Map);
}
