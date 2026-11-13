import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/media_url.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String? semanticLabel;

  /// Used for the initial when there is no photo.
  final String? name;

  const UserAvatar({
    super.key,
    this.imageUrl,
    this.radius = 22,
    this.semanticLabel,
    this.name,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = resolveMediaUrl(imageUrl);
    final size = radius * 2;
    final initial = (name ?? "").trim().isNotEmpty ? name!.trim()[0].toUpperCase() : null;

    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [AppColors.blush, Color(0xFFFFD9C7)]),
      ),
      child: initial != null
          ? Text(initial, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: radius * 0.85))
          : Icon(Icons.person_rounded, size: radius * 1.1, color: AppColors.primary),
    );

    return Semantics(
      label: semanticLabel ?? "Profile photo",
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: resolved == null || resolved.isEmpty
            ? fallback
            : ClipOval(
                child: CachedNetworkImage(
                  imageUrl: resolved,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => fallback,
                  errorWidget: (_, _, _) => fallback,
                ),
              ),
      ),
    );
  }
}
