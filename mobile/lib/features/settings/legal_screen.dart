import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class LegalScreen extends StatelessWidget {
  final String title;
  final List<(String, String)> sections;
  const LegalScreen({super.key, required this.title, required this.sections});

  static const privacy = LegalScreen(title: "Privacy policy", sections: [
    ("What we collect", "Your name, contact details, profile photo, posts, messages and the location attached to activities you submit for verification."),
    ("Why we use it", "To run your account, verify environmental actions, award Eco Points, connect you with friends and teams, and keep the community safe."),
    ("Location", "Location is only read when you submit evidence, report an issue or open the Eco Map. It is used to check you were at the activity site."),
    ("Sharing", "We never sell your data. Organisations you join see your verified impact in their team dashboard. Verifiers see the evidence you submit."),
    ("Your choices", "You can edit your profile, switch notifications off and delete your account at any time from Settings."),
    ("Contact", "Questions about your data: privacy@greenifyx.ae"),
  ]);

  static const terms = LegalScreen(title: "Terms of use", sections: [
    ("Be genuine", "Only submit evidence of actions you really took part in. Faked photos or locations lead to points being reversed and the account being suspended."),
    ("Be kind", "No harassment, hate speech or spam. Reported content is reviewed by moderators and may be removed."),
    ("Eco Points", "Points have no cash value. They can be redeemed for rewards while stocks last, and may be reversed if a verification is overturned."),
    ("Safety", "Follow the organiser's safety guidance at events. Do not enter restricted or protected areas to collect evidence."),
    ("Changes", "We may update these terms. Continuing to use GreenifyX means you accept the latest version."),
  ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          for (final s in sections) ...[
            const SizedBox(height: 18),
            Text(s.$1, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 6),
            Text(s.$2, style: const TextStyle(fontSize: 14.5, height: 1.5, color: AppColors.subtitle)),
          ],
        ],
      ),
    );
  }
}
