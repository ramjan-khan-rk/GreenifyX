import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/profile_provider.dart';
import '../../application/providers/my_profile_provider.dart';
import 'package:go_router/go_router.dart';
import '../../../friends/application/providers/friend_provider.dart';
import '../../../chat/application/providers/chats_provider.dart';
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final profile = ref.watch(myProfileProvider);

    return Scaffold(

      appBar: AppBar(
        title: const Text("My Account"),
      ),

      body: profile.when(

        loading: ()=>const Center(
          child:CircularProgressIndicator(),
        ),

        error:(e,s)=>Center(
          child:Text(e.toString()),
        ),

        data:(user){

          return RefreshIndicator(

            onRefresh:()async{

              ref.invalidate(myProfileProvider);

            },

            child:ListView(

              padding:const EdgeInsets.all(20),

              children:[

                Center(

                  child:CircleAvatar(

                    radius:60,

                    backgroundImage:
                    user.profileImage.isNotEmpty

                    ? NetworkImage(
                      "http://10.255.139.39:5000/uploads/${user.profileImage}",
                    )

                    :null,

                    child:user.profileImage.isEmpty

                    ?const Icon(
                      Icons.person,
                      size:60,
                    )

                    :null,

                  ),

                ),

                const SizedBox(height:20),

                Center(

                  child:Text(

                    user.name,

                    style:const TextStyle(

                      fontSize:26,
                      fontWeight:FontWeight.bold,

                    ),

                  ),

                ),

                const SizedBox(height:8),

                Center(
                  child:Text(user.bio),
                ),

                const SizedBox(height:30),

                _card(
                  "Eco Points",
                  user.ecoPoints.toString(),
                  Icons.eco,
                  Colors.green,
                ),

                const SizedBox(height:12),

                Row(

                  children:[

                    Expanded(
                      child:_card(
                        "Level",
                        user.level.toString(),
                        Icons.star,
                        Colors.orange,
                      ),
                    ),

                    const SizedBox(width:12),

                    Expanded(
                      child:_card(
                        "Streak",
                        user.streak.toString(),
                        Icons.local_fire_department,
                        Colors.deepOrange,
                      ),
                    ),

                  ],

                ),

                const SizedBox(height:12),

                _card(
                  "Friends",
                  user.friendsCount.toString(),
                  Icons.people,
                  Colors.blue,
                ),

                const SizedBox(height:30),

                ElevatedButton.icon(

                  onPressed:(){

                    // next

                  },

                  icon:const Icon(Icons.edit),

                  label:const Text("Edit Profile"),

                ),

                const SizedBox(height:12),

                ElevatedButton.icon(

                  onPressed:(){

                    // next

                  },

                  icon:const Icon(Icons.people),

                  label:const Text("My Friends"),

                ),

                const SizedBox(height:12),

                ElevatedButton.icon(

                  style:ElevatedButton.styleFrom(
                    backgroundColor:Colors.red,
                  ),

                 
onPressed: () async {
  await ref.read(profileProvider.notifier).logout();

  ref.invalidate(myProfileProvider);
  ref.invalidate(friendsProvider);
  ref.invalidate(requestsProvider);
  ref.invalidate(chatsProvider);

  if (context.mounted) {
    context.go("/login");
  }
}, // <-- THIS COMMA WAS MISSING

icon: const Icon(Icons.logout),

label: const Text("Logout"),
)

              ],

            ),

          );

        },

      ),

    );

  }

  Widget _card(
      String title,
      String value,
      IconData icon,
      Color color){

    return Card(

      child:Padding(

        padding:const EdgeInsets.all(18),

        child:Column(

          children:[

            Icon(icon,color:color),

            const SizedBox(height:8),

            Text(

              value,

              style:const TextStyle(

                fontWeight:FontWeight.bold,
                fontSize:22,

              ),

            ),

            Text(title),

          ],

        ),

      ),

    );

  }

}