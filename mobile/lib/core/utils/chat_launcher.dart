import 'package:flutter/material.dart';

import '../../features/chat/application/call_coordinator.dart';
import '../../features/chat/presentation/screens/call_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';

/// One place to open a chat or start a call, so every screen behaves the same.
Future<void> openChat(BuildContext context, {required String userId, required String name, String profileImage = ""}) {
  return Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ChatScreen(userId: userId, userName: name, profileImage: profileImage)),
  );
}

Future<void> startCall(BuildContext context, {required String userId, required String name, required bool video}) async {
  final call = CallCoordinator.instance;
  if (call.busy) {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const CallScreen()));
    return;
  }
  final screen = Navigator.push(context, MaterialPageRoute(builder: (_) => const CallScreen()));
  await call.start(userId: userId, userName: name, withVideo: video);
  await screen;
}
