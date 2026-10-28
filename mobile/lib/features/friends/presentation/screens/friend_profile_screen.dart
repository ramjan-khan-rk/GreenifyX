import 'package:flutter/material.dart';

import '../../../../core/utils/media_url.dart';
import '../../domain/models/friend_model.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
class FriendProfileScreen extends StatelessWidget {
  final FriendModel friend;

  const FriendProfileScreen({
    super.key,
    required this.friend,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(friend.name),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            CircleAvatar(
              radius: 55,
              backgroundImage: friend.profileImage.isNotEmpty
                  ? NetworkImage(
                      resolveMediaUrl(friend.profileImage) ?? "",
                    )
                  : null,
              child: friend.profileImage.isEmpty
                  ? const Icon(Icons.person,size:55)
                  : null,
            ),

            const SizedBox(height:20),

            Text(
              friend.name,
              style: const TextStyle(
                fontSize:24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height:8),

            Text(friend.bio),

            const SizedBox(height:30),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [

                    ListTile(
                      leading: const Icon(Icons.eco),
                      title: const Text("Eco Points"),
                      trailing: Text(friend.ecoPoints.toString()),
                    ),

                    ListTile(
                      leading: const Icon(Icons.star),
                      title: const Text("Level"),
                      trailing: Text(friend.level.toString()),
                    ),

                    ListTile(
                      leading: const Icon(Icons.local_fire_department),
                      title: const Text("Streak"),
                      trailing: Text(friend.streak.toString()),
                    ),

                  ],
                ),
              ),
            ),

            const SizedBox(height:30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.chat),
                label: const Text("Message"),
                onPressed: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChatScreen(
        userId: friend.id,
        userName: friend.name,
      ),
    ),
  );
},
              ),
            ),

          ],
        ),
      ),
    );
  }
}