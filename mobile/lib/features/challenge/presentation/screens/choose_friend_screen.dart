import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../friends/application/providers/friend_provider.dart';
import '../../../friends/domain/models/friend_model.dart';
import '../../application/providers/challenge_provider.dart';

class ChooseFriendScreen extends ConsumerStatefulWidget {
  final String title;
  final String description;
  final String activity;
  final String category;
  final String difficulty;
  final int target;

  final DateTime deadline;

  const ChooseFriendScreen({
    super.key,
    required this.title,
    required this.description,
    required this.activity,
    required this.category,
    required this.difficulty,
    required this.target,
    required this.deadline,
  });

  @override
  ConsumerState<ChooseFriendScreen> createState() =>
      _ChooseFriendScreenState();
}

class _ChooseFriendScreenState
    extends ConsumerState<ChooseFriendScreen> {
  final TextEditingController searchController =
      TextEditingController();

  FriendModel? selectedFriend;

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Choose Friend"),
      ),

      body: friends.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),

        error: (e, s) => Center(
          child: Text(e.toString()),
        ),

        data: (list) {
          final filtered = list.where((friend) {
            return friend.name
                .toLowerCase()
                .contains(
                  searchController.text.toLowerCase(),
                );
          }).toList();

          return Column(
            children: [

              //----------------------------------

              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: "Search friend",
                    prefixIcon:
                        const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                  ),
                  onChanged: (_) {
                    setState(() {});
                  },
                ),
              ),

              //----------------------------------

              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text(
                          "No Friends Found",
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final friend =
                              filtered[index];

                          final selected =
                              selectedFriend?.id ==
                                  friend.id;

                          return Card(
                            margin:
                                const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            child: ListTile(
                              onTap: () {
                                setState(() {
                                  selectedFriend =
                                      friend;
                                });
                              },

                              leading: CircleAvatar(
                                radius: 24,
                                backgroundImage:
                                    friend.profileImage
                                            .isNotEmpty
                                        ? NetworkImage(
                                            "http://10.255.139.39:5000/uploads/${friend.profileImage}",
                                          )
                                        : null,
                                child:
                                    friend.profileImage
                                            .isEmpty
                                        ? const Icon(
                                            Icons.person,
                                          )
                                        : null,
                              ),

                              title: Text(
                                friend.name,
                              ),

                              subtitle: Text(
                                "Level ${friend.level}   •   Eco ${friend.ecoScore}",
                              ),

                              trailing: Icon(
                                selected
                                    ? Icons
                                        .radio_button_checked
                                    : Icons
                                        .radio_button_off,
                                color: selected
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                            ),
                          );
                        },
                      ),
              ),

              //----------------------------------

              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.send),

                    label: const Text(
                      "Send Challenge",
                    ),

                    onPressed: selectedFriend == null
    ? null
    : () async {
        try {
          await ref
              .read(challengeRepositoryProvider)
              .createChallenge(
                friendId: selectedFriend!.id,
                title: widget.title,
                description: widget.description,
                activity: widget.activity,
                category: widget.category,
                difficulty: widget.difficulty,
                target: widget.target,
                deadline: widget.deadline,
              );

          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Challenge Sent Successfully 🎉",
              ),
            ),
          );

          ref.invalidate(challengesProvider);

          Navigator.popUntil(
            context,
            (route) => route.isFirst,
          );
        } catch (e) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
            ),
          );

          debugPrint(e.toString());
        }
      },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}