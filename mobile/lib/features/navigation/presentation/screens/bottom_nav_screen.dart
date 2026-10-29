import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/socket_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/brand_icons.dart';
import '../../../../core/widgets/count_badge.dart';
import '../../../challenge/application/providers/challenge_provider.dart';
import '../../../challenge/presentation/screens/challenge_screen.dart';
import '../../../chat/application/providers/chat_provider.dart';
import '../../../chat/application/providers/chats_provider.dart';
import '../../../friends/application/providers/friend_provider.dart';
import '../../../friends/presentation/screens/friends_screen.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../home/presentation/screens/leaderboard_screen.dart';
import '../../../notifications/application/providers/notification_provider.dart';
import '../../../profile/presentation/screens/account_screen.dart';

class BottomNavScreen extends ConsumerStatefulWidget {
  const BottomNavScreen({super.key});

  @override
  ConsumerState<BottomNavScreen> createState() => _BottomNavScreenState();
}

class _BottomNavScreenState extends ConsumerState<BottomNavScreen> {
  int currentIndex = 0;
  final pages = const [
    HomeScreen(),
    FriendsScreen(),
    ChallengeScreen(),
    LeaderboardScreen(),
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
    final pendingFriends = ref.watch(requestsProvider).maybeWhen(
          data: (list) => list.length,
          orElse: () => 0,
        );

    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.navy,
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
              child: const Icon(BrandGlyph.home),
            ),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: CountBadge(
              count: pendingFriends,
              child: const Icon(BrandGlyph.friends),
            ),
            label: "Friends",
          ),
          const BottomNavigationBarItem(
            icon: Icon(BrandGlyph.challenges),
            label: "Challenges",
          ),
          const BottomNavigationBarItem(
            icon: Icon(BrandGlyph.leaderboard),
            label: "Leaderboard",
          ),
          const BottomNavigationBarItem(
            icon: Icon(BrandGlyph.profile),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}
