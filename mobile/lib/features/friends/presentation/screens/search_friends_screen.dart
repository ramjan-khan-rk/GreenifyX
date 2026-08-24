import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/friend_provider.dart';
import '../../application/providers/search_user_provider.dart';

class SearchFriendsScreen extends ConsumerStatefulWidget {
  const SearchFriendsScreen({super.key});

  @override
  ConsumerState<SearchFriendsScreen> createState() =>
      _SearchFriendsScreenState();
}

class _SearchFriendsScreenState
    extends ConsumerState<SearchFriendsScreen> {

  final controller = TextEditingController();

  String keyword = "";

  @override
  Widget build(BuildContext context) {

    final users = ref.watch(
      searchUsersProvider(keyword),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Friends"),
      ),

      body: Column(
        children: [

          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: controller,

              decoration: InputDecoration(
                hintText: "Search by name...",
                prefixIcon: const Icon(Icons.search),

                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                ),
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

              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),

              error: (e, s) => Center(
                child: Text(e.toString()),
              ),

              data: (list) {

print("LIST LENGTH: ${list.length}");

for (final u in list) {
  print("UI USER: ${u.name}");
}


                if (list.isEmpty) {
                  return const Center(
                    child: Text("No users found"),
                  );
                }

                return ListView.builder(

                  itemCount: list.length,

                  itemBuilder: (context, index) {

                    final user = list[index];

                    Widget button;

                    if (user.isFriend) {

                      button = ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: const Text("Friend"),
                      );

                    } else if (user.requestSent) {

                      button = ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: const Text("Pending"),
                      );

                    } else if (user.requestReceived) {

                      button = ElevatedButton(

                        onPressed: () async {

                          await ref
                              .read(friendRepositoryProvider)
                              .acceptRequest(user.id);

                          ref.invalidate(
                            searchUsersProvider(keyword),
                          );

                        },

                        child: const Text("Accept"),
                      );

                    } else {

                      button = ElevatedButton(

                        onPressed: () async {

                          await ref
                              .read(friendRepositoryProvider)
                              .sendRequest(user.id);

                          ref.invalidate(
                            searchUsersProvider(keyword),
                          );

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

                        leading: CircleAvatar(

                          backgroundImage:
                              user.profileImage.isNotEmpty
                                  ? NetworkImage(
                                      "http://10.255.139.39:5000/uploads/${user.profileImage}",
                                    )
                                  : null,

                          child: user.profileImage.isEmpty
                              ? const Icon(Icons.person)
                              : null,
                        ),

                        title: Text(
                          user.name.isEmpty
                              ? "Greenify User"
                              : user.name,
                        ),

                        subtitle: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,

                          children: [

                            Text(
                              "🌱 ${user.ecoScore} Eco Points",
                            ),

                            Text(
                              "Level ${user.level}",
                            ),

                          ],
                        ),

                        trailing: SizedBox(
  width: 100,
  child: button,
),
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