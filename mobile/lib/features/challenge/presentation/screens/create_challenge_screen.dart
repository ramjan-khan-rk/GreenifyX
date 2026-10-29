import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../friends/application/providers/friend_provider.dart';
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
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();

  String activity = "Plant Tree";
  String category = "Environment";
  String difficulty = "Easy";
  int target = 10;
  DateTime deadline = DateTime.now().add(const Duration(days: 7));

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
      case "Medium":
        return 50;
      case "Hard":
        return 100;
      default:
        return 20;
    }
  }

  Future<void> pickDeadline() async {
    final date = await showDatePicker(
      context: context,
      initialDate: deadline,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() => deadline = date);
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          "New challenge",
          style: AppTextStyles.title.copyWith(fontSize: 20),
        ),
      ),
      body: friends.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(e.toString(), textAlign: TextAlign.center),
          ),
        ),
        data: (friendList) {
          if (friendList.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Add a friend first",
                    style: AppTextStyles.title.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Challenges are head-to-head. Connect with at least one friend, then come back to create one.",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitle.copyWith(height: 1.45),
                  ),
                ],
              ),
            );
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  "Define the goal",
                  style: AppTextStyles.subtitle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: titleController,
                  decoration: _decoration("Challenge title"),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Title is required";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: _decoration("Description (optional)"),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: activity,
                  decoration: _decoration("Activity"),
                  items: activities
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => activity = value!);
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: _decoration("Category"),
                  items: categories
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => category = value!);
                  },
                ),
                const SizedBox(height: 22),
                Text(
                  "Difficulty",
                  style: AppTextStyles.subtitle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: "Easy", label: Text("Easy")),
                    ButtonSegment(value: "Medium", label: Text("Medium")),
                    ButtonSegment(value: "Hard", label: Text("Hard")),
                  ],
                  selected: {difficulty},
                  onSelectionChanged: (value) {
                    setState(() => difficulty = value.first);
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return AppColors.primary.withValues(alpha: 0.12);
                      }
                      return Colors.white;
                    }),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  "Target count",
                  style: AppTextStyles.subtitle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          if (target > 1) setState(() => target--);
                        },
                        icon: const Icon(Icons.remove_circle_outline),
                        color: AppColors.primary,
                      ),
                      Expanded(
                        child: Text(
                          "$target",
                          textAlign: TextAlign.center,
                          style: AppTextStyles.title.copyWith(fontSize: 28),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => target++),
                        icon: const Icon(Icons.add_circle_outline),
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    leading: const Icon(
                      Icons.calendar_month_outlined,
                      color: AppColors.primary,
                    ),
                    title: const Text("Deadline"),
                    subtitle: Text(
                      "${deadline.day}/${deadline.month}/${deadline.year}",
                    ),
                    trailing: TextButton(
                      onPressed: pickDeadline,
                      child: const Text("Change"),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.12),
                        AppColors.primaryLight.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.eco, color: AppColors.primary, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Winner reward",
                              style: AppTextStyles.subtitle.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                            ),
                            Text(
                              "$ecoReward Eco Points",
                              style: AppTextStyles.title.copyWith(
                                fontSize: 22,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!_formKey.currentState!.validate()) return;

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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text("Choose opponent"),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
