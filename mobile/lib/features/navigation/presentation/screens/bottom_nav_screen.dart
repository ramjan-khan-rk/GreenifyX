import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/socket_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/count_badge.dart';
import '../../../challenge/application/providers/challenge_provider.dart';
import '../../../campaign/application/campaign_providers.dart';
import '../../../campaign/presentation/screens/campaigns_screen.dart';
import '../../../chat/application/providers/chat_provider.dart';
import '../../../chat/application/providers/chats_provider.dart';
import '../../../chat/application/call_coordinator.dart';
import '../../../chat/presentation/screens/call_screen.dart';
import '../../../chat/presentation/screens/chats_screen.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../../../core/utils/chat_launcher.dart';
import '../../../feed/presentation/screens/feed_screen.dart';
import '../../../feed/application/feed_audio.dart';
import '../../../friends/application/providers/friend_provider.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../notifications/application/providers/notification_provider.dart';
import '../../../profile/presentation/screens/account_screen.dart';
import '../../../../core/i18n/app_locale.dart';
import '../../../../core/services/push_service.dart';
import '../../../../core/services/session_user.dart';
import '../../../auth/application/providers/auth_provider.dart';

class BottomNavScreen extends ConsumerStatefulWidget {
  const BottomNavScreen({super.key});

  @override
  ConsumerState<BottomNavScreen> createState() => _BottomNavScreenState();
}

class _BottomNavScreenState extends ConsumerState<BottomNavScreen> {
  int currentIndex = 0;
  bool _callOpen = false;
  final pages = const [
    HomeScreen(),
    CampaignsScreen(),
    FeedScreen(),
    ChatsScreen(),
    AccountScreen(),
  ];

  /// Shows a "Reply" popup for new messages unless that chat is already open.
  void _onMessagePopup(dynamic raw) {
    if (!mounted || raw is! Map) return;
    final sender = raw["sender"];
    if (sender is! Map) return;
    final id = sender["_id"]?.toString() ?? "";
    if (id.isEmpty || ChatScreen.activeUserId == id) return;
    final name = sender["name"]?.toString() ?? "Friend";
    final image = sender["profileImage"]?.toString() ?? "";
    final type = raw["messageType"]?.toString() ?? "text";
    final preview = type == "audio" ? "🎤 Voice note" : type == "image" ? "📷 Photo" : raw["text"]?.toString() ?? "";
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 5),
      content: Text("$name: $preview", maxLines: 2, overflow: TextOverflow.ellipsis),
      action: SnackBarAction(
        label: tr("Reply"),
        textColor: AppColors.sun,
        onPressed: () => openChat(context, userId: id, name: name, profileImage: image),
      ),
    ));
  }

  void _onRealtimeEvent(dynamic _) {
    ref.invalidate(chatsProvider);
    ref.invalidate(chatProvider);
    ref.invalidate(challengesProvider);
    ref.invalidate(notificationsProvider);
    // Points and campaign status change when a report is approved.
    ref.invalidate(campaignsProvider("mine"));
    ref.invalidate(myPointsProvider);
  }

  @override
  void initState() {
    super.initState();
    final socket = SocketService.instance;
    socket.on("receiveMessage", _onRealtimeEvent);
    socket.on("receiveMessage", _onMessagePopup);
    socket.on("challengeReceived", _onRealtimeEvent);
    socket.on("challengeAccepted", _onRealtimeEvent);
    socket.on("challengeRejected", _onRealtimeEvent);
    socket.on("challengeCompleted", _onRealtimeEvent);
    socket.on("newNotification", _onRealtimeEvent);
    final calls = CallCoordinator.instance;
    calls.bind();
    calls.addListener(_onIncomingCall);
    PushService.instance.register();
  }

  void _onIncomingCall() {
    final call = CallCoordinator.instance;
    if (!mounted || _callOpen || call.phase != "incoming") return;
    _callOpen = true;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CallScreen()),
    ).whenComplete(() => _callOpen = false);
  }

  @override
  void dispose() {
    final socket = SocketService.instance;
    socket.off("receiveMessage", _onRealtimeEvent);
    socket.off("receiveMessage", _onMessagePopup);
    socket.off("challengeReceived", _onRealtimeEvent);
    socket.off("challengeAccepted", _onRealtimeEvent);
    socket.off("challengeRejected", _onRealtimeEvent);
    socket.off("challengeCompleted", _onRealtimeEvent);
    socket.off("newNotification", _onRealtimeEvent);
    CallCoordinator.instance.removeListener(_onIncomingCall);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authProvider).user;
    if (me != null) SessionUser.update(id: me.id, name: me.name, profileImage: me.profileImage);
    final unreadNotes = ref.watch(unreadNotificationCountProvider);
    final pendingFriends = ref.watch(requestsProvider).maybeWhen(
          data: (list) => list.length,
          orElse: () => 0,
        );

    final unreadChats = ref.watch(chatsProvider).maybeWhen(
          data: (list) => list.where((c) => c.unread).length,
          orElse: () => 0,
        );

    return Scaffold(
      // Keeps each tab's scroll position and state when switching.
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, -4))],
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) {
            // Feed soundtracks stop when you leave the feed.
            if (index != currentIndex) FeedAudio.instance.stop();
            setState(() => currentIndex = index);
          },
          destinations: [
            NavigationDestination(
              icon: CountBadge(count: unreadNotes, child: const Icon(Icons.home_outlined)),
              selectedIcon: CountBadge(count: unreadNotes, child: const Icon(Icons.home_rounded)),
              label: tr("Home"),
            ),
            NavigationDestination(
              icon: const Icon(Icons.forest_outlined),
              selectedIcon: const Icon(Icons.forest_rounded),
              label: tr("Campaigns"),
            ),
            NavigationDestination(
              icon: const Icon(Icons.auto_awesome_outlined),
              selectedIcon: const Icon(Icons.auto_awesome_rounded),
              label: tr("Moments"),
            ),
            NavigationDestination(
              icon: CountBadge(count: unreadChats, child: const Icon(Icons.chat_bubble_outline_rounded)),
              selectedIcon: CountBadge(count: unreadChats, child: const Icon(Icons.chat_bubble_rounded)),
              label: tr("Chat"),
            ),
            NavigationDestination(
              icon: CountBadge(count: pendingFriends, child: const Icon(Icons.person_outline_rounded)),
              selectedIcon: CountBadge(count: pendingFriends, child: const Icon(Icons.person_rounded)),
              label: tr("Profile"),
            ),
          ],
        ),
      ),
    );
  }
}
