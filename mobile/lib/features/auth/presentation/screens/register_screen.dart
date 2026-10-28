import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/phone.dart';
import '../../application/providers/auth_provider.dart';
import 'otp_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final phoneController = TextEditingController();

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = withIndiaCountryCode(phoneController.text);
    if (phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter your phone number")),
      );
      return;
    }

    final devOtp = await ref.read(authProvider.notifier).sendOtp(
          phone,
          purpose: "register",
        );

    if (ref.read(authProvider).error != null || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtpScreen(
          phone: phone,
          purpose: "register",
          devOtp: devOtp,
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

    return Scaffold(
      appBar: AppBar(title: const Text("Create account")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Verify your phone to register",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  prefixText: "+91 ",
                  labelText: "Phone Number",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: authState.isLoading ? null : _sendOtp,
                  child: authState.isLoading
                      ? const CircularProgressIndicator()
                      : const Text("Send OTP"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
