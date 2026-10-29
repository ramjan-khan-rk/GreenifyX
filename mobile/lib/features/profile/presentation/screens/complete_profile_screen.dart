import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/brand_icons.dart';
import '../../application/providers/profile_provider.dart';
import '../widgets/profile_avatar.dart';

class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState
    extends ConsumerState<CompleteProfileScreen> {
  final nameController = TextEditingController();
  final bioController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Settings", style: AppTextStyles.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(BrandGlyph.settings, color: AppColors.navy, size: 28),
            const SizedBox(height: 8),
            Text(
              "Name, photo, and bio",
              style: AppTextStyles.subtitle,
            ),
            const SizedBox(height: 20),
            ProfileAvatar(
              image: state.imageFile,
              onTap: () {
                ref.read(profileProvider.notifier).pickImage();
              },
            ),
            const SizedBox(height: 28),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Full Name",
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: bioController,
              maxLines: 4,
              maxLength: 150,
              decoration: const InputDecoration(
                labelText: "Bio",
                hintText: "Tell something about yourself",
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: state.isLoading
                    ? null
                    : () async {
                        if (state.imageFile != null &&
                            state.profileImage.isEmpty) {
                          await ref
                              .read(profileProvider.notifier)
                              .uploadImage();
                        }

                        final success = await ref
                            .read(profileProvider.notifier)
                            .saveProfile(
                              name: nameController.text.trim(),
                              bio: bioController.text.trim(),
                            );

                        if (success && context.mounted) {
                          context.go("/home");
                        }
                      },
                child: state.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text("Save profile"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
