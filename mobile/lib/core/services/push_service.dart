import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';

import '../../features/chat/application/call_native.dart';
import '../routes/app_router.dart';
import '../utils/chat_launcher.dart';
import 'api_service.dart';

/// Runs in the background (even when the app was closed) for data pushes:
/// a friend's call rings here with the phone's own incoming-call screen.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  await CallNative.handlePush(message.data);
}

/// Firebase push: registers this phone with the backend and opens the right
/// screen when a notification is tapped. Safe to call more than once.
class PushService {
  PushService._();
  static final instance = PushService._();

  bool _ready = false;
  String? _token;

  Future<void> register() async {
    try {
      if (!_ready) {
        await Firebase.initializeApp();
        _ready = true;
        FirebaseMessaging.instance.onTokenRefresh.listen(_send);
        FirebaseMessaging.onMessageOpenedApp.listen(_open);
        // A ring push while the app is open (e.g. the call connection was briefly down).
        FirebaseMessaging.onMessage.listen((m) => CallNative.handlePush(m.data));
        final initial = await FirebaseMessaging.instance.getInitialMessage();
        if (initial != null) {
          // Wait for the first screen before navigating.
          WidgetsBinding.instance.addPostFrameCallback((_) => _open(initial));
        }
      }
      final perm = await FirebaseMessaging.instance.requestPermission();
      if (perm.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _send(token);
    } catch (e) {
      debugPrint("Push setup skipped: $e");
    }
  }

  Future<void> _send(String token) async {
    _token = token;
    try {
      await ApiService.dio.post("/users/me/push-token", data: {"token": token, "platform": Platform.isIOS ? "ios" : "android"});
    } catch (_) {}
  }

  /// Call before logging out so this phone stops getting that account's alerts.
  Future<void> unregister() async {
    final t = _token;
    if (t == null) return;
    try {
      await ApiService.dio.delete("/users/me/push-token", data: {"token": t});
    } catch (_) {}
    _token = null;
  }

  void _open(RemoteMessage m) {
    final ctx = AppRouter.router.routerDelegate.navigatorKey.currentContext;
    if (ctx == null) return;
    final type = m.data["type"]?.toString() ?? "";
    final sender = m.data["senderId"]?.toString() ?? "";
    if ((type == "message" || type == "call") && sender.isNotEmpty) {
      var name = m.notification?.title ?? "Friend";
      if (type == "call") name = "Friend";
      openChat(ctx, userId: sender, name: name);
    }
    // Other types land on the home screen, where the notification bell shows them.
  }
}
