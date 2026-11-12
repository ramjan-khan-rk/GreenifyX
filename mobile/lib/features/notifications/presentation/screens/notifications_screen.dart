import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/chat_launcher.dart';
import '../../../../core/utils/friendly_error.dart';
import '../../../../core/widgets/app_status.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../campaign/presentation/screens/points_history_screen.dart';
import '../../../campaign/presentation/screens/verifier_home_screen.dart';
import '../../../challenge/presentation/screens/challenge_screen.dart';
import '../../../feed/presentation/screens/feed_screen.dart';
import '../../../friends/presentation/screens/friends_screen.dart';
import '../../../issues/presentation/issues_hub_screen.dart';
import '../../../events/events_screen.dart';
import '../../../pickup/pickup_screen.dart';
import '../../../rewards/rewards_screen.dart';
import '../../application/providers/notification_provider.dart';
import '../../domain/models/notification_model.dart';
import 'package:greenifyx/core/i18n/app_locale.dart';

({IconData icon, Color color}) _style(String type) => switch (type) {
      "message" => (icon: Icons.chat_bubble_rounded, color: AppColors.primary),
      "call" => (icon: Icons.call_missed_rounded, color: AppColors.error),
      "friend_request" || "friend_accept" => (icon: Icons.person_add_alt_1_rounded, color: const Color(0xFF4A78B5)),
      "like" => (icon: Icons.favorite_rounded, color: AppColors.error),
      "comment" => (icon: Icons.mode_comment_rounded, color: const Color(0xFF4A78B5)),
      "points" => (icon: Icons.stars_rounded, color: const Color(0xFFB07A00)),
      "campaign" => (icon: Icons.forest_rounded, color: AppColors.eco),
      "verification" => (icon: Icons.verified_rounded, color: AppColors.eco),
      "reward" => (icon: Icons.redeem_rounded, color: AppColors.joy),
      "pickup" => (icon: Icons.local_shipping_rounded, color: AppColors.eco),
      "event" => (icon: Icons.event_rounded, color: const Color(0xFF0083B0)),
      _ when type.startsWith("challenge") => (icon: Icons.emoji_events_rounded, color: const Color(0xFFB07A00)),
      _ => (icon: Icons.notifications_rounded, color: AppColors.subtitle),
    };

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return "now";
  if (d.inMinutes < 60) return "${d.inMinutes}m";
  if (d.inHours < 24) return "${d.inHours}h";
  if (d.inDays < 7) return "${d.inDays}d";
  return DateFormat("d MMM").format(t);
}

/// Opens the screen a notification is about.
void openNotification(BuildContext context, AppNotification n) {
  Widget? page;
  switch (n.type) {
    case "message":
    case "call":
      if (n.senderId.isNotEmpty) {
        openChat(context, userId: n.senderId, name: n.senderName.isEmpty ? "Friend" : n.senderName, profileImage: n.senderImage);
      }
      return;
    case "friend_request":
    case "friend_accept":
      page = const FriendsScreen();
    case "like":
    case "comment":
      page = const FeedScreen();
    case "points":
      page = const PointsHistoryScreen();
    case "reward":
      page = const RewardsScreen();
    case "pickup":
      page = const PickupScreen();
    case "event":
      page = const EventsScreen();
    case "campaign":
      page = const VerifierHomeScreen();
    case "verification":
      page = n.title.toLowerCase().startsWith("report") ? const IssuesHubScreen() : const PointsHistoryScreen();
    default:
      if (n.type.startsWith("challenge")) page = const ChallengeScreen();
  }
  if (page != null) Navigator.push(context, MaterialPageRoute(builder: (_) => page!));
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(tr("Updates"), style: AppTextStyles.title),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationApiProvider).markAllRead();
              ref.invalidate(notificationsProvider);
            },
            child: Text(tr("Mark all read")),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.invalidate(notificationsProvider),
        child: notifications.when(
          loading: () => const AppLoading(),
          error: (error, _) => AppErrorState(message: friendlyError(error), onRetry: () => ref.invalidate(notificationsProvider)),
          data: (list) {
            if (list.isEmpty) {
              return AppEmptyState(
                icon: Icons.notifications_none_outlined,
                title: tr("You're all caught up"),
                message: tr("Messages, calls, friend requests, likes and points will show up here."),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              itemCount: list.length,
              itemBuilder: (context, i) => _Row(
                n: list[i],
                onTap: () async {
                  final n = list[i];
                  if (!n.isRead) {
                    ref.read(notificationApiProvider).markRead(n.id).then((_) => ref.invalidate(notificationsProvider)).catchError((_) {});
                  }
                  openNotification(context, n);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final AppNotification n;
  final VoidCallback onTap;
  const _Row({required this.n, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final st = _style(n.type);
    final canReply = n.type == "message" || n.type == "call";
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: n.isRead ? Colors.white : AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: n.isRead ? AppColors.border : AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(clipBehavior: Clip.none, children: [
              n.senderImage.isNotEmpty || n.senderName.isNotEmpty
                  ? UserAvatar(imageUrl: n.senderImage, radius: 22)
                  : CircleAvatar(radius: 22, backgroundColor: st.color.withValues(alpha: 0.12), child: Icon(st.icon, color: st.color)),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: st.color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                  child: Icon(st.icon, size: 11, color: Colors.white),
                ),
              ),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(n.title,
                        style: TextStyle(fontWeight: n.isRead ? FontWeight.w700 : FontWeight.w800, color: AppColors.ink)),
                  ),
                  Text(_ago(n.createdAt), style: const TextStyle(color: AppColors.subtitle, fontSize: 12)),
                ]),
                const SizedBox(height: 2),
                Text(n.message, style: const TextStyle(color: AppColors.subtitle, height: 1.35)),
                if (canReply && n.senderId.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 12)),
                      onPressed: onTap,
                      icon: const Icon(Icons.reply_rounded, size: 16),
                      label: Text(tr("Reply")),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        foregroundColor: AppColors.eco,
                      ),
                      onPressed: () => startCall(context, userId: n.senderId, name: n.senderName, video: false),
                      icon: const Icon(Icons.call_rounded, size: 16),
                      label: Text(tr("Call back")),
                    ),
                  ]),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
