import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/emirates.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_status.dart';
import '../../application/providers/my_profile_provider.dart';
import '../../application/providers/profile_provider.dart';
import '../../domain/models/profile_model.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_text_field.dart';
import '../widgets/save_button.dart';

/// Edit an existing profile. Fields start with the saved values so nothing is lost.
class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text("Edit profile", style: AppTextStyles.title)),
      body: profile.when(
        loading: () => const AppLoading(),
        error: (e, _) => AppErrorState(
          message: "Could not load your profile.",
          onRetry: () => ref.invalidate(myProfileProvider),
        ),
        data: (p) => _EditForm(profile: p),
      ),
    );
  }
}

class _EditForm extends ConsumerStatefulWidget {
  final ProfileModel profile;
  const _EditForm({required this.profile});

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.profile.name);
  late final TextEditingController _bio = TextEditingController(text: widget.profile.bio);
  late String _emirate = widget.profile.emirate;
  File? _photo;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1080,
    );
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      var imageUrl = widget.profile.profileImage;
      if (_photo != null) {
        imageUrl = await ref.read(uploadApiProvider).uploadImage(_photo!);
      }
      await ref.read(profileRepositoryProvider).updateProfile(
            name: _name.text.trim(),
            bio: _bio.text.trim(),
            profileImage: imageUrl,
            emirate: _emirate,
          );
      ref.invalidate(myProfileProvider);
      messenger.showSnackBar(const SnackBar(content: Text("Profile updated")));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Could not save. Check your connection and try again.")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          Center(
            child: ProfileHeader(
              imageUrl: widget.profile.profileImage,
              file: _photo,
              onChangePhoto: () {
                if (!_saving) _pickPhoto();
              },
            ),
          ),
          const SizedBox(height: 16),
          ProfileTextField(
            controller: _name,
            label: "Full name",
            icon: Icons.person_outline_rounded,
            validator: (v) => (v == null || v.trim().length < 2) ? "Enter your name" : null,
          ),
          const SizedBox(height: 18),
          ProfileTextField(
            controller: _bio,
            label: "Bio",
            hint: "What do you do for the planet?",
            maxLines: 3,
            maxLength: 150,
            textInputAction: TextInputAction.newline,
          ),
          const SizedBox(height: 10),
          Text("Emirate", style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in kEmirates)
                ChoiceChip(
                  label: Text(e),
                  selected: _emirate == e,
                  selectedColor: AppColors.primary.withValues(alpha: 0.16),
                  side: BorderSide(color: _emirate == e ? AppColors.primary : AppColors.border),
                  onSelected: (_) => setState(() => _emirate = e),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Used for community stats by emirate. Not shown publicly with your location.",
            style: AppTextStyles.subtitle.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 28),
          SaveButton(label: "Save changes", loading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}
