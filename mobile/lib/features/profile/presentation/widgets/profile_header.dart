import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/user_avatar.dart';
import 'package:greenifyx/core/i18n/app_locale.dart';

/// Photo with a camera badge. Shows a newly picked [file] before it is uploaded.
class ProfileHeader extends StatelessWidget {
  final String imageUrl;
  final File? file;
  final VoidCallback onChangePhoto;

  const ProfileHeader({
    super.key,
    required this.imageUrl,
    required this.onChangePhoto,
    this.file,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Semantics(
          button: true,
          label: tr("Change profile photo"),
          child: GestureDetector(
            onTap: onChangePhoto,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                file != null
                    ? CircleAvatar(radius: 52, backgroundImage: FileImage(file!))
                    : UserAvatar(imageUrl: imageUrl, radius: 52),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background, width: 3),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: onChangePhoto,
          child: Text(tr("Change photo"), style: AppTextStyles.subtitle.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
