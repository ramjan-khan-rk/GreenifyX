import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/i18n/app_locale.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/utils/media_url.dart';
import '../feed/domain/models/feed_model.dart';
import '../feed/presentation/widgets/post_card.dart';
import 'reels_screen.dart';
import 'social_api.dart';

/// Trending hashtags, sounds and the week's top posts.
class TrendingScreen extends StatefulWidget {
  final String meId;
  const TrendingScreen({super.key, required this.meId});

  @override
  State<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends State<TrendingScreen> {
  Json? _d;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ApiService.dio.get("/discover/trending");
      if (mounted) setState(() => _d = Json.from(r.data as Map));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Scaffold(
      appBar: AppBar(title: Text(tr("Trending"))),
      body: d == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
                Text(tr("Hashtags this week"), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(height: 10),
                if (maps(d["hashtags"]).isEmpty) Text(tr("No hashtags yet — add #tags to your posts!"), style: const TextStyle(color: AppColors.subtitle)),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final (i, h) in maps(d["hashtags"]).indexed)
                    ActionChip(
                      avatar: i < 3 ? const Text("🔥") : null,
                      label: Text("#${h["tag"]} · ${h["posts"]}"),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HashtagScreen(tag: h["tag"].toString(), meId: widget.meId))),
                    ),
                ]),
                if (maps(d["sounds"]).isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text(tr("Trending sounds"), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  const SizedBox(height: 6),
                  for (final s in maps(d["sounds"]))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(backgroundColor: AppColors.ink, child: Icon(Icons.music_note_rounded, color: Colors.white)),
                      title: Text(s["title"].toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text("${s["uses"]} ${tr("posts")}"),
                      trailing: const Icon(Icons.play_circle_fill_rounded, color: AppColors.joy, size: 30),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReelsScreen(meId: widget.meId, sound: s["url"].toString(), soundTitle: s["title"].toString()))),
                    ),
                ],
                const SizedBox(height: 22),
                Text(tr("Top this week"), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(height: 10),
                _Grid(posts: maps(d["topPosts"]), meId: widget.meId),
              ]),
            ),
    );
  }
}

class HashtagScreen extends StatefulWidget {
  final String tag;
  final String meId;
  const HashtagScreen({super.key, required this.tag, required this.meId});

  @override
  State<HashtagScreen> createState() => _HashtagScreenState();
}

class _HashtagScreenState extends State<HashtagScreen> {
  List<Json>? _posts;

  @override
  void initState() {
    super.initState();
    ApiService.dio.get("/discover/hashtag/${Uri.encodeComponent(widget.tag)}").then((r) {
      if (mounted) setState(() => _posts = maps(r.data["posts"]));
    }).catchError((e) {
      if (mounted) setState(() => _posts = []);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = _posts;
    return Scaffold(
      appBar: AppBar(title: Text("#${widget.tag}")),
      body: p == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Row(children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: const Color(0xFF1D6FD1).withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: const Text("#", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF1D6FD1))),
                ),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("#${widget.tag}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  Text("${p.length} ${tr("posts")}", style: const TextStyle(color: AppColors.subtitle)),
                ]),
              ]),
              const SizedBox(height: 16),
              _Grid(posts: p, meId: widget.meId),
            ]),
    );
  }
}

class _Grid extends StatelessWidget {
  final List<Json> posts;
  final String meId;
  const _Grid({required this.posts, required this.meId});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: posts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 3, crossAxisSpacing: 3),
      itemBuilder: (_, i) {
        final post = posts[i];
        final video = post["mediaType"] == "video";
        final img = resolveMediaUrl(post["image"]?.toString()) ?? "";
        final thumb = video ? img.replaceAll(RegExp(r"\.(mp4|mov|webm)$", caseSensitive: false), ".jpg") : img;
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(), body: ListView(children: [PostCard(post: FeedModel.fromJson(post), meId: meId)]))),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(fit: StackFit.expand, children: [
              CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover, errorWidget: (_, _, _) => Container(color: AppColors.blush)),
              if (video) const Positioned(right: 5, top: 5, child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 18)),
            ]),
          ),
        );
      },
    );
  }
}
