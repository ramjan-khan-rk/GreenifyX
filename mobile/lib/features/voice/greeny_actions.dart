import 'package:flutter/material.dart';

import '../../core/i18n/app_locale.dart';
import '../../core/services/session_user.dart';
import '../../core/utils/chat_launcher.dart';
import '../battles/battles_screen.dart';
import '../campaign/presentation/screens/campaigns_screen.dart';
import '../carbon/carbon_screen.dart';
import '../chat/data/api/message_api.dart';
import '../chat/presentation/screens/chats_screen.dart';
import '../checkin/scan_screen.dart';
import '../communities/community_screens.dart';
import '../companion/companion_screen.dart';
import '../events/events_screen.dart';
import '../growth/growth_screens.dart';
import '../impact/impact_screen.dart';
import '../live/live_screens.dart';
import '../map/eco_map_screen.dart';
import '../market/market_screens.dart';
import '../notifications/presentation/screens/notifications_screen.dart';
import '../pickup/pickup_screen.dart';
import '../post/presentation/screens/create_post_screen.dart';
import '../rewards/rewards_screen.dart';
import '../settings/settings_screen.dart';
import '../social/creator_profile_screen.dart';
import '../social/reels_screen.dart';
import '../social/trending_screens.dart';
import '../wrapped/wrapped_screen.dart';
import 'greeny.dart';

Widget? _screen(String name) => switch (name) {
      "rewards" => const RewardsScreen(),
      "events" => const EventsScreen(),
      "battles" => const BattlesScreen(),
      "map" => const EcoMapScreen(),
      "carbon" => const CarbonScreen(),
      "impact" => const ImpactScreen(),
      "wrapped" => WrappedScreen(year: wrappedYear()),
      "market" => const MarketScreen(),
      "scan" => const ScanScreen(),
      "communities" => const CommunitiesScreen(),
      "reels" => ReelsScreen(meId: SessionUser.id),
      "chats" => const ChatsScreen(),
      "notifications" => const NotificationsScreen(),
      "settings" => const SettingsScreen(),
      "profile" => CreatorProfileScreen(userId: SessionUser.id, meId: SessionUser.id),
      "pickup" => const PickupScreen(),
      "campaigns" => const CampaignsScreen(),
      "companion" => const CompanionScreen(),
      "live" => const LiveListScreen(),
      "trending" => TrendingScreen(meId: SessionUser.id),
      "invite" => const InviteScreen(),
      "create_post" => const CreatePostScreen(),
      _ => null,
    };

/// Carry out what the server decided Greeny should do.
Future<void> runGreenyAction(BuildContext context, Map<String, dynamic> res) async {
  final person = res["person"] is Map ? Map<String, dynamic>.from(res["person"] as Map) : null;
  switch (res["action"]) {
    case "call":
      if (person != null) await startCall(context, userId: person["_id"].toString(), name: person["name"].toString(), video: res["video"] == true);
    case "open_chat":
      if (person != null) await openChat(context, userId: person["_id"].toString(), name: person["name"].toString(), profileImage: person["profileImage"]?.toString() ?? "");
    case "send_message":
      if (person == null) return;
      final text = res["message"]?.toString() ?? "";
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text("${tr("Send to")} ${person["name"]}?"),
          content: Text("“$text”"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr("Cancel"))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr("Send"))),
          ],
        ),
      );
      if (ok != true) return;
      try {
        await MessageApi().sendMessage(receiverId: person["_id"].toString(), text: text);
        Greeny.instance.speak(tr("Sent."));
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${tr("Message sent to")} ${person["name"]}")));
      } catch (_) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr("Couldn't send the message"))));
      }
    case "open_screen":
      final w = _screen(res["screen"]?.toString() ?? "");
      if (w != null) await Navigator.push(context, MaterialPageRoute(builder: (_) => w));
  }
}
