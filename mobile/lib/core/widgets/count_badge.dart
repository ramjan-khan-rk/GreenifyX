import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class CountBadge extends StatelessWidget {
  final int count;
  final Widget child;

  const CountBadge({
    super.key,
    required this.count,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      backgroundColor: AppColors.primary,
      label: Text(count > 9 ? "9+" : "$count"),
      child: child,
    );
  }
}
