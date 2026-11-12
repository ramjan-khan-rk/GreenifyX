import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../core/i18n/app_locale.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/utils/media_url.dart';
import '../../core/widgets/user_avatar.dart';
import '../comment/presentation/widgets/comment_bottom_sheet.dart';
import '../post/domain/looks.dart';
import 'creator_profile_screen.dart';
import 'social_api.dart';

/// Full-screen vertical video feed.
class ReelsScreen extends StatefulWidget {
  final String meId;
  final String? sound;
  final String? soundTitle;
  const ReelsScreen({super.key, required this.meId, this.sound, this.soundTitle});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  final List<Json> _reels = [];
  int _page = 1;
  bool _more = true;
  bool _loading = false;
  int _index = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (_loading || !_more) return;
    setState(() => _loading = true);
    try {
      final r = await SocialApi.reels(page: _page, sound: widget.sound);
      setState(() {
        _reels.addAll(maps(r["reels"]));
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
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(widget.soundTitle != null ? "♪ ${widget.soundTitle}" : tr("Reels"), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
      body: _reels.isEmpty
          ? Center(
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(_error ?? tr("No reels yet. Post a short video to start the trend!"), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                    ),
            )
          : PageView.builder(
              scrollDirection: Axis.vertical,
              itemCount: _reels.length,
              onPageChanged: (i) {
                setState(() => _index = i);
                if (i >= _reels.length - 3) _fetch();
              },
              itemBuilder: (_, i) => _ReelPage(key: ValueKey(_reels[i]["_id"]), reel: _reels[i], active: i == _index, meId: widget.meId),
            ),
    );
  }
}

class _ReelPage extends StatefulWidget {
  final Json reel;
  final bool active;
  final String meId;
  const _ReelPage({super.key, required this.reel, required this.active, required this.meId});

  @override
  State<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<_ReelPage> {
  VideoPlayerController? _c;
  VideoPlayerController? _music;
  late bool _liked = widget.reel["isLiked"] == true;
  late int _likes = (widget.reel["likesCount"] as num?)?.toInt() ?? 0;
  late bool _following = widget.reel["isFollowing"] == true;
  bool _heart = false;
  bool _viewed = false;

  Json get _user => Json.from((widget.reel["user"] ?? {}) as Map);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = VideoPlayerController.networkUrl(Uri.parse(resolveMediaUrl(widget.reel["image"]?.toString()) ?? ""));
    _c = c;
    try {
      await c.initialize();
      await c.setLooping(true);
      final mute = widget.reel["muteOriginal"] == true;
      await c.setVolume(mute ? 0 : 1);
      final music = (widget.reel["musicUrl"] ?? "").toString();
      if (music.isNotEmpty) {
        final m = VideoPlayerController.networkUrl(Uri.parse(music));
        _music = m;
        await m.initialize();
        await m.setLooping(true);
        await m.seekTo(Duration(seconds: (widget.reel["musicStartSec"] as num?)?.toInt() ?? 0));
        if (!mute) await c.setVolume(0.3);
      }
      if (mounted) {
        setState(() {});
        _sync();
      }
    } catch (_) {}
  }

  void _sync() {
    if (widget.active) {
      _c?.play();
      _music?.play();
      if (!_viewed) {
        _viewed = true;
        SocialApi.view(widget.reel["_id"].toString());
      }
    } else {
      _c?.pause();
      _music?.pause();
    }
  }

  @override
  void didUpdateWidget(covariant _ReelPage old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _sync();
  }

  @override
  void dispose() {
    _c?.dispose();
    _music?.dispose();
    super.dispose();
  }

  Future<void> _like({bool doubleTap = false}) async {
    if (doubleTap) {
      setState(() => _heart = true);
      Future.delayed(const Duration(milliseconds: 650), () {
        if (mounted) setState(() => _heart = false);
      });
      if (_liked) return;
    }
    setState(() {
      _liked = !_liked;
      _likes += _liked ? 1 : -1;
    });
    try {
      await ApiService.dio.put("/posts/${widget.reel["_id"]}/like");
    } catch (_) {}
  }

  Future<void> _follow() async {
    try {
      final f = await SocialApi.follow(_user["_id"].toString());
      if (mounted) setState(() => _following = f);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reel;
    final c = _c;
    final look = lookById(r["look"]?.toString() ?? "natural");
    final isMe = _user["_id"] == widget.meId;
    return GestureDetector(
      onTap: () {
        if (c == null) return;
        c.value.isPlaying ? c.pause() : c.play();
        c.value.isPlaying ? _music?.pause() : _music?.play();
        setState(() {});
      },
      onDoubleTap: () => _like(doubleTap: true),
      child: Stack(fit: StackFit.expand, children: [
        if (c != null && c.value.isInitialized)
          ColorFiltered(
            colorFilter: ColorFilter.matrix(look.matrix),
            child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c))),
          )
        else
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        const DecoratedBox(
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.transparent, Colors.black87], stops: [0, 0.55, 1])),
        ),
        if (c != null && c.value.isInitialized && !c.value.isPlaying) const Center(child: Icon(Icons.play_arrow_rounded, size: 90, color: Colors.white70)),
        if (_heart) const Center(child: Icon(Icons.favorite_rounded, color: Colors.white, size: 120, shadows: [Shadow(blurRadius: 20)])),
        Positioned(
          right: 10,
          bottom: 110,
          child: Column(children: [
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreatorProfileScreen(userId: _user["_id"].toString(), meId: widget.meId))),
              child: Stack(clipBehavior: Clip.none, alignment: Alignment.bottomCenter, children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                  child: UserAvatar(imageUrl: _user["profileImage"]?.toString(), name: _user["name"]?.toString(), radius: 22),
                ),
                if (!isMe && !_following)
                  Positioned(
                    bottom: -10,
                    child: GestureDetector(
                      onTap: _follow,
                      child: const CircleAvatar(radius: 11, backgroundColor: Color(0xFFE8384F), child: Icon(Icons.add_rounded, size: 16, color: Colors.white)),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 22),
            _Side(icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: _liked ? const Color(0xFFE8384F) : Colors.white, label: compact(_likes), onTap: _like),
            _Side(
              icon: Icons.mode_comment_rounded,
              label: compact(r["commentsCount"] as num?),
              onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => CommentBottomSheet(postId: r["_id"].toString())),
            ),
            _Side(
              icon: Icons.reply_rounded,
              flip: true,
              label: tr("Share"),
              onTap: () => SharePlus.instance.share(ShareParams(
                text: "${_user["name"]} on GreenifyX: ${r["activity"]} 🌱\n${r["description"] ?? ""}\n${resolveMediaUrl(r["image"]?.toString()) ?? ""}",
              )),
            ),
            if ((r["musicUrl"] ?? "").toString().isNotEmpty)
              _Side(
                icon: Icons.music_note_rounded,
                label: tr("Sound"),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ReelsScreen(meId: widget.meId, sound: r["musicUrl"].toString(), soundTitle: (r["musicTitle"] ?? "Original sound").toString())),
                ),
              ),
          ]),
        ),
        Positioned(
          left: 14,
          right: 80,
          bottom: 28,
          child: SafeArea(
            top: false,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("@${(_user["name"] ?? "").toString().replaceAll(" ", "").toLowerCase()}",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(14)),
                child: Text("🌱 ${r["activity"]} · +${r["ecoPoints"]}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
              ),
              if ((r["description"] ?? "").toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(r["description"].toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, height: 1.35)),
                ),
              if ((r["musicTitle"] ?? "").toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(children: [
                    const Icon(Icons.music_note_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Flexible(child: Text(r["musicTitle"].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white))),
                  ]),
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Side extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool flip;
  const _Side({required this.icon, required this.label, required this.onTap, this.color = Colors.white, this.flip = false});

  @override
  Widget build(BuildContext context) {
    final i = Icon(icon, color: color, size: 34, shadows: const [Shadow(blurRadius: 10, color: Colors.black54)]);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: GestureDetector(
        onTap: onTap,
        child: Column(children: [
          flip ? Transform.flip(flipX: true, child: i) : i,
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5, shadows: [Shadow(blurRadius: 6)])),
        ]),
      ),
    );
  }
}
