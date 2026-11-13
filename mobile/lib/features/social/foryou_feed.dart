import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/i18n/app_locale.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/widgets/user_avatar.dart';
import '../feed/domain/models/feed_model.dart';
import '../feed/presentation/widgets/post_card.dart';
import '../communities/community_screens.dart';
import 'creator_profile_screen.dart';
import 'social_api.dart';

/// Personalised feed with creator, community and campaign suggestions mixed in.
class ForYouFeed extends StatefulWidget {
  final String meId;
  final Widget header;
  const ForYouFeed({super.key, required this.meId, required this.header});

  @override
  State<ForYouFeed> createState() => _ForYouFeedState();
}

class _ForYouFeedState extends State<ForYouFeed> with AutomaticKeepAliveClientMixin {
  final List<Json> _posts = [];
  List<Json> _creators = [];
  List<Json> _communities = [];
  List<String> _interests = [];
  int _page = 1;
  bool _more = true;
  bool _loading = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetch(reset: true);
  }

  Future<void> _fetch({bool reset = false}) async {
    if (_loading) return;
    if (reset) {
      _page = 1;
      _more = true;
    }
    if (!_more) return;
    setState(() => _loading = true);
    try {
      final r = await SocialApi.forYou(page: _page);
      setState(() {
        if (reset) _posts.clear();
        _posts.addAll(maps(r["posts"]));
        if (_page == 1) {
          _creators = maps(r["creators"]);
          _communities = maps(r["communities"]);
          _interests = (r["interests"] as List? ?? []).map((e) => e.toString()).toList();
        }
        _more = r["hasMore"] == true;
        _page++;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final items = <Widget>[widget.header];
    if (_interests.isNotEmpty) {
      items.add(Container(
        color: AppColors.surface,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(children: [
          const Icon(Icons.auto_awesome_rounded, color: AppColors.joy, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text("${tr("Picked for you")}: ${_interests.join(" · ")}",
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.subtitle, fontWeight: FontWeight.w600, fontSize: 12.5)),
          ),
        ]),
      ));
    }
    for (var i = 0; i < _posts.length; i++) {
      items.add(PostCard(key: ValueKey(_posts[i]["_id"]), post: FeedModel.fromJson(_posts[i]), meId: widget.meId));
      if (i == 2 && _creators.isNotEmpty) items.add(_CreatorsRow(creators: _creators, meId: widget.meId));
      if (i == 6 && _communities.isNotEmpty) items.add(_CommunitiesRow(communities: _communities));
    }
    if (_posts.isEmpty && !_loading) {
      items.add(Padding(
        padding: const EdgeInsets.all(40),
        child: Column(children: [
          Icon(Icons.auto_awesome_rounded, size: 48, color: AppColors.subtitle),
          const SizedBox(height: 10),
          Text(_error ?? tr("Your feed learns what you love. Like and post a few moments to tune it."), textAlign: TextAlign.center),
        ]),
      ));
      if (_creators.isNotEmpty) items.add(_CreatorsRow(creators: _creators, meId: widget.meId));
      if (_communities.isNotEmpty) items.add(_CommunitiesRow(communities: _communities));
    }
    if (_loading) items.add(const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())));
    return RefreshIndicator(
      onRefresh: () => _fetch(reset: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 800) _fetch();
          return false;
        },
        child: ListView(padding: const EdgeInsets.only(bottom: 24), children: items),
      ),
    );
  }
}

class _CreatorsRow extends StatelessWidget {
  final List<Json> creators;
  final String meId;
  const _CreatorsRow({required this.creators, required this.meId});

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.surface,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(tr("Creators to follow"), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          const SizedBox(height: 10),
          SizedBox(
            height: 170,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
              for (final c in creators)
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreatorProfileScreen(userId: c["_id"].toString(), meId: meId))),
                  child: Container(
                    width: 130,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
                    child: Column(children: [
                      UserAvatar(imageUrl: c["profileImage"]?.toString(), name: c["name"]?.toString(), radius: 30),
                      const SizedBox(height: 8),
                      Text(c["name"]?.toString() ?? "", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text("❤ ${compact(c["likes"] as num?)}", style: TextStyle(color: AppColors.subtitle, fontSize: 12)),
                      const Spacer(),
                      Text(tr("View profile"), style: const TextStyle(color: AppColors.joy, fontWeight: FontWeight.w800, fontSize: 12.5)),
                    ]),
                  ),
                ),
            ]),
          ),
        ]),
      );
}

class _CommunitiesRow extends StatelessWidget {
  final List<Json> communities;
  const _CommunitiesRow({required this.communities});

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.surface,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(tr("Communities you may like"), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          const SizedBox(height: 10),
          SizedBox(
            height: 150,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
              for (final c in communities)
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CommunityDetailScreen(id: c["_id"].toString()))),
                  child: Container(
                    width: 210,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: AppColors.inkFixedFixed),
                    child: Stack(fit: StackFit.expand, children: [
                      if ((c["coverImage"] ?? "").toString().isNotEmpty)
                        CachedNetworkImage(imageUrl: c["coverImage"].toString(), fit: BoxFit.cover, color: Colors.black38, colorBlendMode: BlendMode.darken),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                          Text(c["category"]?.toString() ?? "", style: const TextStyle(color: AppColors.sun, fontWeight: FontWeight.w800, fontSize: 11.5)),
                          Text(c["name"]?.toString() ?? "", maxLines: 2, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                          Text("${c["members"]} ${tr("members")}", style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                        ]),
                      ),
                    ]),
                  ),
                ),
            ]),
          ),
        ]),
      );
}
