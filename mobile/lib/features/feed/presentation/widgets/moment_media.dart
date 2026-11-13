import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/media_url.dart';
import '../../../post/domain/looks.dart';
import '../../application/feed_audio.dart';

/// Cloudinary serves a poster frame when the video extension is swapped for .jpg.
String? videoPoster(String url) {
  if (!url.contains("res.cloudinary.com")) return null;
  return url.replaceFirst(RegExp(r"\.(mp4|mov|webm|m4v)$", caseSensitive: false), ".jpg");
}

class MomentMedia extends StatelessWidget {
  final String url;
  final String mediaType;
  final String look;
  final String musicUrl;
  final String musicTitle;
  final int musicStartSec;
  final bool muteOriginal;

  const MomentMedia({
    super.key,
    required this.url,
    required this.mediaType,
    this.look = "natural",
    this.musicUrl = "",
    this.musicTitle = "",
    this.musicStartSec = 0,
    this.muteOriginal = false,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = resolveMediaUrl(url) ?? "";
    final isVideo = mediaType == "video";
    final poster = isVideo ? videoPoster(resolved) : resolved;

    Widget picture = poster == null
        ? Container(color: AppColors.inkFixedFixed)
        : CachedNetworkImage(
            imageUrl: poster,
            width: double.infinity,
            height: 340,
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(color: AppColors.blush),
            errorWidget: (_, _, _) => Container(
              color: isVideo ? AppColors.ink : AppColors.blush,
              alignment: Alignment.center,
              child: Icon(isVideo ? Icons.movie_rounded : Icons.broken_image_outlined, color: isVideo ? Colors.white54 : null),
            ),
          );
    // Photos get the look baked in by the CDN; videos are filtered on device.
    if (isVideo && look != "natural") {
      picture = ColorFiltered(colorFilter: ColorFilter.matrix(lookById(look).matrix), child: picture);
    }

    return SizedBox(
      height: 340,
      width: double.infinity,
      child: Stack(fit: StackFit.expand, children: [
        GestureDetector(
          onTap: isVideo
              ? () {
                  FeedAudio.instance.stop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MomentPlayer(
                        url: resolved,
                        look: look,
                        musicUrl: musicUrl,
                        musicStartSec: musicStartSec,
                        muteOriginal: muteOriginal,
                      ),
                    ),
                  );
                }
              : null,
          child: picture,
        ),
        if (isVideo)
          IgnorePointer(
            child: Center(
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 44),
              ),
            ),
          ),
        if (musicUrl.isNotEmpty)
          Positioned(
            left: 12,
            bottom: 12,
            right: 64,
            child: _MusicChip(url: musicUrl, title: musicTitle, startSec: musicStartSec, enabled: !isVideo),
          ),
      ]),
    );
  }
}

class _MusicChip extends StatelessWidget {
  final String url;
  final String title;
  final int startSec;
  final bool enabled;
  const _MusicChip({required this.url, required this.title, required this.startSec, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FeedAudio.instance,
      builder: (context, _) {
        final playing = FeedAudio.instance.isPlaying(url);
        final loading = FeedAudio.instance.isLoading(url);
        return Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: enabled ? () => FeedAudio.instance.toggle(url, startSec: startSec) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (loading)
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  else
                    Icon(
                      enabled ? (playing ? Icons.volume_up_rounded : Icons.volume_off_rounded) : Icons.music_note_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      title.isEmpty ? "Soundtrack" : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Full-screen video with its look, optional soundtrack and a mute switch.
class MomentPlayer extends StatefulWidget {
  final String url;
  final String look;
  final String musicUrl;
  final int musicStartSec;
  final bool muteOriginal;

  const MomentPlayer({
    super.key,
    required this.url,
    this.look = "natural",
    this.musicUrl = "",
    this.musicStartSec = 0,
    this.muteOriginal = false,
  });

  @override
  State<MomentPlayer> createState() => _MomentPlayerState();
}

class _MomentPlayerState extends State<MomentPlayer> {
  late final VideoPlayerController _video = VideoPlayerController.networkUrl(Uri.parse(widget.url));
  final AudioPlayer _music = AudioPlayer();
  bool _muted = false;

  bool get _hasMusic => widget.musicUrl.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _video.initialize().then((_) async {
      if (!mounted) return;
      await _video.setLooping(true);
      await _video.setVolume(widget.muteOriginal ? 0 : 1);
      if (_hasMusic) {
        try {
          await _music.setUrl(widget.musicUrl);
          await _music.setLoopMode(LoopMode.one);
          if (widget.musicStartSec > 0) await _music.seek(Duration(seconds: widget.musicStartSec));
          _music.play();
        } catch (_) {}
      }
      setState(() {});
      _video.play();
    });
  }

  @override
  void dispose() {
    _video.dispose();
    _music.dispose();
    super.dispose();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _video.setVolume(_muted || widget.muteOriginal ? 0 : 1);
    _music.setVolume(_muted ? 0 : 1);
  }

  void _togglePlay() {
    if (_video.value.isPlaying) {
      _video.pause();
      _music.pause();
    } else {
      _video.play();
      if (_hasMusic) _music.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    Widget view = _video.value.isInitialized
        ? AspectRatio(aspectRatio: _video.value.aspectRatio, child: VideoPlayer(_video))
        : const CircularProgressIndicator(color: Colors.white);
    if (widget.look != "natural" && _video.value.isInitialized) {
      view = ColorFiltered(colorFilter: ColorFilter.matrix(lookById(widget.look).matrix), child: view);
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: _muted ? "Unmute" : "Mute",
            onPressed: _toggleMute,
            icon: Icon(_muted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: _togglePlay,
        child: Stack(alignment: Alignment.center, children: [
          Center(child: view),
          if (_video.value.isInitialized && !_video.value.isPlaying)
            const Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 80),
          if (_video.value.isInitialized)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(_video, allowScrubbing: true, colors: const VideoProgressColors(playedColor: AppColors.joy)),
            ),
        ]),
      ),
    );
  }
}
