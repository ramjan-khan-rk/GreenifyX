import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/socket_service.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../friends/presentation/screens/friends_screen.dart';
import '../../../chat/presentation/screens/chats_screen.dart';
import '../../../chat/application/providers/chat_provider.dart';
import '../../../chat/application/providers/chats_provider.dart';
import '../../../profile/presentation/screens/account_screen.dart';
import '../../../post/presentation/screens/create_post_screen.dart';
import '../../../feed/presentation/screens/feed_screen.dart';
import '../../../challenge/application/providers/challenge_provider.dart';
import '../../../notifications/application/providers/notification_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/count_badge.dart';
import '../../../friends/application/providers/friend_provider.dart';

class BottomNavScreen extends ConsumerStatefulWidget {
  const BottomNavScreen({super.key});

  @override
  ConsumerState<BottomNavScreen> createState() => _BottomNavScreenState();
}

class _BottomNavScreenState extends ConsumerState<BottomNavScreen> {
  int currentIndex = 0;
  final pages = const [
    HomeScreen(),
    FeedScreen(),
    FriendsScreen(),
    ChatsScreen(),
    AccountScreen(),
  ];

  void _onRealtimeEvent(dynamic _) {
    ref.invalidate(chatsProvider);
    ref.invalidate(chatProvider);
    ref.invalidate(challengesProvider);
    ref.invalidate(notificationsProvider);
  }

  @override
  void initState() {
    super.initState();
    final socket = SocketService.instance;
    socket.on("receiveMessage", _onRealtimeEvent);
    socket.on("challengeReceived", _onRealtimeEvent);
    socket.on("challengeAccepted", _onRealtimeEvent);
    socket.on("challengeRejected", _onRealtimeEvent);
    socket.on("challengeCompleted", _onRealtimeEvent);
    socket.on("newNotification", _onRealtimeEvent);
  }

  @override
  void dispose() {
    final socket = SocketService.instance;
    socket.off("receiveMessage");
    socket.off("challengeReceived");
    socket.off("challengeAccepted");
    socket.off("challengeRejected");
    socket.off("challengeCompleted");
    socket.off("newNotification");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unreadNotes = ref.watch(unreadNotificationCountProvider);
    final unreadChats = ref.watch(chatsProvider).maybeWhen(
          data: (list) => list.where((chat) => chat.unread).length,
          orElse: () => 0,
        );
    final pendingFriends = ref.watch(requestsProvider).maybeWhen(
          data: (list) => list.length,
          orElse: () => 0,
        );

    return Scaffold(
      body: pages[currentIndex],
      floatingActionButton: FloatingActionButton(
        heroTag: "create_post",
        tooltip: "Share an eco activity",
        backgroundColor: AppColors.primary,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreatePostScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: CountBadge(
              count: unreadNotes,
              child: const Icon(Icons.home),
            ),
            label: "Home",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.public),
            label: "Explore",
          ),
          BottomNavigationBarItem(
            icon: CountBadge(
              count: pendingFriends,
              child: const Icon(Icons.people),
            ),
            label: "Friends",
          ),
          BottomNavigationBarItem(
            icon: CountBadge(
              count: unreadChats,
              child: const Icon(Icons.chat),
            ),
            label: "Chat",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}
