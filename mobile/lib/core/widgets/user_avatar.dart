import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/media_url.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String? semanticLabel;

  const UserAvatar({
    super.key,
    this.imageUrl,
    this.radius = 22,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = resolveMediaUrl(imageUrl);
    final hasImage = resolved != null && resolved.isNotEmpty;

    return Semantics(
      label: semanticLabel ?? "Profile photo",
      image: true,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
        backgroundImage: hasImage ? NetworkImage(resolved) : null,
        child: hasImage
            ? null
            : Icon(Icons.person, size: radius, color: AppColors.primary),
      ),
    );
  }
}
