import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/challenge_provider.dart';
import '../../domain/models/challenge_model.dart';

class ChallengeCard extends ConsumerWidget {
  final ChallengeModel challenge;

  const ChallengeCard({
    super.key,
    required this.challenge,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remainingDays =
        challenge.deadline.difference(DateTime.now()).inDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [

            //------------------------------------------------

            Row(
              children: [

                const Icon(
                  Icons.emoji_events,
                  color: Colors.green,
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    challenge.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                _statusChip(),
              ],
            ),

            //------------------------------------------------

            const SizedBox(height: 12),

            Text(
              challenge.description,
            ),

            const SizedBox(height: 15),

            Row(
              children: [

                const Icon(Icons.category),

                const SizedBox(width: 6),

                Text(challenge.category),

                const Spacer(),

                const Icon(Icons.local_fire_department,
                    color: Colors.orange),

                const SizedBox(width: 5),

                Text(challenge.difficulty),
              ],
            ),

            const SizedBox(height: 18),

            const Divider(),

            const SizedBox(height: 10),

            const Text(
              "Creator Progress",
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

           LinearProgressIndicator(
  value: (challenge.creatorProgress / challenge.target)
      .clamp(0.0, 1.0),
),

            const SizedBox(height: 4),

            Text(
              "${challenge.creatorProgress}/${challenge.target}",
            ),

            const SizedBox(height: 18),

            const Text(
              "Friend Progress",
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            LinearProgressIndicator(
  value: (challenge.friendProgress / challenge.target)
      .clamp(0.0, 1.0),
),
            const SizedBox(height: 4),

            Text(
              "${challenge.friendProgress}/${challenge.target}",
            ),

            const SizedBox(height: 18),

            Row(
              children: [

                const Icon(
                  Icons.eco,
                  color: Colors.green,
                ),

                const SizedBox(width: 5),

                Text(
                  "${challenge.ecoReward}",
                ),

                const SizedBox(width: 20),

                const Icon(
                  Icons.favorite,
                  color: Colors.red,
                ),

                const SizedBox(width: 5),

                Text(
                  "${challenge.karmaReward}",
                ),

                const Spacer(),

                const Icon(Icons.schedule),

                const SizedBox(width: 5),

                Text(
                  "$remainingDays days",
                ),
              ],
            ),

            const SizedBox(height: 20),

            _buttons(context, ref),
          ],
        ),
      ),
    );
  }

  //-------------------------------------------------------

  Widget _statusChip() {
    Color color;

    switch (challenge.status) {
      case "pending":
        color = Colors.orange;
        break;

      case "ongoing":
        color = Colors.green;
        break;

      case "completed":
        color = Colors.blue;
        break;

      case "rejected":
        color = Colors.red;
        break;

      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(
        challenge.status.toUpperCase(),
      ),
     backgroundColor: color.withValues(alpha: 0.15),
    );
  }

  //----------------------------------------------------
  Widget _buttons(BuildContext context, WidgetRef ref) {
  if (challenge.status == "pending") {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () async {
              try {
                await ref
                    .read(challengeRepositoryProvider)
                    .acceptChallenge(challenge.id);

                ref.invalidate(challengesProvider);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Challenge accepted 🎉"),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                    ),
                  );
                }
              }
            },
            child: const Text("Accept"),
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              try {
                await ref
                    .read(challengeRepositoryProvider)
                    .rejectChallenge(challenge.id);

                ref.invalidate(challengesProvider);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Challenge rejected"),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                    ),
                  );
                }
              }
            },
            child: const Text("Reject"),
          ),
        ),
      ],
    );
  }

  if (challenge.status == "ongoing") {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          try {
            await ref
                .read(challengeRepositoryProvider)
                .updateProgress(challenge.id);

            ref.invalidate(challengesProvider);

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Progress updated 🚀"),
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(e.toString()),
                ),
              );
            }
          }
        },
        icon: const Icon(Icons.add),
        label: const Text("Update Progress"),
      ),
    );
  }

  if (challenge.status == "completed") {
    return const Center(
      child: Text(
        "🏆 Challenge Completed",
        style: TextStyle(
          color: Colors.green,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  return const Center(
    child: Text("Challenge Rejected"),
  );
}
}