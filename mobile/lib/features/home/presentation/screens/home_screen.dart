import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/session_user.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/chat_launcher.dart';
import '../../../../core/utils/friendly_error.dart';
import '../../../../core/widgets/app_status.dart';
import '../../../../core/widgets/count_badge.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../assistant/snap_sort_screen.dart';
import '../../../campaign/presentation/screens/campaigns_screen.dart';
import '../../../campaign/presentation/screens/points_history_screen.dart';
import '../../../campaign/presentation/widgets/featured_campaign.dart';
import '../../../chat/application/providers/chats_provider.dart';
import '../../../chat/presentation/screens/chats_screen.dart';
import '../../../friends/application/providers/friend_provider.dart';
import '../../../friends/domain/models/friend_model.dart';
import '../../../friends/presentation/screens/friends_screen.dart';
import '../../../issues/presentation/issues_hub_screen.dart';
import '../../../issues/presentation/report_restore_card.dart';
import '../../../map/eco_map_screen.dart';
import '../../../notifications/application/providers/notification_provider.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../orgs/teams_screen.dart';
import '../../../post/presentation/screens/create_post_screen.dart';
import '../../../profile/application/providers/my_profile_provider.dart';
import '../../../settings/settings_screen.dart';
import '../../../rewards/rewards_screen.dart';
import '../../../events/events_screen.dart';
import '../../../pickup/pickup_screen.dart';
import '../../../battles/battles_screen.dart';
import '../../../carbon/carbon_screen.dart';
import '../../../checkin/scan_screen.dart';
import '../../../communities/community_screens.dart';
import '../../../companion/companion_screen.dart';
import '../../../impact/impact_screen.dart';
import '../../../wrapped/wrapped_screen.dart';
import '../../../health/health_sync.dart';
import '../../../bills/bills_screen.dart';
import '../../../forest/forest_screen.dart';
import '../../../household/household_screen.dart';
import '../../../academy/academy_screen.dart';
import '../../../deals/deals_screen.dart';
import '../../../stations/stations_screen.dart';
import '../../../missions/missions_screen.dart';
import '../../../market/market_screens.dart';
import '../../../social/reels_screen.dart';
import '../../../growth/growth_screens.dart';
import '../../../live/live_screens.dart';
import '../../../social/trending_screens.dart';
import '../../../sponsored/sponsored.dart';
import '../../../voice/greeny.dart';
import '../widgets/home_actions.dart';
import '../widgets/impact_hero.dart';
import '../widgets/quote_card.dart';
import 'leaderboard_screen.dart';
import '../../../../core/i18n/app_locale.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _go(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return tr("Good morning");
    if (h < 17) return tr("Good afternoon");
    return tr("Good evening");
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);
    final unread = ref.watch(unreadNotificationCountProvider);
    final unreadChats = ref.watch(chatsProvider).maybeWhen(
          data: (l) => l.where((c) => c.unread).length,
          orElse: () => 0,
        );
    final friends = ref.watch(friendsProvider).maybeWhen(data: (f) => f, orElse: () => const <FriendModel>[]);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: profile.when(
          loading: () => const AppLoading(),
          error: (e, _) => AppErrorState(message: friendlyError(e), onRetry: () => ref.invalidate(myProfileProvider)),
          data: (user) {
            SessionUser.update(id: user.id, name: user.name, profileImage: user.profileImage);
            HealthSync.syncIfOn();
            final first = user.name.trim().split(" ").first;
            final actions = [
              HomeAction(Icons.add_a_photo_rounded, tr("Post"), const [Color(0xFFE36A4A), Color(0xFFF2B544)], () => _go(context, const CreatePostScreen())),
              HomeAction(Icons.slow_motion_video_rounded, tr("Reels"), const [Color(0xFFE8384F), Color(0xFFFF7EB3)], () => _go(context, ReelsScreen(meId: user.id))),
              HomeAction(Icons.campaign_rounded, tr("Campaigns"), const [Color(0xFF1F8A70), Color(0xFF4CC9A0)], () => _go(context, const CampaignsScreen())),
              HomeAction(Icons.sports_kabaddi_rounded, tr("Battles"), const [Color(0xFF7F53AC), Color(0xFFE36A4A)], () => _go(context, const BattlesScreen())),
              HomeAction(Icons.groups_rounded, tr("Communities"), const [Color(0xFF2B2440), Color(0xFF5B4E7A)], () => _go(context, const CommunitiesScreen())),
              HomeAction(Icons.autorenew_rounded, tr("Swap & Share"), const [Color(0xFFFF8008), Color(0xFFFFC837)], () => _go(context, const MarketScreen())),
              HomeAction(Icons.qr_code_scanner_rounded, tr("Scan QR"), const [Color(0xFF00B4DB), Color(0xFF0083B0)], () => _go(context, const ScanScreen())),
              HomeAction(Icons.co2_rounded, tr("Carbon"), const [Color(0xFF11998E), Color(0xFF38EF7D)], () => _go(context, const CarbonScreen())),
              HomeAction(Icons.report_gmailerrorred_rounded, tr("Report"), const [Color(0xFFC2413B), Color(0xFFE36A4A)], () => _go(context, const IssuesHubScreen())),
              HomeAction(Icons.document_scanner_rounded, tr("Snap & Sort"), const [Color(0xFF3A7BD5), Color(0xFF00D2FF)], () => _go(context, const SnapSortScreen())),
              HomeAction(Icons.map_rounded, tr("Eco Map"), const [Color(0xFF56AB2F), Color(0xFFA8E063)], () => _go(context, const EcoMapScreen())),
              HomeAction(Icons.event_rounded, tr("Events"), const [Color(0xFF0083B0), Color(0xFF00B4DB)], () => _go(context, const EventsScreen())),
              HomeAction(Icons.redeem_rounded, tr("Rewards"), const [Color(0xFFE36A4A), Color(0xFFFF5E9C)], () => _go(context, const RewardsScreen())),
              HomeAction(Icons.local_shipping_rounded, tr("Pickup"), const [Color(0xFF1F8A70), Color(0xFF56AB2F)], () => _go(context, const PickupScreen())),
              HomeAction(Icons.workspace_premium_rounded, tr("My impact"), const [Color(0xFFD9B45A), Color(0xFFF2B544)], () => _go(context, const ImpactScreen())),
              HomeAction(Icons.business_center_rounded, tr("Teams"), const [Color(0xFF3A3256), Color(0xFF7F53AC)], () => _go(context, const TeamsScreen())),
              HomeAction(Icons.sensors_rounded, tr("Live"), const [Color(0xFFE8384F), Color(0xFFFF8A65)], () => _go(context, const LiveListScreen())),
              HomeAction(Icons.tag_rounded, tr("Trending"), const [Color(0xFF1D6FD1), Color(0xFF6DD5FA)], () => _go(context, TrendingScreen(meId: user.id))),
              HomeAction(Icons.card_giftcard_rounded, tr("Invite"), const [Color(0xFFF2B544), Color(0xFFE36A4A)], () => _go(context, const InviteScreen())),
              HomeAction(Icons.directions_walk_rounded, tr("Health sync"), const [Color(0xFF11998E), Color(0xFF38EF7D)], () => _go(context, const HealthSyncScreen())),
              HomeAction(Icons.bolt_rounded, tr("My bills"), const [Color(0xFF0083B0), Color(0xFF00B4DB)], () => _go(context, const BillsScreen())),
              HomeAction(Icons.park_rounded, tr("My Forest"), const [Color(0xFF0E3B2E), Color(0xFF56AB2F)], () => _go(context, const ForestScreen())),
              HomeAction(Icons.cottage_rounded, tr("Household"), const [Color(0xFFF2B544), Color(0xFFE36A4A)], () => _go(context, const HouseholdScreen())),
              HomeAction(Icons.school_rounded, tr("Eco Academy"), const [Color(0xFF7F53AC), Color(0xFF647DEE)], () => _go(context, const AcademyScreen())),
              HomeAction(Icons.handshake_rounded, tr("Brand deals"), const [Color(0xFF2B2440), Color(0xFFE36A4A)], () => _go(context, const DealsScreen())),
              HomeAction(Icons.recycling_rounded, tr("Recycle"), const [Color(0xFF1F8A70), Color(0xFF56AB2F)], () => _go(context, const StationsScreen())),
              HomeAction(Icons.flag_circle_rounded, tr("Missions"), const [Color(0xFFC2413B), Color(0xFFF2B544)], () => _go(context, const MissionsScreen())),
              HomeAction(Icons.mic_rounded, "Greeny", const [Color(0xFF38EF7D), Color(0xFF11998E)], () => Greeny.instance.open(context)),
            ];
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                ref.invalidate(myProfileProvider);
                ref.invalidate(friendsProvider);
                ref.invalidate(chatsProvider);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                children: [
                  Row(children: [
                    GestureDetector(
                      onTap: () => _go(context, const SettingsScreen()),
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [AppColors.joy, AppColors.sun]),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.background),
                          child: UserAvatar(imageUrl: user.profileImage, name: user.name, radius: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_greeting(), style: TextStyle(color: AppColors.subtitle, fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(
                          first.isEmpty ? tr("Welcome 👋") : "$first 👋",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.3),
                        ),
                      ]),
                    ),
                    _TopIcon(
                      icon: Icons.chat_bubble_outline_rounded,
                      count: unreadChats,
                      onTap: () => _go(context, const ChatsScreen()),
                    ),
                    const SizedBox(width: 8),
                    _TopIcon(
                      icon: Icons.notifications_none_rounded,
                      count: unread,
                      onTap: () => _go(context, const NotificationsScreen()),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  ImpactHero(
                    points: user.ecoPoints,
                    level: user.level,
                    streak: user.streak,
                    onHistory: () => _go(context, const PointsHistoryScreen()),
                    onRewards: () => _go(context, const RewardsScreen()),
                  ),
                  const WrappedBanner(),
                  const StreakCard(),
                  const CompanionCard(),
                  const SponsoredStrip(),
                  const SizedBox(height: 16),
                  HomeActionGrid(actions: actions),
                  if (friends.isNotEmpty) ...[
                    SectionHeader(tr("Friends"), action: tr("See all"), onAction: () => _go(context, const FriendsScreen())),
                    SizedBox(
                      height: 92,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: friends.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 14),
                        itemBuilder: (_, i) {
                          final f = friends[i];
                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => openChat(context, userId: f.id, name: f.name, profileImage: f.profileImage),
                            child: SizedBox(
                              width: 66,
                              child: Column(children: [
                                UserAvatar(imageUrl: f.profileImage, name: f.name, radius: 30),
                                const SizedBox(height: 6),
                                Text(
                                  f.name.split(" ").first,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink),
                                ),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const FeaturedCampaign(),
                  const ReportRestoreCard(),
                  SectionHeader(tr("Climb the leaderboard"), action: tr("Open"), onAction: () => _go(context, const LeaderboardScreen())),
                  _LeaderboardTeaser(onTap: () => _go(context, const LeaderboardScreen())),
                  const SizedBox(height: 18),
                  const QuoteCard(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TopIcon extends StatelessWidget {
  final IconData icon;
  final int count;
  final VoidCallback onTap;
  const _TopIcon({required this.icon, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: CountBadge(count: count, child: Icon(icon, color: AppColors.ink, size: 23)),
        ),
      ),
    );
  }
}

class _LeaderboardTeaser extends StatelessWidget {
  final VoidCallback onTap;
  const _LeaderboardTeaser({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 14, offset: Offset(0, 4))],
        ),
        child: Row(children: [
          CircleAvatar(radius: 24, backgroundColor: AppColors.blush, child: Icon(Icons.leaderboard_rounded, color: AppColors.joy)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr("UAE weekly ranking"), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: AppColors.ink)),
              const SizedBox(height: 2),
              Text(tr("See where you stand among friends and every emirate."), style: TextStyle(color: AppColors.subtitle, fontSize: 13)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.subtitle),
        ]),
      ),
    );
  }
}
