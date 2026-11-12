import 'package:flutter/material.dart';

/// Blue tick for verified creators, organisations, verifiers and official accounts.
class VerifiedTick extends StatelessWidget {
  final String type;
  final double size;
  const VerifiedTick(this.type, {super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    if (type.isEmpty) return const SizedBox.shrink();
    final color = switch (type) {
      "organisation" => const Color(0xFFD9B45A),
      "official" => const Color(0xFF1F8A70),
      _ => const Color(0xFF1D9BF0),
    };
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4),
      child: Tooltip(message: "Verified $type", child: Icon(Icons.verified_rounded, size: size, color: color)),
    );
  }
}
