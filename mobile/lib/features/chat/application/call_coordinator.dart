import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import 'dart:math';

import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/socket_service.dart';
import 'call_native.dart';

/// One-to-one voice/video calls over WebRTC, signalled through the app's socket.
///
/// Phases: idle → ringing (outgoing) | incoming → connecting → live → ended → idle.
/// "ended" is shown briefly with the reason before the call screen closes.
class CallCoordinator extends ChangeNotifier {
  CallCoordinator._();

  static final CallCoordinator instance = CallCoordinator._();

  static const _ringTimeout = Duration(seconds: 45);
  static const _fallbackIce = [
    {"urls": ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"]},
  ];

  String phase = "idle";
  String peerId = "";
  String peerName = "Friend";
  bool video = false;
  bool outgoing = false;
  String detail = "";

  bool muted = false;
  bool speakerOn = false;
  bool cameraOff = false;
  DateTime? connectedAt;

  RTCPeerConnection? _pc;
  MediaStream? _local;
  final localRenderer = RTCVideoRenderer();
  final remoteRenderer = RTCVideoRenderer();
  final List<RTCIceCandidate> _ice = [];
  Map<String, dynamic>? _pendingOffer;
  List<dynamic>? _iceServers;
  Timer? _ringTimer;
  Timer? _closeTimer;
  Timer? _connectTimer;
  bool _ready = false;
  bool _bound = false;
  bool _remoteReady = false;

  bool get busy => phase != "idle" && phase != "ended";

  /// Step-by-step call log: printed to the debug console as [call] lines and
  /// kept here (last 60) so the call screen can show what stopped a call.
  final List<String> log = [];

  /// While the details panel is open, an ended call stays on screen until closed.
  bool holdOpen = false;

  void closeEnded() {
    holdOpen = false;
    if (phase == "ended") {
      phase = "idle";
      notifyListeners();
    }
  }
  final Map<String, int> _candidateKinds = {};

  void _log(String what) {
    final t = DateTime.now();
    final line = "${t.hour.toString().padLeft(2, "0")}:${t.minute.toString().padLeft(2, "0")}:${t.second.toString().padLeft(2, "0")} $what";
    debugPrint("[call] $line");
    // Also to the server log (Render → Logs), so a failed call can be traced there.
    try {
      SocketService.instance.emit("call:log", {"line": what});
    } catch (_) {}
    log.add(line);
    if (log.length > 60) log.removeAt(0);
  }

  /// host = same Wi-Fi, srflx = through the internet (STUN), relay = through a TURN server.
  void _countCandidate(String? c, String side) {
    final m = RegExp(r" typ (\w+)").firstMatch(c ?? "");
    final kind = "$side ${m?.group(1) ?? "?"}";
    _candidateKinds[kind] = (_candidateKinds[kind] ?? 0) + 1;
  }

  String get _candidateSummary => _candidateKinds.isEmpty ? "none" : _candidateKinds.entries.map((e) => "${e.key} x${e.value}").join(", ");

  void _onRaw(dynamic raw) {
    if (raw is Map) unawaited(_onSignal(Map<String, dynamic>.from(raw)));
  }

  /// This call's id, shared with the phone's own call screen (CallKit / Android call UI).
  String callId = "";
  /// Answered or declined on the phone's own call screen before the call reached the app.
  final Map<String, String> _nativeChoice = {};
  bool _nativeAnswered = false;
  StreamSubscription<dynamic>? _nativeEvents;

  static String _newId() {
    final r = Random.secure();
    String hex(int n) => List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
    return "${hex(8)}-${hex(4)}-4${hex(3)}-a${hex(3)}-${hex(12)}";
  }

  /// Safe to call many times; the socket registry keeps the listener across reconnects.
  void bind() {
    if (_bound) return;
    _bound = true;
    SocketService.instance.on("call:signal", _onRaw);
    // Ask the server for any call that rang while the app was closed, now and after every reconnect.
    if (SocketService.instance.isConnected) SocketService.instance.emit("call:ready", {});
    SocketService.instance.status.listen((ok) {
      if (ok) SocketService.instance.emit("call:ready", {});
    });
    _nativeEvents = FlutterCallkitIncoming.onEvent.listen(_onNative, onError: (_) {});
    unawaited(_resumeNativeAccept());
    unawaited(CallNative.requestPermissions());
    unawaited(_registerVoip());
  }

  /// The app was opened by tapping Accept on the lock screen: answer as soon as the call arrives.
  Future<void> _resumeNativeAccept() async {
    try {
      for (final c in await FlutterCallkitIncoming.activeCalls()) {
        final from = c.extra?["callerId"]?.toString() ?? "";
        if (from.isNotEmpty && c.isAccepted) {
          _nativeChoice[from] = "accept";
          _log("answered on the lock screen, waiting for the call to arrive");
        }
      }
    } catch (_) {}
  }

  Future<void> _registerVoip() async {
    final token = await CallNative.voipToken();
    if (token.isEmpty) return;
    try {
      await ApiService.dio.post("/users/me/push-token", data: {"token": token, "platform": "ios_voip"});
    } catch (_) {}
  }

  /// Taps on the phone's own call screen.
  void _onNative(CallEvent? e) {
    if (e == null) return;
    switch (e) {
      case CallEventActionCallAccept(:final callKitParams):
        final from = callKitParams.extra?["callerId"]?.toString() ?? peerId;
        _log("accepted on the phone's call screen");
        _nativeAnswered = true;
        if (phase == "incoming" && from == peerId) {
          unawaited(accept());
        } else {
          _nativeChoice[from] = "accept";
        }
      case CallEventActionCallDecline(:final callKitParams):
        final from = callKitParams.extra?["callerId"]?.toString() ?? peerId;
        _log("declined on the phone's call screen");
        if (phase == "incoming" && from == peerId) {
          unawaited(reject());
        } else {
          // The app wasn't handling this call yet: decline it on the server.
          unawaited(CallNative.declineByToken(callKitParams.extra, callKitParams.id));
        }
      case CallEventActionCallEnded():
        if (busy) unawaited(hangUp());
      case CallEventActionCallTimeout():
        if (phase == "incoming") _endWith("Missed call");
      default:
        break;
    }
  }

  @override
  void dispose() {
    _nativeEvents?.cancel();
    super.dispose();
  }

  Future<void> start({required String userId, required String userName, required bool withVideo}) async {
    if (busy) {
      _log("start ignored: already on a call ($phase)");
      return;
    }
    _closeTimer?.cancel();
    _resetFlags();
    log.clear();
    holdOpen = false;
    _candidateKinds.clear();
    _log("calling $userName (${withVideo ? "video" : "voice"})");
    callId = _newId();
    _nativeAnswered = false;
    peerId = userId;
    peerName = userName;
    video = withVideo;
    outgoing = true;
    phase = "ringing";
    detail = withVideo ? "Starting video call…" : "Calling…";
    notifyListeners();

    bind();
    if (!await SocketService.instance.ensureConnected()) {
      _log("STOPPED: socket not connected (offline or server asleep)");
      phase = "ended";
      detail = "You're offline. Check your internet and try again.";
      notifyListeners();
      return;
    }

    _log("socket connected");
    await _ensureMedia();
    if (_local == null) {
      _log("STOPPED: no microphone/camera (permission denied or device busy)");
      phase = "ended";
      detail = withVideo ? "Allow the camera and microphone to call." : "Allow the microphone to call.";
      notifyListeners();
      return;
    }
    try {
      await _peer();
      _log("creating offer");
      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);
      _send("offer", sdp: {"type": offer.type, "sdp": offer.sdp});
    } catch (e) {
      // Used to fail silently and leave the screen on "Calling…" forever.
      _log("STOPPED: could not set up the call: $e");
      _endWith("Couldn't start the call. Open Call details for the reason.");
      return;
    }
    _log("offer sent, waiting for answer");
    unawaited(CallNative.startOutgoing(id: callId, name: peerName, video: video));
    unawaited(CallNative.playRingback());
    detail = "Ringing…";
    notifyListeners();
    _ringTimer = Timer(_ringTimeout, () {
      if (phase == "ringing") {
        _log("STOPPED: no answer in ${_ringTimeout.inSeconds}s");
        _endWith("No answer", notifyPeer: true);
      }
    });
  }

  /// If the two phones can't reach each other (usually mobile data without a
  /// relay server), say so instead of showing "Connecting…" forever.
  void _watchConnect() {
    _connectTimer?.cancel();
    _connectTimer = Timer(const Duration(seconds: 25), () {
      if (phase == "connecting") {
        _log("STOPPED: phones could not reach each other in 25s. Candidates: $_candidateSummary");
        _endWith("Couldn't connect. Try on Wi-Fi, or ask the admin to set up call relay.", notifyPeer: true);
      }
    });
  }

  Future<void> accept() async {
    if (_pendingOffer == null || phase != "incoming") {
      _log("accept ignored ($phase)");
      return;
    }
    _log("accepted");
    // Answered in the app: stop the phone's own ringing screen.
    if (!_nativeAnswered) unawaited(CallNative.end(callId));
    _ringTimer?.cancel();
    outgoing = false;
    phase = "connecting";
    detail = "Connecting…";
    notifyListeners();
    _watchConnect();
    await _ensureMedia();
    if (_local == null) {
      _log("STOPPED: microphone permission denied");
      _endWith("Microphone permission is needed", notifyPeer: true);
      return;
    }
    try {
      await _peer();
      await _applyRemote(_pendingOffer!);
      _log("creating answer");
      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);
      _send("answer", sdp: {"type": answer.type, "sdp": answer.sdp});
    } catch (e) {
      _log("STOPPED: could not answer the call: $e");
      _endWith("Couldn't answer the call. Open Call details for the reason.", notifyPeer: true);
      return;
    }
    _log("answer sent, connecting");
  }

  Future<void> reject() async {
    _send("reject");
    await hangUp(notifyPeer: false);
  }

  Future<void> hangUp({bool notifyPeer = true}) async {
    _ringTimer?.cancel();
    _closeTimer?.cancel();
    _connectTimer?.cancel();
    if (phase != "idle") _log("hung up ($phase)");
    if (notifyPeer && peerId.isNotEmpty && phase != "ended" && phase != "idle") _send("end");
    // Close the screen first so ending always feels instant, then release
    // the camera and microphone (a stuck device must never trap the call).
    phase = "idle";
    notifyListeners();
    unawaited(_releaseNative());
    await _teardown().timeout(const Duration(seconds: 4), onTimeout: () {});
  }

  void toggleMute() {
    muted = !muted;
    for (final t in _local?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      t.enabled = !muted;
    }
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    speakerOn = !speakerOn;
    try {
      await Helper.setSpeakerphoneOn(speakerOn);
    } catch (_) {}
    notifyListeners();
  }

  void toggleCamera() {
    cameraOff = !cameraOff;
    for (final t in _local?.getVideoTracks() ?? <MediaStreamTrack>[]) {
      t.enabled = !cameraOff;
    }
    notifyListeners();
  }

  Future<void> switchCamera() async {
    final tracks = _local?.getVideoTracks() ?? <MediaStreamTrack>[];
    if (tracks.isEmpty) return;
    try {
      await Helper.switchCamera(tracks.first);
    } catch (_) {}
  }

  /* ---------------- internals ---------------- */

  void _resetFlags() {
    muted = false;
    speakerOn = false;
    cameraOff = false;
    connectedAt = null;
  }

  void _live() {
    if (phase == "live") return;
    _log("CONNECTED. Candidates: $_candidateSummary");
    _ringTimer?.cancel();
    _connectTimer?.cancel();
    unawaited(CallNative.stopRingback());
    if (outgoing || _nativeAnswered) unawaited(CallNative.connected(callId));
    // Keep the microphone (and camera) running when the person switches to another app.
    unawaited(CallNative.startBackgroundService(peerName: peerName, video: video));
    phase = "live";
    detail = "Connected";
    connectedAt = DateTime.now();
    if (video) {
      speakerOn = true;
      Helper.setSpeakerphoneOn(true).catchError((_) {});
    }
    notifyListeners();
  }

  /// Shows why the call ended, then closes the call screen.
  void _endWith(String reason, {bool notifyPeer = false}) {
    if (phase == "idle") return;
    _log("ended: $reason");
    _ringTimer?.cancel();
    _connectTimer?.cancel();
    if (notifyPeer && peerId.isNotEmpty) _send("end");
    unawaited(_teardown());
    unawaited(_releaseNative());
    phase = "ended";
    detail = reason;
    notifyListeners();
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(milliseconds: 1800), () {
      if (phase == "ended" && !holdOpen) {
        phase = "idle";
        notifyListeners();
      }
    });
  }

  /// Stop the ringback, the phone's call screen and the background service.
  Future<void> _releaseNative() async {
    await CallNative.stopRingback();
    if (callId.isNotEmpty) await CallNative.end(callId);
    await CallNative.stopBackgroundService();
    _nativeAnswered = false;
  }

  Future<void> _teardown() async {
    try {
      for (final t in _local?.getTracks() ?? <MediaStreamTrack>[]) {
        await t.stop();
      }
      await _local?.dispose();
    } catch (_) {}
    _local = null;
    try {
      await _pc?.close();
    } catch (_) {}
    _pc = null;
    _ice.clear();
    _pendingOffer = null;
    _remoteReady = false;
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
  }

  Future<void> _ensureMedia() async {
    await _renderers();
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) return;
    if (video) {
      final cam = await Permission.camera.request();
      if (!cam.isGranted) video = false;
    }
    try {
      _local = await navigator.mediaDevices.getUserMedia({
        "audio": {"echoCancellation": true, "noiseSuppression": true},
        "video": video ? {"facingMode": "user", "width": 1280, "height": 720} : false,
      });
      localRenderer.srcObject = _local;
    } catch (_) {
      _local = null;
    }
  }

  Future<void> _renderers() async {
    if (_ready) return;
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _ready = true;
  }

  Future<List<dynamic>> _loadIceServers() async {
    if (_iceServers != null) return _iceServers!;
    try {
      final res = await ApiService.dio.get("/calls/ice-servers");
      final list = res.data["iceServers"];
      if (list is List && list.isNotEmpty) {
        _log(res.data["relay"] == true ? "ice servers: STUN + TURN relay" : "ice servers: STUN only (no TURN relay, mobile data may fail)");
        return _iceServers = list;
      }
    } catch (e) {
      _log("could not load ice servers, using STUN fallback: $e");
    }
    return _fallbackIce;
  }

  Future<void> _peer() async {
    final servers = await _loadIceServers();
    _log("creating connection");
    try {
      _pc = await createPeerConnection({"iceServers": servers, "sdpSemantics": "unified-plan"});
    } catch (e) {
      // A bad TURN setting (e.g. a typo in TURN_URLS) must not block calls on Wi-Fi.
      _log("connection with relay failed ($e), retrying with STUN only");
      _pc = await createPeerConnection({"iceServers": _fallbackIce, "sdpSemantics": "unified-plan"});
    }
    _log("adding ${_local?.getTracks().length ?? 0} media tracks");
    for (final track in _local?.getTracks() ?? <MediaStreamTrack>[]) {
      await _pc!.addTrack(track, _local!);
    }
    _pc!.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      _countCandidate(candidate.candidate, "mine");
      _send("ice", candidate: {
        "candidate": candidate.candidate,
        "sdpMid": candidate.sdpMid,
        "sdpMLineIndex": candidate.sdpMLineIndex,
      });
    };
    _pc!.onTrack = (event) {
      if (event.streams.isEmpty) return;
      remoteRenderer.srcObject = event.streams.first;
      _live();
    };
    _pc!.onConnectionState = (state) {
      _log("connection: ${state.name.replaceFirst("RTCPeerConnectionState", "")}");
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _live();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _endWith("Connection lost. The network may be blocking calls.", notifyPeer: true);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected && phase == "live") {
        detail = "Reconnecting…";
        notifyListeners();
      }
    };
    _pc!.onIceConnectionState = (state) {
      _log("ice: ${state.name.replaceFirst("RTCIceConnectionState", "")}");
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        _live();
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _endWith("Couldn't connect. Try on Wi-Fi, or ask the admin to set up call relay.", notifyPeer: true);
      }
    };
  }

  Future<void> _onSignal(Map<String, dynamic> data) async {
    final type = data["type"]?.toString() ?? "";
    final from = data["from"]?.toString() ?? "";
    if (from.isEmpty) return;
    if (type != "ice") _log("signal from server: $type");

    if (type == "offer") {
      if (busy) {
        _log("incoming call refused: already busy ($phase)");
        // Already on a call: let the other caller know straight away.
        SocketService.instance.emit("call:signal", {"to": from, "type": "busy"});
        return;
      }
      _closeTimer?.cancel();
      _resetFlags();
      log.clear();
      holdOpen = false;
      _candidateKinds.clear();
      _log("incoming ${data["video"] == true ? "video" : "voice"} call from ${data["fromName"] ?? from}");
      peerId = from;
      peerName = data["fromName"]?.toString() ?? "Friend";
      video = data["video"] == true;
      outgoing = false;
      _pendingOffer = Map<String, dynamic>.from(data["sdp"] as Map);
      phase = "incoming";
      detail = video ? "Incoming video call" : "Incoming voice call";
      notifyListeners();
      _ringTimer?.cancel();
      _ringTimer = Timer(_ringTimeout, () {
        if (phase == "incoming") _endWith("Missed call");
      });
      callId = data["callId"]?.toString().isNotEmpty == true ? data["callId"].toString() : _newId();
      final choice = _nativeChoice.remove(from);
      if (choice == "accept") {
        // Already answered on the lock screen: connect straight away.
        _nativeAnswered = true;
        _log("answering: it was accepted on the phone's call screen");
        unawaited(accept());
      } else {
        // Ring with the phone's own call screen and ringtone (works on the lock screen too).
        unawaited(CallNative.showIncoming(id: callId, name: peerName, video: video, extra: {"callerId": from}));
      }
      return;
    }

    if (from != peerId) {
      if (type != "ice") _log("ignored $type from someone else");
      return;
    }

    switch (type) {
      case "ringing_push":
        _log("friend's app is closed: their phone is ringing");
      case "answer":
        if (data["sdp"] is Map) {
          unawaited(CallNative.stopRingback());
          _ringTimer?.cancel();
          phase = "connecting";
          detail = "Connecting…";
          notifyListeners();
          _watchConnect();
          try {
            await _applyRemote(Map<String, dynamic>.from(data["sdp"] as Map));
          } catch (e) {
            _log("STOPPED: could not use the friend's answer: $e");
            _endWith("Couldn't connect the call. Open Call details for the reason.", notifyPeer: true);
          }
        }
      case "ice":
        if (data["candidate"] is Map) {
          final raw = Map<String, dynamic>.from(data["candidate"] as Map);
          final ice = RTCIceCandidate(
            raw["candidate"]?.toString(),
            raw["sdpMid"]?.toString(),
            raw["sdpMLineIndex"] is int ? raw["sdpMLineIndex"] as int : null,
          );
          _countCandidate(raw["candidate"]?.toString(), "theirs");
          if (_pc == null || !_remoteReady) {
            _ice.add(ice);
          } else {
            await _pc?.addCandidate(ice);
          }
        }
      case "reject":
        _endWith("$peerName declined");
      case "busy":
        _endWith("$peerName is on another call");
      case "not_friends":
        _endWith("You can only call friends. Add $peerName as a friend first.");
      case "unavailable":
        _endWith("$peerName isn't online. We let them know you called.");
      case "end":
        _endWith(phase == "incoming" ? "Missed call" : "Call ended");
    }
  }

  Future<void> _applyRemote(Map<String, dynamic> sdp) async {
    await _pc?.setRemoteDescription(RTCSessionDescription(sdp["sdp"]?.toString(), sdp["type"]?.toString()));
    _remoteReady = true;
    for (final ice in _ice) {
      await _pc?.addCandidate(ice);
    }
    _ice.clear();
  }

  void _send(String type, {Map<String, dynamic>? sdp, Map<String, dynamic>? candidate}) {
    if (peerId.isEmpty) return;
    SocketService.instance.emit("call:signal", {
      "to": peerId,
      "type": type,
      "video": video,
      if (callId.isNotEmpty) "callId": callId,
      "sdp": ?sdp,
      "candidate": ?candidate,
    });
  }
}
