import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/i18n/app_locale.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/chat_launcher.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/utils/media_url.dart';
import '../../core/widgets/user_avatar.dart';
import '../feed/domain/models/feed_model.dart';
import '../feed/presentation/widgets/post_card.dart';
import 'social_api.dart';

String compact(num? v) {
  final n = (v ?? 0).toDouble();
  if (n >= 1e6) return "${(n / 1e6).toStringAsFixed(1)}M";
  if (n >= 1e3) return "${(n / 1e3).toStringAsFixed(1)}K";
  return n.toStringAsFixed(0);
}

/// Public creator profile: stats, follow, message, posts grid.
class CreatorProfileScreen extends StatefulWidget {
  final String userId;
  final String meId;
  const CreatorProfileScreen({super.key, required this.userId, required this.meId});

  @override
  State<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends State<CreatorProfileScreen> {
  Json? _p;
  List<Json> _posts = [];
  List<Json> _communities = [];
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await SocialApi.creator(widget.userId);
      if (!mounted) return;
      setState(() {
        _p = Json.from(r["profile"] as Map);
        _posts = maps(r["posts"]);
        _communities = maps(r["communities"]);
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _follow() async {
    setState(() => _busy = true);
    try {
      final f = await SocialApi.follow(widget.userId);
      setState(() {
        _p!["isFollowing"] = f;
        _p!["followers"] = ((_p!["followers"] as num?) ?? 0) + (f ? 1 : -1);
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, title: Text(p?["name"]?.toString() ?? "")),
      body: _error != null
          ? Center(child: TextButton(onPressed: _load, child: Text("$_error\n${tr("Try again")}", textAlign: TextAlign.center)))
          : p == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AppColors.sun, AppColors.joy, Color(0xFF7F53AC)])),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                            child: UserAvatar(imageUrl: p["profileImage"]?.toString(), name: p["name"]?.toString(), radius: 40),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                            _Stat(compact(p["posts"] as num?), tr("Posts")),
                            _Stat(compact(p["followers"] as num?), tr("Followers")),
                            _Stat(compact(p["following"] as num?), tr("Following")),
                          ]),
                        ),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Flexible(child: Text(p["name"]?.toString() ?? "", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.eco.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                            child: Text("${tr("Level")} ${p["level"]}", style: const TextStyle(color: AppColors.eco, fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                        ]),
                        if ((p["bio"] ?? "").toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(p["bio"].toString(), style: const TextStyle(height: 1.4))),
                        const SizedBox(height: 6),
                        Text("⭐ ${compact(p["ecoPoints"] as num?)} ${tr("Eco Points")} · ❤ ${compact(p["likes"] as num?)} · 🔥 ${p["streak"] ?? 0}",
                            style: const TextStyle(color: AppColors.subtitle, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    if (p["isMe"] != true)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        child: Row(children: [
                          Expanded(
                            child: p["isFollowing"] == true
                                ? OutlinedButton(onPressed: _busy ? null : _follow, child: Text(tr("Following")))
                                : FilledButton(onPressed: _busy ? null : _follow, child: Text(tr("Follow"))),
                          ),
                          if (p["isFriend"] == true) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => openChat(context, userId: widget.userId, name: p["name"].toString(), profileImage: p["profileImage"]?.toString() ?? ""),
                                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                                label: Text(tr("Message")),
                              ),
                            ),
                          ],
                        ]),
                      ),
                    if (_communities.isNotEmpty)
                      SizedBox(
                        height: 46,
                        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), children: [
                          for (final c in _communities)
                            Padding(padding: const EdgeInsets.only(right: 8), child: Chip(avatar: const Icon(Icons.groups_rounded, size: 16), label: Text(c["name"].toString()))),
                        ]),
                      ),
                    const SizedBox(height: 14),
                    const Divider(),
                    if (_posts.isEmpty)
                      Padding(padding: const EdgeInsets.all(40), child: Center(child: Text(tr("No posts yet"), style: const TextStyle(color: AppColors.subtitle)))),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _posts.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
                      itemBuilder: (_, i) {
                        final post = _posts[i];
                        final video = post["mediaType"] == "video";
                        final img = resolveMediaUrl(post["image"]?.toString()) ?? "";
                        final thumb = video ? img.replaceAll(RegExp(r"\.(mp4|mov|webm)$", caseSensitive: false), ".jpg") : img;
                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                appBar: AppBar(title: Text(p["name"].toString())),
                                body: ListView(children: [PostCard(post: FeedModel.fromJson(post), meId: widget.meId)]),
                              ),
                            ),
                          ),
                          child: Stack(fit: StackFit.expand, children: [
                            CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover, errorWidget: (_, _, _) => Container(color: AppColors.blush)),
                            if (video) const Positioned(right: 6, top: 6, child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 20)),
                            Positioned(
                              left: 6,
                              bottom: 4,
                              child: Text("❤ ${post["likesCount"] ?? 0}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12, shadows: [Shadow(blurRadius: 4)])),
                            ),
                          ]),
                        );
                      },
                    ),
                  ]),
                ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat(this.value, this.label);

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.ink)),
        Text(label, style: const TextStyle(color: AppColors.subtitle, fontSize: 12.5)),
      ]);
}
