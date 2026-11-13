import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Soft shimmering placeholder blocks shown while content loads.
class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});
  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = AppColors.isDark ? const Color(0xFF26232F) : const Color(0xFFEDEAF2);
    final hi = AppColors.isDark ? const Color(0xFF34303F) : const Color(0xFFF8F6FB);
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (r) => LinearGradient(
          begin: Alignment(-1.5 + _c.value * 3, -0.3),
          end: Alignment(-0.5 + _c.value * 3, 0.3),
          colors: [base, hi, base],
        ).createShader(r),
        child: child,
      ),
    );
  }
}

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const SkeletonBox({super.key, this.width, this.height = 12, this.radius = 8});
  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: AppColors.isDark ? const Color(0xFF26232F) : const Color(0xFFEDEAF2), borderRadius: BorderRadius.circular(radius)),
      );
}

/// A list of card-shaped placeholders (avatar, two lines, media block).
class SkeletonList extends StatelessWidget {
  final int count;
  final bool media;
  const SkeletonList({super.key, this.count = 4, this.media = true});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        children: [
          for (var i = 0; i < count; i++)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  SkeletonBox(width: 42, height: 42, radius: 21),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SkeletonBox(width: 140),
                      SizedBox(height: 8),
                      SkeletonBox(width: 90, height: 10),
                    ]),
                  ),
                ]),
                if (media && i.isEven) ...[
                  const SizedBox(height: 14),
                  const SkeletonBox(height: 170, radius: 16),
                ],
                const SizedBox(height: 12),
                const SkeletonBox(),
                const SizedBox(height: 8),
                const SkeletonBox(width: 200),
              ]),
            ),
        ],
      ),
    );
  }
}
