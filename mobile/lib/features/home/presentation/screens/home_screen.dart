import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/application/providers/my_profile_provider.dart';
import '../../../challenge/presentation/screens/create_challenge_screen.dart';
import '../../../challenge/presentation/screens/challenge_screen.dart';
import '../../../../core/utils/media_url.dart';
import '../widgets/eco_points_card.dart';
import '../widgets/quote_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
  heroTag: "challenges",
  icon: const Icon(Icons.flag),
  label: const Text("Challenges"),
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ChallengeScreen(),
      ),
    );
  },
),

      body: SafeArea(
        child: profile.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),

          error: (e, s) =>
              Center(child: Text(e.toString())),

          data: (user) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  //---------------------------------
                  /// USER HEADER
                  //---------------------------------

                  Row(
                    children: [

                      CircleAvatar(
                        radius: 28,

                        backgroundImage:
                            user.profileImage.isNotEmpty
                                ? NetworkImage(
                                    resolveMediaUrl(user.profileImage) ?? "",
                                  )
                                : null,

                        child: user.profileImage.isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),

                      const SizedBox(width: 15),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [

                            Text(
                              "Welcome Back 👋",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              user.name,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  EcoPointsCard(
                    ecoPoints: user.ecoPoints,
                    level: user.level,
                    streak: user.streak,
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.emoji_events),

                      label: const Text(
                        "Start New Challenge",
                      ),

                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const CreateChallengeScreen(),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  const QuoteCard(),

                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}