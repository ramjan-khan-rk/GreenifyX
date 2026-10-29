import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}
