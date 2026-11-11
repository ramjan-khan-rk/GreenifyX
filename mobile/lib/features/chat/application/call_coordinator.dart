import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/services/socket_service.dart';

class CallCoordinator extends ChangeNotifier {
  CallCoordinator._();

  static final CallCoordinator instance = CallCoordinator._();

  String phase = "idle";
  String peerId = "";
  String peerName = "Friend";
  bool video = false;
  bool outgoing = false;
  String detail = "";

  RTCPeerConnection? _pc;
  MediaStream? _local;
  final localRenderer = RTCVideoRenderer();
  final remoteRenderer = RTCVideoRenderer();
  final List<RTCIceCandidate> _ice = [];
  Map<String, dynamic>? _pendingOffer;
  bool _ready = false;
  bool _bound = false;
  bool _remoteReady = false;

  void bind() {
    if (_bound) return;
    _bound = true;
    SocketService.instance.on("call:signal", (raw) {
      if (raw is Map) {
        unawaited(_onSignal(Map<String, dynamic>.from(raw)));
      }
    });
  }

  Future<void> start({
    required String userId,
    required String userName,
    required bool withVideo,
  }) async {
    if (phase != "idle" && phase != "ended") return;
    peerId = userId;
    peerName = userName;
    video = withVideo;
    outgoing = true;
    detail = withVideo ? "Starting video…" : "Calling…";
    phase = "ringing";
    notifyListeners();
    await _ensureMedia();
    if (_local == null) {
      phase = "ended";
      detail = "Allow the microphone to call.";
      notifyListeners();
      return;
    }
    await _peer();
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    _send("offer", sdp: {"type": offer.type, "sdp": offer.sdp});
  }

  Future<void> accept() async {
    if (_pendingOffer == null) return;
    outgoing = false;
    phase = "connecting";
    detail = "Connecting…";
    notifyListeners();
    await _ensureMedia();
    await _peer();
    await _applyRemote(_pendingOffer!);
    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);
    _send("answer", sdp: {"type": answer.type, "sdp": answer.sdp});
    phase = "live";
    detail = "Connected";
    notifyListeners();
  }

  Future<void> reject() async {
    _send("reject");
    await hangUp(notifyPeer: false);
  }

  Future<void> hangUp({bool notifyPeer = true}) async {
    if (notifyPeer && peerId.isNotEmpty) _send("end");
    await _local?.dispose();
    _local = null;
    await _pc?.close();
    _pc = null;
    _ice.clear();
    _pendingOffer = null;
    _remoteReady = false;
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    phase = "idle";
    notifyListeners();
  }

  Future<void> _ensureMedia() async {
    await _renderers();
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) return;
    if (video) {
      await Permission.camera.request();
    }
    _local = await navigator.mediaDevices.getUserMedia({
      "audio": true,
      "video": video ? {"facingMode": "user"} : false,
    });
    localRenderer.srcObject = _local;
  }

  Future<void> _renderers() async {
    if (_ready) return;
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _ready = true;
  }

  Future<void> _peer() async {
    _pc = await createPeerConnection({
      "iceServers": [
        {"urls": "stun:stun.l.google.com:19302"},
      ],
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
      phase = "live";
      detail = "Connected";
      notifyListeners();
    };
  }

  Future<void> _onSignal(Map<String, dynamic> data) async {
    final type = data["type"]?.toString() ?? "";
    final from = data["from"]?.toString() ?? "";
    if (from.isEmpty) return;

    if (type == "offer" && (phase == "idle" || phase == "ended")) {
      peerId = from;
      peerName = data["fromName"]?.toString() ?? "Friend";
      video = data["video"] == true;
      outgoing = false;
      _pendingOffer = Map<String, dynamic>.from(data["sdp"] as Map);
      phase = "incoming";
      detail = video ? "Video call" : "Voice call";
      notifyListeners();
      return;
    }

    if (from != peerId) return;

    if (type == "answer" && data["sdp"] is Map) {
      await _applyRemote(Map<String, dynamic>.from(data["sdp"] as Map));
      phase = "live";
      detail = "Connected";
      notifyListeners();
    } else if (type == "ice" && data["candidate"] is Map) {
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
    } else if (type == "reject" || type == "end") {
      await hangUp(notifyPeer: false);
    }
  }

  Future<void> _applyRemote(Map<String, dynamic> sdp) async {
    await _pc?.setRemoteDescription(
      RTCSessionDescription(sdp["sdp"]?.toString(), sdp["type"]?.toString()),
    );
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
