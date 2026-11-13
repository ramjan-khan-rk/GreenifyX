import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/call_coordinator.dart';
import 'package:greenifyx/core/i18n/app_locale.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final call = CallCoordinator.instance;
  Timer? _tick;
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    call.addListener(_onCall);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && call.phase == "live") setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    call.removeListener(_onCall);
    super.dispose();
  }

  void _onCall() {
    if (!mounted) return;
    if (call.phase == "idle") {
      if (!_popped) {
        _popped = true;
        Navigator.of(context).maybePop();
      }
      return;
    }
    setState(() {});
  }

  String get _status {
    if (call.phase == "live" && call.connectedAt != null) {
      final d = DateTime.now().difference(call.connectedAt!);
      final m = d.inMinutes.remainder(60).toString().padLeft(2, "0");
      final s = d.inSeconds.remainder(60).toString().padLeft(2, "0");
      return d.inHours > 0 ? "${d.inHours}:$m:$s" : "$m:$s";
    }
    return call.detail;
  }

  String get _initials {
    final parts = call.peerName.trim().split(RegExp(r"\s+")).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return "?";
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : "")).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final incoming = call.phase == "incoming";
    final ended = call.phase == "ended";
    final showVideo = call.video && call.phase == "live";

    return PopScope(
      canPop: call.phase == "idle" || ended,
      child: Scaffold(
        backgroundColor: AppColors.inkFixed,
        body: Stack(fit: StackFit.expand, children: [
          if (showVideo)
            RTCVideoView(call.remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
          else
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.ink, Color(0xFF1F5A4B)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          if (showVideo)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x99000000), Color(0x00000000), Color(0x00000000), Color(0xB3000000)],
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              child: Column(children: [
                if (showVideo)
                  Align(
                    alignment: Alignment.topLeft,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(call.peerName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      Text(_status, style: const TextStyle(color: Colors.white70)),
                    ]),
                  )
                else ...[
                  const Spacer(flex: 2),
                  _Avatar(initials: _initials, pulsing: call.phase == "ringing" || incoming),
                  const SizedBox(height: 22),
                  Text(call.peerName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ended ? AppColors.sun : Colors.white70, fontSize: 16, fontWeight: ended ? FontWeight.w700 : FontWeight.w400),
                  ),
                  const SizedBox(height: 6),
                  Text(call.video ? "Video call" : "Voice call", style: const TextStyle(color: Colors.white38, fontSize: 13)),
                ],
                const Spacer(flex: 3),
                if (ended)
                  const SizedBox(height: 68)
                else if (incoming)
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    _RoundButton(color: AppColors.error, icon: Icons.call_end_rounded, label: tr("Decline"), onTap: call.reject),
                    _RoundButton(
                      color: AppColors.eco,
                      icon: call.video ? Icons.videocam_rounded : Icons.call_rounded,
                      label: tr("Accept"),
                      onTap: call.accept,
                    ),
                  ])
                else ...[
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    _ToggleButton(
                      icon: call.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      label: call.muted ? "Unmute" : "Mute",
                      active: call.muted,
                      onTap: call.toggleMute,
                    ),
                    _ToggleButton(
                      icon: call.speakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                      label: tr("Speaker"),
                      active: call.speakerOn,
                      onTap: call.toggleSpeaker,
                    ),
                    if (call.video) ...[
                      _ToggleButton(
                        icon: call.cameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                        label: call.cameraOff ? "Camera on" : "Camera off",
                        active: call.cameraOff,
                        onTap: call.toggleCamera,
                      ),
                      _ToggleButton(icon: Icons.cameraswitch_rounded, label: tr("Flip"), active: false, onTap: call.switchCamera),
                    ],
                  ]),
                  const SizedBox(height: 28),
                  _RoundButton(color: AppColors.error, icon: Icons.call_end_rounded, label: tr("End"), onTap: () => call.hangUp()),
                ],
              ]),
            ),
          ),
          if (call.video && !incoming && !ended && !call.cameraOff)
            Positioned(
              right: 16,
              top: MediaQuery.paddingOf(context).top + 16,
              width: 110,
              height: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: DecoratedBox(
                  decoration: BoxDecoration(border: Border.all(color: Colors.white24), color: Colors.black),
                  child: RTCVideoView(call.localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class _Avatar extends StatefulWidget {
  final String initials;
  final bool pulsing;
  const _Avatar({required this.initials, required this.pulsing});

  @override
  State<_Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<_Avatar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      height: 170,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Stack(alignment: Alignment.center, children: [
          if (widget.pulsing)
            Container(
              width: 120 + 50 * _c.value,
              height: 120 + 50 * _c.value,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.eco.withValues(alpha: 0.35 * (1 - _c.value))),
            ),
          Container(
            width: 120,
            height: 120,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [AppColors.joy, AppColors.sun]),
            ),
            child: Text(widget.initials, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToggleButton({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Material(
        color: active ? Colors.white : Colors.white.withValues(alpha: 0.14),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 56, height: 56, child: Icon(icon, color: active ? AppColors.ink : Colors.white)),
        ),
      ),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ]);
  }
}

class _RoundButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _RoundButton({required this.color, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Material(
        color: color,
        shape: const CircleBorder(),
        elevation: 6,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 70, height: 70, child: Icon(icon, color: Colors.white, size: 30)),
        ),
      ),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
    ]);
  }
}
