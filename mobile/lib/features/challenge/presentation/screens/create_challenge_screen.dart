import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../friends/application/providers/friend_provider.dart';
import '../../application/providers/challenge_provider.dart';
import 'choose_friend_screen.dart';
class CreateChallengeScreen extends ConsumerStatefulWidget {
  const CreateChallengeScreen({super.key});

  @override
  ConsumerState<CreateChallengeScreen> createState() =>
      _CreateChallengeScreenState();
}

class _CreateChallengeScreenState
    extends ConsumerState<CreateChallengeScreen> {

  final _formKey = GlobalKey<FormState>();

  final titleController =
      TextEditingController();

  final descriptionController =
      TextEditingController();

  String? selectedFriendId;

  String activity = "Plant Tree";

  String category = "Environment";

  String difficulty = "Easy";

  int target = 10;

  DateTime deadline =
      DateTime.now().add(
    const Duration(days: 7),
  );

  bool loading = false;

  final activities = const [

    "Plant Tree",

    "Clean Plastic",

    "Cycle Ride",

    "Save Water",

    "Use Public Transport",

    "Clean Park",

    "Energy Saving",

    "Beach Cleanup",

    "River Cleanup",

  ];

  final categories = const [

    "Environment",

    "Fitness",

    "Lifestyle",

    "Community",

  ];

  int get ecoReward {

    switch (difficulty) {

      case "Easy":
        return 20;

      case "Medium":
        return 50;

      case "Hard":
        return 100;

      default:
        return 20;

    }

  }

  int get karmaReward {

    switch (difficulty) {

      case "Easy":
        return 10;

      case "Medium":
        return 25;

      case "Hard":
        return 50;

      default:
        return 10;

    }

  }

  Future<void> pickDeadline() async {

    final date =
        await showDatePicker(

      context: context,

      initialDate: deadline,

      firstDate: DateTime.now(),

      lastDate:
      DateTime.now().add(
        const Duration(days: 365),
      ),

    );

    if (date != null) {

      setState(() {

        deadline = date;

      });

    }

  }

  @override
  void dispose() {

    titleController.dispose();

    descriptionController.dispose();

    super.dispose();

  }

  @override
  Widget build(BuildContext context) {

    final friends =
        ref.watch(friendsProvider);

    return Scaffold(

      appBar: AppBar(

        title:
        const Text(
          "Create Challenge",
        ),

      ),

      body: friends.when(

        loading: () =>
        const Center(
          child:
          CircularProgressIndicator(),
        ),

        error: (e, s) =>
            Center(
              child:
              Text(e.toString()),
            ),

        data: (friendList) {

          if (friendList.isEmpty) {

            return const Center(

              child: Text(
                "You need at least one friend to create a challenge.",
              ),

            );

          }

          selectedFriendId ??=
              friendList.first.id;

          return Form(

            key: _formKey,

            child: ListView(

              padding:
              const EdgeInsets.all(20),

              children: [

                const Text(

                  "Choose Friend",

                  style: TextStyle(

                    fontWeight:
                    FontWeight.bold,

                    fontSize: 16,

                  ),

                ),

                const SizedBox(height: 10),

                DropdownButtonFormField<String>(

                  value:
                  selectedFriendId,

                  decoration:
                  const InputDecoration(

                    border:
                    OutlineInputBorder(),

                  ),

                  items:
                  friendList.map((friend) {

                    return DropdownMenuItem(

                      value: friend.id,

                      child: Text(friend.name),

                    );

                  }).toList(),

                  onChanged: (value) {

                    setState(() {

                      selectedFriendId =
                          value;

                    });

                  },

                ),

                const SizedBox(height: 20),

                TextFormField(

                  controller:
                  titleController,

                  decoration:
                  const InputDecoration(

                    labelText:
                    "Challenge Title",

                    border:
                    OutlineInputBorder(),

                  ),

                  validator: (value) {

                    if (value == null ||
                        value.trim().isEmpty) {

                      return "Title required";

                    }

                    return null;

                  },

                ),

                const SizedBox(height: 20),

                TextFormField(

                  controller:
                  descriptionController,

                  maxLines: 3,

                  decoration:
                  const InputDecoration(

                    labelText:
                    "Description",

                    border:
                    OutlineInputBorder(),

                  ),

                ),

                const SizedBox(height: 20),

                DropdownButtonFormField<String>(

                  value: activity,

                  decoration:
                  const InputDecoration(

                    labelText: "Activity",

                    border:
                    OutlineInputBorder(),

                  ),

                  items:
                  activities.map((item) {

                    return DropdownMenuItem(

                      value: item,

                      child: Text(item),

                    );

                  }).toList(),

                  onChanged: (value) {

                    setState(() {

                      activity = value!;

                    });

                  },

                ),

                const SizedBox(height: 20),

                DropdownButtonFormField<String>(

                  value: category,

                  decoration:
                  const InputDecoration(

                    labelText:
                    "Category",

                    border:
                    OutlineInputBorder(),

                  ),

                  items:
                  categories.map((item) {

                    return DropdownMenuItem(

                      value: item,

                      child: Text(item),

                    );

                  }).toList(),

                  onChanged: (value) {

                    setState(() {

                      category = value!;

                    });

                  },

                ),
                                const SizedBox(height: 20),

                const Text(
                  "Difficulty",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: "Easy",
                      label: Text("Easy"),
                    ),
                    ButtonSegment(
                      value: "Medium",
                      label: Text("Medium"),
                    ),
                    ButtonSegment(
                      value: "Hard",
                      label: Text("Hard"),
                    ),
                  ],
                  selected: {difficulty},
                  onSelectionChanged: (value) {
                    setState(() {
                      difficulty = value.first;
                    });
                  },
                ),

                const SizedBox(height: 25),

                const Text(
                  "Target",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                Row(
                  children: [

                    IconButton(
                      onPressed: () {

                        if (target > 1) {

                          setState(() {

                            target--;

                          });

                        }

                      },
                      icon: const Icon(
                        Icons.remove_circle,
                      ),
                    ),

                    Expanded(
                      child: Center(
                        child: Text(
                          "$target",
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    IconButton(
                      onPressed: () {

                        setState(() {

                          target++;

                        });

                      },
                      icon: const Icon(
                        Icons.add_circle,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                ListTile(
  tileColor: Colors.grey.shade100,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),

  leading: const Icon(Icons.calendar_month),

  title: const Text("Deadline"),

  subtitle: Text(
    "${deadline.day}/${deadline.month}/${deadline.year}",
  ),

  trailing: SizedBox(
    width: 80,
    height: 36,
    child: ElevatedButton(
      onPressed: pickDeadline,
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.zero,
      ),
      child: const Text(
        "Change",
        style: TextStyle(fontSize: 12),
      ),
    ),
  ),
),

                const SizedBox(height: 25),

                Card(

                  child: Padding(

                    padding:
                        const EdgeInsets.all(18),

                    child: Column(

                      children: [

                        const Text(

                          "Reward Preview",

                          style: TextStyle(

                            fontSize: 18,

                            fontWeight:
                                FontWeight.bold,

                          ),

                        ),

                        const SizedBox(height: 20),

                        Row(

                          children: [

                            const Icon(
                              Icons.eco,
                              color: Colors.green,
                            ),

                            const SizedBox(width: 8),

                            Text(
                              "$ecoReward Eco Score",
                            ),

                            const Spacer(),

                            const Icon(
                              Icons.favorite,
                              color: Colors.red,
                            ),

                            const SizedBox(width: 8),

                            Text(
                              "$karmaReward Karma",
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 35),

               
                SizedBox(
  width: double.infinity,
  height: 55,
  child: ElevatedButton(
    onPressed: () {

      if (!_formKey.currentState!.validate()) {
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChooseFriendScreen(
            title: titleController.text.trim(),
            description: descriptionController.text.trim(),
            activity: activity,
            category: category,
            difficulty: difficulty,
            target: target,
            

            deadline: deadline,
          ),
        ),
      );

    },
    child: const Text("Continue"),
  ),
),

                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }
}