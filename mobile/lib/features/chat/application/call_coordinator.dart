import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/socket_service.dart';

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
  bool _ready = false;
  bool _bound = false;
  bool _remoteReady = false;

  bool get busy => phase != "idle" && phase != "ended";

  void _onRaw(dynamic raw) {
    if (raw is Map) unawaited(_onSignal(Map<String, dynamic>.from(raw)));
  }

  /// Safe to call many times; the socket registry keeps the listener across reconnects.
  void bind() {
    if (_bound) return;
    _bound = true;
    SocketService.instance.on("call:signal", _onRaw);
  }

  Future<void> start({required String userId, required String userName, required bool withVideo}) async {
    if (busy) return;
    _closeTimer?.cancel();
    _resetFlags();
    peerId = userId;
    peerName = userName;
    video = withVideo;
    outgoing = true;
    phase = "ringing";
    detail = withVideo ? "Starting video call…" : "Calling…";
    notifyListeners();

    bind();
    if (!await SocketService.instance.ensureConnected()) {
      phase = "ended";
      detail = "You're offline. Check your internet and try again.";
      notifyListeners();
      return;
    }

    await _ensureMedia();
    if (_local == null) {
      phase = "ended";
      detail = withVideo ? "Allow the camera and microphone to call." : "Allow the microphone to call.";
      notifyListeners();
      return;
    }
    await _peer();
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    _send("offer", sdp: {"type": offer.type, "sdp": offer.sdp});
    detail = "Ringing…";
    notifyListeners();
    _ringTimer = Timer(_ringTimeout, () {
      if (phase == "ringing") _endWith("No answer", notifyPeer: true);
    });
  }

  Future<void> accept() async {
    if (_pendingOffer == null || phase != "incoming") return;
    outgoing = false;
    phase = "connecting";
    detail = "Connecting…";
    notifyListeners();
    await _ensureMedia();
    if (_local == null) {
      _endWith("Microphone permission is needed", notifyPeer: true);
      return;
    }
    await _peer();
    await _applyRemote(_pendingOffer!);
    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);
    _send("answer", sdp: {"type": answer.type, "sdp": answer.sdp});
  }

  Future<void> reject() async {
    _send("reject");
    await hangUp(notifyPeer: false);
  }

  Future<void> hangUp({bool notifyPeer = true}) async {
    _ringTimer?.cancel();
    _closeTimer?.cancel();
    if (notifyPeer && peerId.isNotEmpty && phase != "ended") _send("end");
    await _teardown();
    phase = "idle";
    notifyListeners();
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
    _ringTimer?.cancel();
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
    _ringTimer?.cancel();
    if (notifyPeer && peerId.isNotEmpty) _send("end");
    unawaited(_teardown());
    phase = "ended";
    detail = reason;
    notifyListeners();
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(milliseconds: 1800), () {
      if (phase == "ended") {
        phase = "idle";
        notifyListeners();
      }
    });
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
      if (list is List && list.isNotEmpty) return _iceServers = list;
    } catch (_) {}
    return _fallbackIce;
  }

  Future<void> _peer() async {
    _pc = await createPeerConnection({
      "iceServers": await _loadIceServers(),
      "sdpSemantics": "unified-plan",
    });
    for (final track in _local?.getTracks() ?? <MediaStreamTrack>[]) {
      await _pc!.addTrack(track, _local!);
    }
    _pc!.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
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
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _live();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _endWith("Connection lost. The network may be blocking calls.", notifyPeer: true);
      }
    };
  }

  Future<void> _onSignal(Map<String, dynamic> data) async {
    final type = data["type"]?.toString() ?? "";
    final from = data["from"]?.toString() ?? "";
    if (from.isEmpty) return;

    if (type == "offer") {
      if (busy) {
        // Already on a call: let the other caller know straight away.
        SocketService.instance.emit("call:signal", {"to": from, "type": "busy"});
        return;
      }
      _closeTimer?.cancel();
      _resetFlags();
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
      return;
    }

    if (from != peerId) return;

    switch (type) {
      case "answer":
        if (data["sdp"] is Map) {
          phase = "connecting";
          detail = "Connecting…";
          notifyListeners();
          await _applyRemote(Map<String, dynamic>.from(data["sdp"] as Map));
        }
      case "ice":
        if (data["candidate"] is Map) {
          final raw = Map<String, dynamic>.from(data["candidate"] as Map);
          final ice = RTCIceCandidate(
            raw["candidate"]?.toString(),
            raw["sdpMid"]?.toString(),
            raw["sdpMLineIndex"] is int ? raw["sdpMLineIndex"] as int : null,
          );
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
      "sdp": ?sdp,
      "candidate": ?candidate,
    });
  }
}
