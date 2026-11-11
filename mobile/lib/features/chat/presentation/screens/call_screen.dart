import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../application/call_coordinator.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final call = CallCoordinator.instance;

  @override
  void initState() {
    super.initState();
    call.addListener(_onCall);
  }

  @override
  void dispose() {
    call.removeListener(_onCall);
    super.dispose();
  }

  void _onCall() {
    if (!mounted) return;
    if (call.phase == "idle") {
      Navigator.pop(context);
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final incoming = call.phase == "incoming";
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Text(
                call.peerName,
                textAlign: TextAlign.center,
                style: AppTextStyles.heading.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                call.detail,
                style: AppTextStyles.subtitle.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 28),
              if (call.video && call.phase == "live")
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: RTCVideoView(call.remoteRenderer),
                  ),
                )
              else
                const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (incoming)
                    _RoundButton(
                      color: AppColors.eco,
                      icon: Icons.call_rounded,
                      onTap: call.accept,
                    ),
                  if (incoming) const SizedBox(width: 28),
                  _RoundButton(
                    color: AppColors.error,
                    icon: Icons.call_end_rounded,
                    onTap: incoming ? call.reject : () => call.hangUp(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _RoundButton({
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 68,
          height: 68,
          child: Icon(icon, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}
