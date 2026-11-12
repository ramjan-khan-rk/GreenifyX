import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Premium points card: balance, level progress and streak.
class ImpactHero extends StatelessWidget {
  final int points;
  final int level;
  final int streak;
  final VoidCallback onHistory;
  final VoidCallback onRewards;

  const ImpactHero({
    super.key,
    required this.points,
    required this.level,
    required this.streak,
    required this.onHistory,
    required this.onRewards,
  });

  @override
  Widget build(BuildContext context) {
    // Levels step every 100 verified points (matches the backend).
    final into = points % 100;
    final progress = into / 100;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [Color(0xFF2B2440), Color(0xFF1F5A4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [BoxShadow(color: Color(0x332B2440), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Stack(children: [
        Positioned(
          right: -30,
          top: -40,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.sun.withValues(alpha: 0.12)),
          ),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.stars_rounded, color: AppColors.sun, size: 20),
            const SizedBox(width: 6),
            Text("Eco Points", style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF9F43), size: 16),
                const SizedBox(width: 4),
                Text("$streak-day streak", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Text("$points", style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w800, height: 1, letterSpacing: -1)),
          const SizedBox(height: 16),
          Row(children: [
            Text("Level $level", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            const Spacer(),
            Text("${100 - into} to level ${level + 1}", style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12.5)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.14),
              color: AppColors.sun,
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: _HeroButton(icon: Icons.redeem_rounded, label: "Rewards", filled: true, onTap: onRewards),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _HeroButton(icon: Icons.receipt_long_rounded, label: "History", onTap: onHistory),
            ),
          ]),
        ]),
      ]),
    );
  }
}

class _HeroButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _HeroButton({required this.icon, required this.label, required this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.sun : Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: filled ? AppColors.ink : Colors.white),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: filled ? AppColors.ink : Colors.white)),
          ]),
        ),
      ),
    );
  }
}
