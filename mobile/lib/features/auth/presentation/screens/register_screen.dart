import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_status.dart';
import '../../../../core/widgets/brand_icons.dart';
import '../../application/providers/auth_provider.dart';
import 'otp_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final emailController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final email = emailController.text.trim();
    if (email.isEmpty || !email.contains("@")) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid email")),
      );
      return;
    }

    final devOtp = await ref.read(authProvider.notifier).sendOtp(
          email,
          purpose: "register",
        );

    if (ref.read(authProvider).error != null || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtpScreen(
          email: email,
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
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text("Create account")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const BrandMark(size: 64),
              const SizedBox(height: 16),
              Text("Register with email", style: AppTextStyles.title),
              const SizedBox(height: 8),
              Text(
                "We'll email a 6-digit code. ${BrandCopy.tagline}.",
                style: AppTextStyles.subtitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: "Email",
                  prefixIcon: Icon(Icons.mail_outline, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: authState.isLoading ? null : _sendOtp,
                  icon: const Icon(BrandGlyph.verified),
                  label: authState.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Email verification code"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
