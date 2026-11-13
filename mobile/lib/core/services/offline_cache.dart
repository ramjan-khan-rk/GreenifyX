import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Keeps the last good copy of key screens (feed, chats, profile, map...) on the
/// phone. When the network drops, those requests are answered from disk and a
/// small "offline" banner appears, so the app never shows a blank page.
class OfflineCache extends Interceptor {
  OfflineCache._();
  static final instance = OfflineCache._();

  /// True while the last request had to be served from the saved copy.
  static final offline = ValueNotifier<bool>(false);

  static const _cacheable = [
    "/posts", "/feed", "/foryou", "/chats", "/messages", "/users/me", "/profile", "/auth/me",
    "/activities", "/map", "/notifications", "/friends", "/rewards", "/events", "/stories",
    "/challenges", "/communities", "/home", "/points", "/campaigns", "/trending", "/market",
  ];
  static const _maxBytes = 1500000;

  Directory? _dir;

  Future<Directory> _folder() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationSupportDirectory();
    final d = Directory("${base.path}${Platform.pathSeparator}api_cache");
    if (!d.existsSync()) d.createSync(recursive: true);
    return _dir = d;
  }

  static bool _eligible(RequestOptions o) =>
      o.method.toUpperCase() == "GET" && _cacheable.any((p) => o.path.startsWith(p)) && o.extra["noCache"] != true;

  /// Stable FNV-1a hash so the file name is the same on every launch.
  static String _key(RequestOptions o) {
    final q = o.queryParameters.entries.map((e) => "${e.key}=${e.value}").toList()..sort();
    final s = "${o.path}?${q.join("&")}";
    var h = 0x811c9dc5;
    for (final c in utf8.encode(s)) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return "${h.toRadixString(16)}_${s.length}.json";
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final o = response.requestOptions;
    if (offline.value) offline.value = false;
    if (!kIsWeb && _eligible(o) && (response.statusCode ?? 0) < 300 && response.data is Map) {
      () async {
        try {
          final body = jsonEncode(response.data);
          if (body.length > _maxBytes) return;
          final f = File("${(await _folder()).path}${Platform.pathSeparator}${_key(o)}");
          await f.writeAsString(body, flush: false);
        } catch (_) {}
      }();
    }
    handler.next(response);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final o = err.requestOptions;
    final network = err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        (err.type == DioExceptionType.unknown && err.error is SocketException);
    if (!kIsWeb && network && _eligible(o)) {
      try {
        final f = File("${(await _folder()).path}${Platform.pathSeparator}${_key(o)}");
        if (await f.exists()) {
          final data = jsonDecode(await f.readAsString());
          offline.value = true;
          return handler.resolve(Response(requestOptions: o, data: data, statusCode: 200, extra: {"fromCache": true}));
        }
      } catch (_) {}
    }
    if (network) offline.value = true;
    handler.next(err);
  }

  /// Wipe saved copies (on logout, so the next person never sees them).
  static Future<void> clear() async {
    try {
      final d = await instance._folder();
      if (d.existsSync()) d.deleteSync(recursive: true);
      instance._dir = null;
    } catch (_) {}
  }
}
