import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../market/market_screens.dart';
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
      "listing" => (icon: Icons.autorenew_rounded, color: const Color(0xFFFF8008)),
      "tag" => (icon: Icons.alternate_email_rounded, color: AppColors.joy),
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
    case "listing":
      page = const MarketScreen();
    case "tag":
      page = const FeedScreen();
    case "campaign":
      page = const VerifierHomeScreen();
    case "verification":
      page = n.title.toLowerCase().startsWith("report") ? const IssuesHubScreen() : const PointsHistoryScreen();
    default:
      if (n.type.startsWith("challenge")) page = const ChallengeScreen();
  }
  if (page != null) Navigator.push(context, MaterialPageRoute(builder: (_) => page!));
}

typedef _J = Map<String, dynamic>;

/// One row in the inbox; may bundle several notifications ("Sara and 3 others liked your post").
class _Item {
  final String key;
  final List<String> ids;
  final String type;
  final String title;
  final String message;
  final String referenceId;
  final List<_J> senders;
  final int count;
  bool isRead;
  final DateTime createdAt;

  _Item(_J j)
      : key = j["key"]?.toString() ?? "",
        ids = [for (final x in (j["ids"] as List? ?? const [])) x.toString()],
        type = j["type"]?.toString() ?? "",
        title = j["title"]?.toString() ?? "Update",
        message = j["message"]?.toString() ?? "",
        referenceId = j["referenceId"]?.toString() ?? "",
        senders = [for (final x in (j["senders"] as List? ?? const [])) if (x is Map) Map<String, dynamic>.from(x)],
        count = (j["count"] as num?)?.toInt() ?? 1,
        isRead = j["isRead"] == true,
        createdAt = DateTime.tryParse(j["createdAt"]?.toString() ?? "")?.toLocal() ?? DateTime.now();

  AppNotification get asNotification {
    final s = senders.isEmpty ? const <String, dynamic>{} : senders.first;
    return AppNotification(
      id: ids.isEmpty ? "" : ids.first,
      type: type,
      title: title,
      message: message,
      isRead: isRead,
      senderId: s["_id"]?.toString() ?? "",
      senderName: s["name"]?.toString() ?? "",
      senderImage: s["profileImage"]?.toString() ?? "",
      referenceId: referenceId,
      createdAt: createdAt,
    );
  }
}

const _tabs = [("all", "All"), ("mentions", "Mentions"), ("social", "Social"), ("rewards", "Rewards"), ("activity", "Activity")];

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: _tabs.length, vsync: this)..addListener(_onTab);
  final Map<String, List<(String, List<_Item>)>> _data = {};
  final Map<String, bool> _loading = {};
  final Map<String, Object?> _errors = {};
  Map<String, int> _unread = {};

  String get _cat => _tabs[_tab.index].$1;

  @override
  void initState() {
    super.initState();
    _load("all");
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _onTab() {
    if (_tab.indexIsChanging) return;
    HapticFeedback.selectionClick();
    if (!_data.containsKey(_cat)) _load(_cat);
  }

  Future<void> _load(String cat) async {
    setState(() {
      _loading[cat] = true;
      _errors[cat] = null;
    });
    try {
      final r = await ref.read(notificationApiProvider).inbox(cat);
      final groups = <(String, List<_Item>)>[
        for (final g in (r["groups"] as List? ?? const []))
          if (g is Map) (g["label"]?.toString() ?? "", [for (final i in (g["items"] as List? ?? const [])) if (i is Map) _Item(Map<String, dynamic>.from(i))]),
      ];
      final counts = <String, int>{};
      final u = r["unreadByCategory"];
      if (u is Map) {
        u.forEach((k, v) => counts[k.toString()] = (v as num?)?.toInt() ?? 0);
      }
      counts["all"] = (r["unread"] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      setState(() {
        _data[cat] = groups;
        _unread = counts;
      });
    } catch (e) {
      if (mounted) setState(() => _errors[cat] = e);
    } finally {
      if (mounted) setState(() => _loading[cat] = false);
    }
  }

  Future<void> _refreshAll() async {
    final cat = _cat;
    _data.removeWhere((k, _) => k != cat);
    await _load(cat);
    ref.invalidate(notificationsProvider);
  }

  Future<void> _markRead(_Item item) async {
    if (item.isRead) return;
    setState(() => item.isRead = true);
    try {
      await ref.read(notificationApiProvider).bulk(item.ids, "read");
      ref.invalidate(notificationsProvider);
    } catch (_) {}
  }

  Future<void> _delete(_Item item) async {
    for (final groups in _data.values) {
      for (final g in groups) {
        g.$2.removeWhere((x) => x.key == item.key);
      }
      groups.removeWhere((g) => g.$2.isEmpty);
    }
    setState(() {});
    try {
      await ref.read(notificationApiProvider).bulk(item.ids, "delete");
      ref.invalidate(notificationsProvider);
    } catch (_) {
      _refreshAll();
    }
  }

  Future<void> _markAll() async {
    HapticFeedback.mediumImpact();
    await ref.read(notificationApiProvider).markAllRead();
    for (final groups in _data.values) {
      for (final g in groups) {
        for (final i in g.$2) {
          i.isRead = true;
        }
      }
    }
    setState(() => _unread = {});
    ref.invalidate(notificationsProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(tr("Notifications"), style: AppTextStyles.title),
        actions: [
          IconButton(tooltip: tr("Mark all read"), onPressed: _markAll, icon: const Icon(Icons.done_all_rounded)),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800),
          tabs: [
            for (final t in _tabs)
              Tab(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(tr(t.$2)),
                  if ((_unread[t.$1] ?? 0) > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: AppColors.joy, borderRadius: BorderRadius.circular(10)),
                      child: Text("${_unread[t.$1]}", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ]),
              ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [for (final t in _tabs) _list(t.$1)],
      ),
    );
  }

  Widget _list(String cat) {
    final groups = _data[cat];
    if (groups == null) {
      if (_errors[cat] != null) return AppErrorState(message: friendlyError(_errors[cat]!), onRetry: () => _load(cat));
      return const AppLoading();
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refreshAll,
      child: groups.isEmpty
          ? ListView(children: [
              const SizedBox(height: 80),
              AppEmptyState(
                icon: Icons.notifications_none_outlined,
                title: tr("You're all caught up"),
                message: tr("Messages, calls, friend requests, likes and points will show up here."),
              ),
            ])
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
              children: [
                for (final g in groups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 16, 6, 8),
                    child: Text(tr(g.$1), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.ink)),
                  ),
                  for (final item in g.$2)
                    Dismissible(
                      key: ValueKey("${cat}_${item.key}"),
                      background: _swipeBg(Icons.done_all_rounded, tr("Read"), AppColors.eco, Alignment.centerLeft),
                      secondaryBackground: _swipeBg(Icons.delete_outline_rounded, tr("Delete"), AppColors.error, Alignment.centerRight),
                      confirmDismiss: (dir) async {
                        HapticFeedback.lightImpact();
                        if (dir == DismissDirection.startToEnd) {
                          _markRead(item);
                          return false;
                        }
                        return true;
                      },
                      onDismissed: (_) => _delete(item),
                      child: _Row(
                        item: item,
                        onTap: () {
                          _markRead(item);
                          openNotification(context, item.asNotification);
                        },
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  Widget _swipeBg(IconData icon, String label, Color color, Alignment align) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        alignment: align,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(18)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        ]),
      );
}

class _Row extends StatelessWidget {
  final _Item item;
  final VoidCallback onTap;
  const _Row({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final st = _style(item.type);
    final n = item.asNotification;
    final canReply = (item.type == "message" || item.type == "call") && n.senderId.isNotEmpty;
    final faces = item.senders.take(3).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: item.isRead ? AppColors.surface : AppColors.primary.withValues(alpha: AppColors.isDark ? 0.16 : 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: item.isRead ? AppColors.border : AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: faces.length > 1 ? 58 : 46,
              height: 46,
              child: Stack(clipBehavior: Clip.none, children: [
                if (faces.isEmpty)
                  CircleAvatar(radius: 23, backgroundColor: st.color.withValues(alpha: 0.12), child: Icon(st.icon, color: st.color))
                else
                  for (var i = faces.length - 1; i >= 0; i--)
                    PositionedDirectional(
                      start: i * 12.0,
                      top: i * 3.0,
                      child: Container(
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.surface, width: 2)),
                        child: UserAvatar(imageUrl: faces[i]["profileImage"]?.toString() ?? "", radius: faces.length > 1 ? 18 : 21),
                      ),
                    ),
                PositionedDirectional(
                  end: -4,
                  bottom: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: st.color, shape: BoxShape.circle, border: Border.all(color: AppColors.surface, width: 2)),
                    child: Icon(st.icon, size: 11, color: Colors.white),
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(item.title, style: TextStyle(fontWeight: item.isRead ? FontWeight.w700 : FontWeight.w800, color: AppColors.ink)),
                  ),
                  Text(_ago(item.createdAt), style: TextStyle(color: AppColors.subtitle, fontSize: 12)),
                  if (!item.isRead) ...[
                    const SizedBox(width: 6),
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.joy, shape: BoxShape.circle)),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(item.message, style: TextStyle(color: AppColors.subtitle, height: 1.35)),
                if (canReply) ...[
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
