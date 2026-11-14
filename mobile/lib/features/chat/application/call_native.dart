import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:just_audio/just_audio.dart';

/// The phone's own call system around our WebRTC calls:
///  - the native incoming-call screen with the phone's ringtone (also on the lock
///    screen and when the app is closed), via CallKit on iPhone and a full-screen
///    call notification on Android;
///  - the ringback tone the caller hears while it rings;
///  - keeping the microphone (and camera) running while the person uses other apps.
class CallNative {
  CallNative._();

  static bool get _mobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static AudioPlayer? _ringback;
  static bool _fgInit = false;

  static CallKitParams _params({
    required String id,
    required String name,
    required bool video,
    Map<String, dynamic> extra = const {},
  }) =>
      CallKitParams(
        id: id,
        nameCaller: name,
        appName: "GreenifyX",
        handle: "GreenifyX",
        type: video ? 1 : 0,
        duration: 45000,
        extra: extra,
        missedCallNotification: const NotificationParams(showNotification: true, isShowCallback: false, subtitle: "Missed call"),
        callingNotification: const NotificationParams(showNotification: true, isShowCallback: true, subtitle: "On a call", callbackText: "Hang up"),
        android: const AndroidParams(
          isCustomNotification: true,
          isShowLogo: false,
          ringtonePath: "system_ringtone_default",
          backgroundColor: "#2B2440",
          actionColor: "#1F8A70",
          textColor: "#ffffff",
          incomingCallNotificationChannelName: "Incoming calls",
          missedCallNotificationChannelName: "Missed calls",
          isShowCallID: false,
        ),
        ios: IOSParams(
          handleType: "generic",
          supportsVideo: true,
          maximumCallGroups: 1,
          maximumCallsPerCallGroup: 1,
          audioSessionMode: video ? "videoChat" : "voiceChat",
          audioSessionActive: true,
          supportsDTMF: false,
          supportsHolding: false,
          supportsGrouping: false,
          supportsUngrouping: false,
          ringtonePath: "system_ringtone_default",
        ),
      );

  /// Ring with the phone's own incoming-call screen and ringtone.
  static Future<void> showIncoming({required String id, required String name, required bool video, Map<String, dynamic> extra = const {}}) async {
    if (!_mobile) return;
    try {
      await FlutterCallkitIncoming.showCallkitIncoming(_params(id: id, name: name, video: video, extra: extra));
    } catch (e) {
      debugPrint("[call] native ring failed: $e");
    }
  }

  /// Tell the phone we're placing a call (shows in the call list, keeps audio alive on iPhone).
  static Future<void> startOutgoing({required String id, required String name, required bool video}) async {
    if (!_mobile) return;
    try {
      await FlutterCallkitIncoming.startCall(_params(id: id, name: name, video: video));
    } catch (_) {}
  }

  static Future<void> connected(String id) async {
    if (!_mobile) return;
    try {
      await FlutterCallkitIncoming.setCallConnected(id);
    } catch (_) {}
  }

  static Future<void> end(String id) async {
    if (!_mobile) return;
    try {
      await FlutterCallkitIncoming.endCall(id);
    } catch (_) {}
  }

  /// Ask once for the permissions ringing needs (Android 13+ notifications, Android 14+ full screen).
  static Future<void> requestPermissions() async {
    if (!_mobile) return;
    try {
      await FlutterCallkitIncoming.requestNotificationPermission({
        "title": "Allow call notifications",
        "rationaleMessagePermission": "GreenifyX needs notifications to ring when a friend calls.",
        "postNotificationMessageRequired": "Allow notifications in Settings so calls can ring.",
      });
      if (Platform.isAndroid && !(await FlutterCallkitIncoming.canUseFullScreenIntent())) {
        await FlutterCallkitIncoming.requestFullIntentPermission();
      }
    } catch (_) {}
  }

  /// iPhone VoIP push token (lets a closed iPhone ring). Empty on Android.
  static Future<String> voipToken() async {
    if (!_mobile || !Platform.isIOS) return "";
    try {
      return (await FlutterCallkitIncoming.getDevicePushTokenVoIP())?.toString() ?? "";
    } catch (_) {
      return "";
    }
  }

  // ---------- ringback for the caller ----------

  static Future<void> playRingback() async {
    try {
      _ringback ??= AudioPlayer();
      await _ringback!.setAsset("assets/sounds/ringback.wav");
      await _ringback!.setLoopMode(LoopMode.one);
      unawaited(_ringback!.play());
    } catch (e) {
      debugPrint("[call] ringback failed: $e");
    }
  }

  static Future<void> stopRingback() async {
    try {
      await _ringback?.stop();
    } catch (_) {}
  }

  // ---------- staying on the call in other apps (Android) ----------

  /// Keeps the microphone (and camera for video) working while the app is in the background.
  /// iPhone does this through CallKit and the audio background mode.
  static Future<void> startBackgroundService({required String peerName, required bool video}) async {
    if (!_mobile || !Platform.isAndroid) return;
    try {
      if (!_fgInit) {
        FlutterForegroundTask.init(
          androidNotificationOptions: AndroidNotificationOptions(
            channelId: "greenifyx_ongoing_call",
            channelName: "Ongoing call",
            channelDescription: "Shown while you're on a GreenifyX call",
            onlyAlertOnce: true,
          ),
          iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
          foregroundTaskOptions: ForegroundTaskOptions(eventAction: ForegroundTaskEventAction.nothing(), allowWakeLock: true, allowWifiLock: true),
        );
        _fgInit = true;
      }
      if (await FlutterForegroundTask.isRunningService) return;
      await FlutterForegroundTask.startService(
        serviceId: 4471,
        serviceTypes: [ForegroundServiceTypes.microphone, if (video) ForegroundServiceTypes.camera],
        notificationTitle: "On a call with $peerName",
        notificationText: "Tap to return to the call",
        callback: callServiceStart,
      );
    } catch (e) {
      debugPrint("[call] background service failed: $e");
    }
  }

  static Future<void> stopBackgroundService() async {
    if (!_mobile || !Platform.isAndroid) return;
    try {
      if (await FlutterForegroundTask.isRunningService) await FlutterForegroundTask.stopService();
    } catch (_) {}
  }

  // ---------- lock-screen decline ----------

  /// Decline a call that rang while the app was closed, using the one-time token from the push.
  static Future<void> declineByToken(Map<String, dynamic>? extra, String callId) async {
    final api = extra?["api"]?.toString() ?? "";
    final token = extra?["declineToken"]?.toString() ?? "";
    if (api.isEmpty || token.isEmpty) return;
    try {
      await Dio().post("$api/calls/decline", data: {"callId": callId, "token": token});
    } catch (_) {}
  }

  /// Handle a ring push (from Firebase, in the foreground or a background isolate).
  static Future<void> handlePush(Map<String, dynamic> data) async {
    final type = data["type"]?.toString() ?? "";
    final id = data["id"]?.toString() ?? "";
    if (id.isEmpty) return;
    if (type == "incoming_call") {
      await showIncoming(
        id: id,
        name: data["nameCaller"]?.toString() ?? "Friend",
        video: data["isVideo"]?.toString() == "true",
        extra: {
          "callerId": data["callerId"]?.toString() ?? "",
          "declineToken": data["declineToken"]?.toString() ?? "",
          "api": data["api"]?.toString() ?? "",
        },
      );
    } else if (type == "call_cancel") {
      await end(id);
    }
  }
}

/// Entry point the Android foreground service needs; the call itself runs in the app.
@pragma('vm:entry-point')
void callServiceStart() {
  FlutterForegroundTask.setTaskHandler(_IdleCallTask());
}

class _IdleCallTask extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}
