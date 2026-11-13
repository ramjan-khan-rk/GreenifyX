import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/i18n/app_locale.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/utils/media_url.dart';
import '../../core/widgets/user_avatar.dart';
import '../post/presentation/screens/create_post_screen.dart';

typedef Json = Map<String, dynamic>;

String _short(int n) => n >= 1000 ? "${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k" : "$n";

/// "Do it too" on a post: copy the action into a new post and join its chain.
class DoItTooButton extends StatelessWidget {
  final String postId;
  final String activity;
  final int count;
  final bool mine;
  const DoItTooButton({super.key, required this.postId, required this.activity, required this.count, required this.mine});

  @override
  Widget build(BuildContext context) {
    final label = count > 0 ? "${_short(count)} ${tr("did it")}" : tr("Do it too");
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 4),
      child: ActionChip(
        avatar: const Text("🔁"),
        visualDensity: VisualDensity.compact,
        shape: const StadiumBorder(),
        side: BorderSide(color: AppColors.eco.withValues(alpha: 0.4)),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.eco)),
        onPressed: () {
          if (count > 0 || mine) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ChainScreen(postId: postId, activity: activity)));
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => CreatePostScreen(chainParent: postId, presetActivity: activity)));
          }
        },
      ),
    );
  }
}

/// Everyone who did the same action after this post.
class ChainScreen extends StatefulWidget {
  final String postId;
  final String activity;
  const ChainScreen({super.key, required this.postId, required this.activity});

  @override
  State<ChainScreen> createState() => _ChainScreenState();
}

class _ChainScreenState extends State<ChainScreen> {
  Json? _d;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ApiService.dio.get("/posts/${widget.postId}/chain");
      if (mounted) setState(() => _d = Json.from(r.data as Map));
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final root = d?["root"] is Map ? Json.from(d!["root"] as Map) : null;
    final posts = (d?["posts"] as List? ?? []).map((e) => Json.from(e as Map)).toList();
    final starter = root?["user"] is Map ? Json.from(root!["user"] as Map) : null;
    return Scaffold(
      appBar: AppBar(title: Text(tr("Do it too"))),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.eco,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CreatePostScreen(chainParent: widget.postId, presetActivity: widget.activity))),
        icon: const Text("🔁", style: TextStyle(fontSize: 18)),
        label: Text(tr("Join the chain")),
      ),
      body: d == null
          ? Center(child: _error == null ? const CircularProgressIndicator() : Text(_error!))
          : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), gradient: const LinearGradient(colors: [Color(0xFF1F8A70), Color(0xFF4CC9A0)])),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("${d["count"]}", style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900, height: 1)),
                  const SizedBox(height: 4),
                  Text(
                    starter == null
                        ? "${tr("people did")} ${tr(widget.activity)}"
                        : "${tr("people did")} ${tr(widget.activity)} ${tr("after")} ${starter["name"]}",
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(tr("Every link in this chain is a real action, not just a share."), style: const TextStyle(color: Colors.white70)),
                ]),
              ),
              const SizedBox(height: 16),
              if (posts.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: Text(tr("Nobody has joined yet. Be the first!"), textAlign: TextAlign.center, style: TextStyle(color: AppColors.subtitle)),
                )
              else
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  children: [
                    for (final p in posts)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(fit: StackFit.expand, children: [
                          p["mediaType"] == "video"
                              ? Container(color: AppColors.surfaceAlt, child: const Icon(Icons.play_circle_fill_rounded, size: 34))
                              : CachedNetworkImage(imageUrl: resolveMediaUrl(p["image"]?.toString()) ?? "", fit: BoxFit.cover),
                          PositionedDirectional(
                            start: 6,
                            bottom: 6,
                            child: UserAvatar(
                              imageUrl: (p["user"] as Map?)?["profileImage"]?.toString(),
                              name: (p["user"] as Map?)?["name"]?.toString() ?? "",
                              radius: 13,
                            ),
                          ),
                        ]),
                      ),
                  ],
                ),
            ]),
    );
  }
}
