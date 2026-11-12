import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/friendly_error.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../comment/presentation/widgets/comment_bottom_sheet.dart';
import '../../../friends/domain/models/friend_model.dart';
import '../../../friends/presentation/screens/friend_profile_screen.dart';
import '../../../post/domain/eco_activity.dart';
import '../../../profile/application/providers/my_profile_provider.dart';
import '../../application/providers/feed_provider.dart';
import '../../domain/models/feed_model.dart';
import 'moment_media.dart';
import 'report_post_sheet.dart';
import 'package:greenifyx/core/i18n/app_locale.dart';

String _ago(DateTime? t) {
  if (t == null) return "";
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return "Just now";
  if (d.inMinutes < 60) return "${d.inMinutes}m";
  if (d.inHours < 24) return "${d.inHours}h";
  if (d.inDays < 7) return "${d.inDays}d";
  return DateFormat("d MMM").format(t);
}

/// Feed post: header, edge-to-edge media with double-tap like, actions, caption.
class PostCard extends ConsumerStatefulWidget {
  final FeedModel post;
  final String meId;
  const PostCard({super.key, required this.post, required this.meId});

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> with SingleTickerProviderStateMixin {
  late bool _liked = widget.post.isLiked;
  late int _likes = widget.post.likes;
  late bool _saved = widget.post.isSaved;
  late bool _verified = widget.post.isVerified;
  bool _expanded = false;
  bool _verifying = false;
  late final AnimationController _burst = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void didUpdateWidget(covariant PostCard old) {
    super.didUpdateWidget(old);
    if (old.post.id != widget.post.id || old.post.likes != widget.post.likes || old.post.isLiked != widget.post.isLiked) {
      _liked = widget.post.isLiked;
      _likes = widget.post.likes;
      _saved = widget.post.isSaved;
      _verified = widget.post.isVerified;
    }
  }

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _toggleLike({bool fromDoubleTap = false}) async {
    if (fromDoubleTap) {
      HapticFeedback.lightImpact();
      _burst.forward(from: 0);
      if (_liked) return;
    }
    setState(() {
      _liked = !_liked;
      _likes += _liked ? 1 : -1;
    });
    try {
      await ref.read(feedRepositoryProvider).toggleLike(widget.post.id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _liked = !_liked;
        _likes += _liked ? 1 : -1;
      });
      _snack(friendlyError(e));
    }
  }

  Future<void> _toggleSave() async {
    setState(() => _saved = !_saved);
    try {
      final s = await ref.read(feedRepositoryProvider).toggleSave(widget.post.id);
      if (mounted) setState(() => _saved = s);
      if (mounted && s) _snack("Saved to your collection");
    } catch (e) {
      if (mounted) {
        setState(() => _saved = !_saved);
        _snack(friendlyError(e));
      }
    }
  }

  Future<void> _verify() async {
    setState(() => _verifying = true);
    try {
      await ref.read(feedRepositoryProvider).verifyPost(widget.post.id);
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      setState(() => _verified = true);
      _snack("Verified. Eco Points awarded to your friend.");
    } catch (e) {
      if (mounted) _snack(friendlyError(e));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _report() async {
    final reason = await showReportPostSheet(context);
    if (reason == null) return;
    try {
      await ref.read(feedRepositoryProvider).reportPost(widget.post.id, reason);
      if (mounted) _snack("Thanks. Our team will review this post.");
    } catch (e) {
      if (mounted) _snack(friendlyError(e));
    }
  }

  void _comments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CommentBottomSheet(postId: widget.post.id),
    );
  }

  void _openUser(String id, String name, String image) {
    if (id.isEmpty || id == widget.meId) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FriendProfileScreen(
          friend: FriendModel(id: id, name: name, bio: "", profileImage: image, ecoPoints: 0, level: 1, streak: 0),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final c = laneColor(p.cause);
    final mine = p.userId == widget.meId;
    final canVerify = !_verified && p.userId.isNotEmpty && !mine;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 10),
          child: Row(children: [
            GestureDetector(
              onTap: () => _openUser(p.userId, p.name, p.profileImage ?? ""),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [c, AppColors.sun])),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                  child: UserAvatar(imageUrl: p.profileImage, name: p.name, radius: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: AppColors.ink)),
                  ),
                  if (_verified) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.verified_rounded, size: 16, color: AppColors.eco),
                  ],
                ]),
                Text.rich(
                  TextSpan(children: [
                    if (p.tagged.isNotEmpty) ...[
                      const TextSpan(text: "with "),
                      for (var i = 0; i < p.tagged.length && i < 2; i++) ...[
                        if (i > 0) const TextSpan(text: ", "),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: GestureDetector(
                            onTap: () => _openUser(p.tagged[i].id, p.tagged[i].name, p.tagged[i].profileImage),
                            child: Text(p.tagged[i].name.split(" ").first,
                                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink, fontSize: 12.5)),
                          ),
                        ),
                      ],
                      if (p.tagged.length > 2) TextSpan(text: " +${p.tagged.length - 2}"),
                      const TextSpan(text: " · "),
                    ],
                    TextSpan(text: _ago(p.createdAt)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.subtitle, fontSize: 12.5),
                ),
              ]),
            ),
            PopupMenuButton<String>(
              tooltip: tr("More"),
              icon: const Icon(Icons.more_horiz_rounded, color: AppColors.ink),
              onSelected: (v) {
                if (v == "report") _report();
                if (v == "save") _toggleSave();
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: "save", child: Text(_saved ? "Remove from saved" : "Save post")),
                if (!mine) PopupMenuItem(value: "report", child: Text(tr("Report post"))),
              ],
            ),
          ]),
        ),
        // Media
        GestureDetector(
          onDoubleTap: () => _toggleLike(fromDoubleTap: true),
          child: Stack(alignment: Alignment.center, children: [
            MomentMedia(
              url: p.image,
              mediaType: p.mediaType,
              look: p.look,
              musicUrl: p.musicUrl,
              musicTitle: p.musicTitle,
              musicStartSec: p.musicStartSec,
              muteOriginal: p.muteOriginal,
            ),
            Positioned(
              left: 12,
              top: 12,
              child: _Glass(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(activityIcon(p.activityIcon), color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(p.activity, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
                ]),
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: _Glass(
                color: _verified ? AppColors.eco.withValues(alpha: 0.85) : null,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_verified ? Icons.verified_rounded : Icons.stars_rounded, color: _verified ? Colors.white : AppColors.sun, size: 15),
                  const SizedBox(width: 4),
                  Text("+${p.ecoPoints}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
                ]),
              ),
            ),
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _burst,
                builder: (_, _) {
                  final t = _burst.value;
                  if (t == 0 || t == 1) return const SizedBox.shrink();
                  final scale = t < 0.3 ? Curves.easeOutBack.transform(t / 0.3) * 1.2 : 1.2 - (t - 0.3) * 0.3;
                  final opacity = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3);
                  return Opacity(
                    opacity: opacity.clamp(0, 1),
                    child: Transform.scale(
                      scale: scale,
                      child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 110,
                          shadows: [Shadow(color: Colors.black38, blurRadius: 24)]),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
        // Actions
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
          child: Row(children: [
            _Action(
              icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: _liked ? const Color(0xFFE8384F) : AppColors.ink,
              onTap: _toggleLike,
              pop: _liked,
            ),
            _Action(icon: Icons.mode_comment_outlined, onTap: _comments),
            const Spacer(),
            if (canVerify)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.eco,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: _verifying ? null : _verify,
                  icon: const Icon(Icons.verified_outlined, size: 18),
                  label: Text(tr("Verify")),
                ),
              ),
            _Action(icon: _saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, onTap: _toggleSave, pop: _saved),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_likes > 0)
              Text("$_likes ${_likes == 1 ? "like" : "likes"}", style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
            if (p.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: "${p.name.split(" ").first}  ", style: const TextStyle(fontWeight: FontWeight.w800)),
                    TextSpan(text: p.description),
                  ]),
                  maxLines: _expanded ? null : 2,
                  overflow: _expanded ? null : TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.ink, fontSize: 14.5, height: 1.4),
                ),
              ),
            ],
            if (p.comments > 0) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _comments,
                child: Text("View ${p.comments == 1 ? "1 comment" : "all ${p.comments} comments"}",
                    style: const TextStyle(color: AppColors.subtitle, fontSize: 13.5)),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _Glass extends StatelessWidget {
  final Widget child;
  final Color? color;
  const _Glass({required this.child, this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color ?? Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: child,
      );
}

class _Action extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool pop;
  const _Action({required this.icon, required this.onTap, this.color = AppColors.ink, this.pop = false});

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onTap,
        iconSize: 27,
        icon: AnimatedScale(
          scale: pop ? 1.12 : 1,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutBack,
          child: Icon(icon, color: color),
        ),
      );
}
