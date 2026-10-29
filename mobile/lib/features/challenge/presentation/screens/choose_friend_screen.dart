import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/media_url.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
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

class _ChooseFriendScreenState extends ConsumerState<ChooseFriendScreen> {
  final TextEditingController searchController = TextEditingController();
  FriendModel? selectedFriend;
  bool sending = false;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (selectedFriend == null || sending) return;

    setState(() => sending = true);

    try {
      await ref.read(challengeRepositoryProvider).createChallenge(
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
        const SnackBar(content: Text("Challenge sent")),
      );

      ref.invalidate(challengesProvider);
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => sending = false);
    }
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
          "Choose opponent",
          style: AppTextStyles.title.copyWith(fontSize: 20),
        ),
      ),
      body: friends.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (list) {
          final filtered = list.where((friend) {
            return friend.name
                .toLowerCase()
                .contains(searchController.text.toLowerCase());
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: "Search friends",
                    prefixIcon: const Icon(Icons.search),
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
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          "No friends match your search",
                          style: AppTextStyles.subtitle,
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final friend = filtered[index];
                          final selected = selectedFriend?.id == friend.id;

                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                setState(() => selectedFriend = friend);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.primary
                                        : AppColors.border,
                                    width: selected ? 1.6 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: AppColors.primary
                                          .withValues(alpha: 0.12),
                                      backgroundImage:
                                          friend.profileImage.isNotEmpty
                                              ? NetworkImage(
                                                  resolveMediaUrl(
                                                        friend.profileImage,
                                                      ) ??
                                                      "",
                                                )
                                              : null,
                                      child: friend.profileImage.isEmpty
                                          ? const Icon(
                                              Icons.person,
                                              color: AppColors.primary,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            friend.name,
                                            style: AppTextStyles.body.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "Level ${friend.level} · ${friend.ecoPoints} Eco Points",
                                            style: AppTextStyles.subtitle
                                                .copyWith(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      selected
                                          ? Icons.check_circle
                                          : Icons.circle_outlined,
                                      color: selected
                                          ? AppColors.primary
                                          : Colors.grey.shade400,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed:
                          selectedFriend == null || sending ? null : _send,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppColors.primary.withValues(alpha: 0.4),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        sending ? "Sending..." : "Send challenge",
                      ),
                    ),
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
