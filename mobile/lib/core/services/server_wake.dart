import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import '../config/app_config.dart';

/// The free server sleeps when nobody uses it and takes up to a minute to wake.
/// This pings it at launch (with a friendly message instead of an error),
/// and again whenever the app comes back to the foreground, so it is warm
/// before people tap anything.
class ServerWake with WidgetsBindingObserver {
  ServerWake._();
  static final instance = ServerWake._();

  final _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 12), receiveTimeout: const Duration(seconds: 12)));
  DateTime _lastOk = DateTime.fromMillisecondsSinceEpoch(0);
  bool _observing = false;

  Future<bool> ping() async {
    try {
      final r = await _dio.get("${AppConfig.origin}/health");
      final ok = (r.statusCode ?? 0) < 400;
      if (ok) _lastOk = DateTime.now();
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// Keeps trying for up to [maxWait]; [onSlow] fires once if it takes a while.
  Future<bool> ensureAwake({Duration maxWait = const Duration(seconds: 90), VoidCallback? onSlow}) async {
    _observe();
    if (DateTime.now().difference(_lastOk) < const Duration(minutes: 5)) return true;
    final started = DateTime.now();
    var warned = false;
    while (DateTime.now().difference(started) < maxWait) {
      final slowTimer = warned ? null : Timer(const Duration(seconds: 3), () {
        warned = true;
        onSlow?.call();
      });
      final ok = await ping();
      slowTimer?.cancel();
      if (ok) return true;
      if (!warned) {
        warned = true;
        onSlow?.call();
      }
      await Future.delayed(const Duration(seconds: 3));
    }
    return false;
  }

  void _observe() {
    if (_observing) return;
    _observing = true;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && DateTime.now().difference(_lastOk) > const Duration(minutes: 5)) {
      ping();
    }
  }
}

/// Retries reads that fail while the server is starting (timeouts, 502/503/504).
class WakeRetry extends Interceptor {
  WakeRetry(this.dio);
  final Dio dio;

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final o = err.requestOptions;
    final tries = (o.extra["wakeTries"] as int?) ?? 0;
    final code = err.response?.statusCode ?? 0;
    final waking = err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        code == 502 ||
        code == 503 ||
        code == 504;
    if (o.method.toUpperCase() == "GET" && waking && tries < 2) {
      await Future.delayed(Duration(seconds: 3 * (tries + 1)));
      o.extra["wakeTries"] = tries + 1;
      try {
        return handler.resolve(await dio.fetch(o));
      } on DioException catch (e) {
        return handler.next(e);
      }
    }
    handler.next(err);
  }
}
