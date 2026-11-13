import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../core/i18n/app_locale.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/utils/media_url.dart';
import '../../core/widgets/user_avatar.dart';
import '../post/domain/looks.dart';
import 'social_api.dart';

/// Horizontal story rings at the top of the feed.
class StoriesBar extends StatefulWidget {
  final String meId;
  final String myName;
  final String myImage;
  const StoriesBar({super.key, required this.meId, this.myName = "", this.myImage = ""});

  @override
  State<StoriesBar> createState() => StoriesBarState();
}

class StoriesBarState extends State<StoriesBar> {
  List<Json> _groups = [];

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    try {
      final g = await SocialApi.stories();
      if (mounted) setState(() => _groups = g);
    } catch (_) {}
  }

  Future<void> _create() async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const CreateStoryScreen()));
    if (ok == true) refresh();
  }

  @override
  Widget build(BuildContext context) {
    final mine = _groups.where((g) => (g["user"] as Map)["_id"] == widget.meId).toList();
    final others = _groups.where((g) => (g["user"] as Map)["_id"] != widget.meId).toList();
    return Container(
      color: AppColors.surface,
      height: 112,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        children: [
          _Ring(
            name: tr("Your story"),
            image: widget.myImage,
            avatarName: widget.myName,
            seen: mine.isEmpty || (mine.first["unseen"] ?? 0) == 0,
            hasStory: mine.isNotEmpty,
            add: true,
            onTap: mine.isEmpty ? _create : () => _open(mine.first, mine + others),
            onAdd: _create,
          ),
          for (final g in others)
            _Ring(
              name: ((g["user"] as Map)["name"] ?? "").toString().split(" ").first,
              image: ((g["user"] as Map)["profileImage"] ?? "").toString(),
              avatarName: ((g["user"] as Map)["name"] ?? "").toString(),
              seen: (g["unseen"] ?? 0) == 0,
              hasStory: true,
              onTap: () => _open(g, others),
            ),
        ],
      ),
    );
  }

  Future<void> _open(Json group, List<Json> all) async {
    final start = all.indexOf(group);
    await Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, _, _) => StoryViewer(groups: all, startGroup: start < 0 ? 0 : start, meId: widget.meId),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      ),
    );
    refresh();
  }
}

class _Ring extends StatelessWidget {
  final String name;
  final String image;
  final String avatarName;
  final bool seen;
  final bool hasStory;
  final bool add;
  final VoidCallback onTap;
  final VoidCallback? onAdd;
  const _Ring({required this.name, required this.image, required this.avatarName, required this.seen, required this.hasStory, required this.onTap, this.add = false, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: SizedBox(
          width: 70,
          child: Column(children: [
            Stack(clipBehavior: Clip.none, children: [
              Container(
                padding: const EdgeInsets.all(2.6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: hasStory && !seen ? const LinearGradient(colors: [Color(0xFFF2B544), Color(0xFFE36A4A), Color(0xFF7F53AC)], begin: Alignment.bottomLeft, end: Alignment.topRight) : null,
                  color: hasStory && seen ? AppColors.border : (hasStory ? null : Colors.transparent),
                ),
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surface),
                  child: UserAvatar(imageUrl: image, name: avatarName, radius: 28),
                ),
              ),
              if (add)
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: GestureDetector(
                    onTap: onAdd,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(color: AppColors.joy, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5)),
                      child: const Icon(Icons.add_rounded, color: Colors.white, size: 15),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 5),
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
          ]),
        ),
      ),
    );
  }
}

/// Full-screen story player: tap right/left to move, hold to pause, swipe down to close.
class StoryViewer extends StatefulWidget {
  final List<Json> groups;
  final int startGroup;
  final String meId;
  const StoryViewer({super.key, required this.groups, required this.startGroup, required this.meId});

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> with SingleTickerProviderStateMixin {
  late int _g = widget.startGroup;
  int _s = 0;
  late final AnimationController _progress = AnimationController(vsync: this, duration: const Duration(seconds: 6))
    ..addStatusListener((st) {
      if (st == AnimationStatus.completed) _next();
    });
  VideoPlayerController? _video;
  bool _liked = false;

  List<Json> get _stories => List<Json>.from(widget.groups[_g]["stories"] as List);
  Json get _story => Json.from(_stories[_s] as Map);
  Json get _user => Json.from(widget.groups[_g]["user"] as Map);
  bool get _mine => _user["_id"] == widget.meId;

  @override
  void initState() {
    super.initState();
    // Start at the first unseen story of the group.
    final i = _stories.indexWhere((s) => s["seen"] != true);
    _s = i < 0 ? 0 : i;
    _load();
  }

  @override
  void dispose() {
    _progress.dispose();
    _video?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _progress.stop();
    _progress.value = 0;
    await _video?.dispose();
    _video = null;
    final s = _story;
    _liked = s["liked"] == true;
    SocialApi.viewStory(s["_id"].toString());
    if (s["mediaType"] == "video") {
      final c = VideoPlayerController.networkUrl(Uri.parse(resolveMediaUrl(s["mediaUrl"]?.toString()) ?? ""));
      _video = c;
      try {
        await c.initialize();
        if (!mounted || _video != c) return;
        final d = c.value.duration;
        _progress.duration = d.inMilliseconds > 0 ? (d > const Duration(seconds: 30) ? const Duration(seconds: 30) : d) : const Duration(seconds: 10);
        await c.play();
      } catch (_) {
        _progress.duration = const Duration(seconds: 5);
      }
    } else {
      _progress.duration = const Duration(seconds: 6);
    }
    if (mounted) {
      setState(() {});
      _progress.forward(from: 0);
    }
  }

  void _next() {
    if (_s < _stories.length - 1) {
      setState(() => _s++);
      _load();
    } else if (_g < widget.groups.length - 1) {
      setState(() {
        _g++;
        _s = 0;
      });
      _load();
    } else {
      Navigator.pop(context);
    }
  }

  void _prev() {
    if (_s > 0) {
      setState(() => _s--);
      _load();
    } else if (_g > 0) {
      setState(() {
        _g--;
        _s = 0;
      });
      _load();
    } else {
      _load();
    }
  }

  void _pause(bool p) {
    if (p) {
      _progress.stop();
      _video?.pause();
    } else {
      _progress.forward();
      _video?.play();
    }
  }

  Future<void> _showViewers() async {
    _pause(true);
    try {
      final r = await SocialApi.storyViewers(_story["_id"].toString());
      if (!mounted) return;
      final viewers = maps(r["viewers"]);
      await showModalBottomSheet<void>(
        context: context,
        builder: (sheetCtx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.visibility_rounded),
              title: Text("${viewers.length} ${tr("views")}", style: const TextStyle(fontWeight: FontWeight.w800)),
              trailing: Text("❤ ${r["likes"] ?? 0}"),
            ),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final v in viewers)
                  ListTile(leading: UserAvatar(imageUrl: v["profileImage"]?.toString(), name: v["name"]?.toString()), title: Text(v["name"]?.toString() ?? "")),
              ]),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: Text(tr("Delete story"), style: const TextStyle(color: AppColors.error)),
              onTap: () async {
                await SocialApi.deleteStory(_story["_id"].toString());
                if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                if (mounted) Navigator.pop(context);
              },
            ),
          ]),
        ),
      );
    } catch (_) {}
    if (mounted) _pause(false);
  }

  String _ago(String? iso) {
    final t = DateTime.tryParse(iso ?? "")?.toLocal();
    if (t == null) return "";
    final d = DateTime.now().difference(t);
    return d.inMinutes < 60 ? "${d.inMinutes}m" : "${d.inHours}h";
  }

  @override
  Widget build(BuildContext context) {
    final s = _story;
    final look = lookById(s["look"]?.toString() ?? "natural");
    final media = s["mediaType"] == "video"
        ? (_video != null && _video!.value.isInitialized
            ? FittedBox(fit: BoxFit.cover, child: SizedBox(width: _video!.value.size.width, height: _video!.value.size.height, child: VideoPlayer(_video!)))
            : const Center(child: CircularProgressIndicator(color: Colors.white)))
        : CachedNetworkImage(imageUrl: resolveMediaUrl(s["mediaUrl"]?.toString()) ?? "", fit: BoxFit.cover, placeholder: (_, _) => const Center(child: CircularProgressIndicator(color: Colors.white)));
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 300) Navigator.pop(context);
        },
        onLongPressStart: (_) => _pause(true),
        onLongPressEnd: (_) => _pause(false),
        onTapUp: (d) {
          final w = MediaQuery.of(context).size.width;
          final rtl = Directionality.of(context) == TextDirection.rtl;
          final right = d.globalPosition.dx > w / 3;
          (right != rtl) ? _next() : _prev();
        },
        child: Stack(fit: StackFit.expand, children: [
          ColorFiltered(colorFilter: ColorFilter.matrix(look.matrix), child: media),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black54, Colors.transparent, Colors.transparent, Colors.black54], stops: [0, 0.2, 0.75, 1]),
            ),
          ),
          SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(children: [
                  for (var i = 0; i < _stories.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: AnimatedBuilder(
                            animation: _progress,
                            builder: (_, _) => LinearProgressIndicator(
                              minHeight: 2.6,
                              value: i < _s ? 1 : i == _s ? _progress.value : 0,
                              backgroundColor: Colors.white30,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
              ListTile(
                leading: UserAvatar(imageUrl: _user["profileImage"]?.toString(), name: _user["name"]?.toString(), radius: 18),
                title: Text("${_user["name"]}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                subtitle: Text(_ago(s["createdAt"]?.toString()), style: const TextStyle(color: Colors.white70)),
                trailing: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
              ),
              const Spacer(),
              if ((s["caption"] ?? "").toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Text(s["caption"].toString(),
                      textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, shadows: [Shadow(blurRadius: 8)])),
                ),
              if ((s["musicTitle"] ?? "").toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text("♪ ${s["musicTitle"]}", style: const TextStyle(color: Colors.white70)),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: _mine
                    ? TextButton.icon(
                        onPressed: _showViewers,
                        icon: const Icon(Icons.visibility_rounded, color: Colors.white),
                        label: Text("${s["viewCount"] ?? 0} ${tr("views")}", style: const TextStyle(color: Colors.white)),
                      )
                    : Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        IconButton(
                          iconSize: 30,
                          onPressed: () async {
                            setState(() => _liked = !_liked);
                            try {
                              _liked = await SocialApi.likeStory(s["_id"].toString());
                              if (mounted) setState(() {});
                            } catch (_) {}
                          },
                          icon: Icon(_liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: _liked ? const Color(0xFFE8384F) : Colors.white),
                        ),
                      ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Pick a photo or clip, choose a filter, add a caption and share for 24 hours.
class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  File? _file;
  bool _video = false;
  String _look = "natural";
  final _caption = TextEditingController();
  bool _sending = false;
  VideoPlayerController? _preview;

  @override
  void dispose() {
    _caption.dispose();
    _preview?.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource src, {bool video = false}) async {
    final picker = ImagePicker();
    final x = video ? await picker.pickVideo(source: src, maxDuration: const Duration(seconds: 30)) : await picker.pickImage(source: src, imageQuality: 85, maxWidth: 1440);
    if (x == null) return;
    await _preview?.dispose();
    _preview = null;
    final f = File(x.path);
    if (video) {
      final c = VideoPlayerController.file(f);
      await c.initialize();
      await c.setLooping(true);
      await c.play();
      _preview = c;
    }
    setState(() {
      _file = f;
      _video = video;
    });
  }

  Future<void> _share() async {
    if (_file == null) return;
    setState(() => _sending = true);
    try {
      await SocialApi.createStory(file: _file!, video: _video, caption: _caption.text.trim(), look: _look);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final look = lookById(_look);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(tr("New story"))),
      body: _file == null
          ? Center(
              child: Wrap(spacing: 16, runSpacing: 16, alignment: WrapAlignment.center, children: [
                _Pick(icon: Icons.photo_camera_rounded, label: tr("Camera"), onTap: () => _pick(ImageSource.camera)),
                _Pick(icon: Icons.videocam_rounded, label: tr("Video"), onTap: () => _pick(ImageSource.camera, video: true)),
                _Pick(icon: Icons.photo_library_rounded, label: tr("Gallery"), onTap: () => _pick(ImageSource.gallery)),
                _Pick(icon: Icons.video_library_rounded, label: tr("Clip"), onTap: () => _pick(ImageSource.gallery, video: true)),
              ]),
            )
          : Column(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.matrix(look.matrix),
                    child: _video && _preview != null
                        ? FittedBox(fit: BoxFit.cover, child: SizedBox(width: _preview!.value.size.width, height: _preview!.value.size.height, child: VideoPlayer(_preview!)))
                        : Image.file(_file!, fit: BoxFit.cover, width: double.infinity),
                  ),
                ),
              ),
              SizedBox(
                height: 54,
                child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), children: [
                  for (final l in momentLooks)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(label: Text(l.label), selected: _look == l.id, onSelected: (_) => setState(() => _look = l.id)),
                    ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: SafeArea(
                  top: false,
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _caption,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(hintText: tr("Add a caption…"), hintStyle: const TextStyle(color: Colors.white60), fillColor: Colors.white12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _sending ? null : _share,
                      icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded),
                      label: Text(tr("Share")),
                    ),
                  ]),
                ),
              ),
            ]),
    );
  }
}

class _Pick extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Pick({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: 130,
          height: 110,
          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}
