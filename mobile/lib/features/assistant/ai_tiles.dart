import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'assistant_screen.dart';
import 'snap_sort_screen.dart';
import 'package:greenifyx/core/i18n/app_locale.dart';

/// Home-screen entry to the AI features.
class AiTiles extends StatelessWidget {
  const AiTiles({super.key});

  @override
  Widget build(BuildContext context) {
    Widget tile({required IconData icon, required String title, required String text, required List<Color> colors, required Widget page}) {
      return Expanded(
        child: Material(
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(icon, color: Colors.white, size: 26),
                  const SizedBox(height: 10),
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15.5)),
                  const SizedBox(height: 2),
                  Text(text, style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 12, height: 1.3)),
                ]),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Row(children: [
        tile(
          icon: Icons.auto_awesome_rounded,
          title: tr("Ask GreenifyX"),
          text: "Find campaigns, drop-offs and answers",
          colors: const [AppColors.eco, Color(0xFF2A9D8F)],
          page: const AssistantScreen(),
        ),
        const SizedBox(width: 12),
        tile(
          icon: Icons.camera_alt_rounded,
          title: tr("Snap & Sort"),
          text: "Photo an item, see which bin",
          colors: const [Color(0xFFE36A4A), Color(0xFFC2513A)],
          page: const SnapSortScreen(),
        ),
      ]),
    );
  }
}
