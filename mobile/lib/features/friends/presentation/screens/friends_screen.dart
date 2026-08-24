import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/friend_provider.dart';
import 'friend_profile_screen.dart';
import 'search_friends_screen.dart';

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final friends = ref.watch(friendsProvider);

    final requests = ref.watch(requestsProvider);

    return Scaffold(

      appBar: AppBar(

        title: const Text("Friends"),

        actions: [

          IconButton(

            icon: const Icon(Icons.person_add),

            onPressed: () {

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const SearchFriendsScreen(),
                ),
              );

            },

          ),

        ],

      ),

      body: RefreshIndicator(

        onRefresh: () async {

          ref.invalidate(friendsProvider);

          ref.invalidate(requestsProvider);

        },

        child: ListView(

          children: [

            const SizedBox(height:10),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal:16),
              child: Text(
                "Friend Requests",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize:18,
                ),
              ),
            ),

            requests.when(

              loading: () =>
                  const Center(
                    child: CircularProgressIndicator(),
                  ),

              error: (e,s)=>
                  const SizedBox(),

              data: (list){

                if(list.isEmpty){

                  return const Padding(

                    padding: EdgeInsets.all(16),

                    child: Text(
                      "No Friend Requests",
                    ),

                  );

                }

                return Column(

                  children: list.map((user){

                   return ListTile(
  leading: CircleAvatar(
    backgroundImage: user.profileImage.isNotEmpty
        ? NetworkImage(
            "http://10.255.139.39:5000/uploads/${user.profileImage}",
          )
        : null,
    child: user.profileImage.isEmpty
        ? const Icon(Icons.person)
        : null,
  ),

  title: Text(user.name),

  trailing: SizedBox(
    width: 90,
    child: ElevatedButton(
      onPressed: () async {
        await ref
            .read(friendRepositoryProvider)
            .acceptRequest(user.id);

        ref.invalidate(friendsProvider);
        ref.invalidate(requestsProvider);
      },
      child: const Text(
        "Accept",
        overflow: TextOverflow.ellipsis,
      ),
    ),
  ),
);

                  }).toList(),

                );

              },

            ),

            const Divider(),

            const Padding(

              padding: EdgeInsets.symmetric(horizontal:16),

              child: Text(
                "My Friends",
                style: TextStyle(
                  fontSize:18,
                  fontWeight: FontWeight.bold,
                ),
              ),

            ),

            friends.when(

              loading: ()=>const Center(
                child: CircularProgressIndicator(),
              ),

              error:(e,s)=>Center(
                child: Text(e.toString()),
              ),

              data:(list){

                if(list.isEmpty){

                  return const Padding(

                    padding: EdgeInsets.all(16),

                    child: Text(
                      "No Friends Yet",
                    ),

                  );

                }

                return Column(

                  children: list.map((friend){

                    return ListTile(

                      leading: CircleAvatar(

                        backgroundImage:
                        friend.profileImage.isNotEmpty
                            ? NetworkImage(
                          "http://10.255.139.39:5000/uploads/${friend.profileImage}",
                        )
                            : null,

                        child: friend.profileImage.isEmpty
                            ? const Icon(Icons.person)
                            : null,

                      ),

                      title: Text(friend.name),

                      subtitle: Text(
                        "Level ${friend.level}",
                      ),

                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size:16,
                      ),

                      onTap: (){

                        Navigator.push(

                          context,

                          MaterialPageRoute(

                            builder:(_)=>

                                FriendProfileScreen(
                                  friend: friend,
                                ),

                          ),

                        );

                      },

                    );

                  }).toList(),

                );

              },

            ),

          ],

        ),

      ),

    );

  }

}