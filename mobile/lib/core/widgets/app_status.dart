import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class AppLoading extends StatelessWidget {
  const AppLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.primary.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            Text(title, style: AppTextStyles.title, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.subtitle.copyWith(height: 1.4),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: 220,
                child: ElevatedButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AppErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.cloud_off_outlined,
      title: "Couldn't load this page",
      message: message,
      actionLabel: onRetry == null ? null : "Try again",
      onAction: onRetry,
    );
  }
}

class BrandMark extends StatelessWidget {
  final double size;

  const BrandMark({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        "assets/brand/app_icon.png",
        width: size,
        height: size,
        fit: BoxFit.cover,
        semanticLabel: "GreenifyX",
      ),
    );
  }
}

class BrandLockup extends StatelessWidget {
  final double markSize;
  final bool centered;

  const BrandLockup({
    super.key,
    this.markSize = 72,
    this.centered = true,
  });

  @override
  Widget build(BuildContext context) {
    final column = Column(
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        BrandMark(size: markSize),
        const SizedBox(height: 12),
        Text("GreenifyX", style: AppTextStyles.heading.copyWith(fontSize: 26)),
        const SizedBox(height: 4),
        Text("Small Actions Big Impact", style: AppTextStyles.tagline),
      ],
    );
    return centered ? Center(child: column) : column;
  }
}
