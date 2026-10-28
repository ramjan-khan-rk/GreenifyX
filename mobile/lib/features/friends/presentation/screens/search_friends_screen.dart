import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_status.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../application/providers/friend_provider.dart';
import '../../application/providers/search_user_provider.dart';

class SearchFriendsScreen extends ConsumerStatefulWidget {
  const SearchFriendsScreen({super.key});

  @override
  ConsumerState<SearchFriendsScreen> createState() =>
      _SearchFriendsScreenState();
}

class _SearchFriendsScreenState extends ConsumerState<SearchFriendsScreen> {
  final controller = TextEditingController();
  String keyword = "";

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(searchUsersProvider(keyword));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Find friends", style: AppTextStyles.title),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: "Search by name",
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  keyword = value;
                });
              },
            ),
          ),
          Expanded(
            child: users.when(
              loading: () => const AppLoading(),
              error: (e, s) => AppErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(searchUsersProvider(keyword)),
              ),
              data: (list) {
                if (keyword.trim().isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.person_search_outlined,
                    title: "Search the community",
                    message: "Find people by name, then send a friend request.",
                  );
                }
                if (list.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.person_off_outlined,
                    title: "No matches",
                    message: "Try another name.",
                  );
                }

                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final user = list[index];
                    late final Widget button;

                    if (user.isFriend) {
                      button = const OutlinedButton(
                        onPressed: null,
                        child: Text("Friends"),
                      );
                    } else if (user.requestSent) {
                      button = const OutlinedButton(
                        onPressed: null,
                        child: Text("Pending"),
                      );
                    } else if (user.requestReceived) {
                      button = ElevatedButton(
                        onPressed: () async {
                          await ref
                              .read(friendRepositoryProvider)
                              .acceptRequest(user.id);
                          ref.invalidate(searchUsersProvider(keyword));
                        },
                        child: const Text("Accept"),
                      );
                    } else {
                      button = ElevatedButton(
                        onPressed: () async {
                          await ref
                              .read(friendRepositoryProvider)
                              .sendRequest(user.id);
                          ref.invalidate(searchUsersProvider(keyword));
                        },
                        child: const Text("Add"),
                      );
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: UserAvatar(
                          imageUrl: user.profileImage,
                          semanticLabel: "${user.name} photo",
                        ),
                        title: Text(
                          user.name.isEmpty ? "GreenifyX member" : user.name,
                        ),
                        subtitle: Text(
                          "${user.ecoPoints} Eco Points · Level ${user.level}",
                        ),
                        trailing: SizedBox(width: 108, child: button),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
