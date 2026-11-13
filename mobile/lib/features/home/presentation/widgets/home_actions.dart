import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class HomeAction {
  final IconData icon;
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;
  const HomeAction(this.icon, this.label, this.colors, this.onTap);
}

/// Grid of round gradient shortcuts, four per row.
class HomeActionGrid extends StatelessWidget {
  final List<HomeAction> actions;
  const HomeActionGrid({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth / 4;
        return Wrap(children: [
          for (final a in actions)
            SizedBox(
              width: w,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: a.onTap,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: a.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                        boxShadow: [BoxShadow(color: a.colors.first.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Icon(a.icon, color: Colors.white, size: 25),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      a.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                    ),
                  ]),
                ),
              ),
            ),
        ]);
      }),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Row(children: [
        Expanded(
          child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.2)),
        ),
        if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
      ]),
    );
  }
}
