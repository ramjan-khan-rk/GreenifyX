import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'issues_hub_screen.dart';
import 'report_issue_screen.dart';

/// Home-screen entry point for Report & Restore UAE.
class ReportRestoreCard extends StatelessWidget {
  const ReportRestoreCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [AppColors.ink, Color(0xFF3A3256)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: AppColors.joy.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.report_gmailerrorred_rounded, color: AppColors.joy),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Report & Restore UAE",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16.5)),
                SizedBox(height: 2),
                Text("Dumping, overflowing bins, pollution",
                    style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 12.5)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportIssueScreen())),
                icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                label: const Text("Report"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0x55FFFFFF)),
                  minimumSize: const Size(0, 44),
                ),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IssuesHubScreen())),
                child: const Text("Track reports"),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
