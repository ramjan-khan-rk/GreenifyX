import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/auth_provider.dart';
import 'set_password_screen.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String email;
  final String purpose;
  final String? devOtp;

  const OtpScreen({
    super.key,
    required this.email,
    this.purpose = "register",
    this.devOtp,
  });

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (kDebugMode && widget.devOtp != null && widget.devOtp!.isNotEmpty) {
      otpController.text = widget.devOtp!;
    }
  }

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final ok = await ref.read(authProvider.notifier).verifyOtp(
          widget.email,
          otpController.text.trim(),
          purpose: widget.purpose,
        );

    if (!ok || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("OTP verified")),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SetPasswordScreen(
          email: widget.email,
          purpose: widget.purpose,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
      }
    });

    final title = widget.purpose == "reset"
        ? "Verify reset OTP"
        : "Verify OTP";

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("OTP sent to ${widget.email}"),
            if (kDebugMode && widget.devOtp != null) ...[
              const SizedBox(height: 12),
              const Text(
                "Development shortcut is enabled on this non-production API.",
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 30),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: "Enter OTP",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: authState.isLoading ? null : _verify,
                child: authState.isLoading
                    ? const CircularProgressIndicator()
                    : const Text("Verify OTP"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
