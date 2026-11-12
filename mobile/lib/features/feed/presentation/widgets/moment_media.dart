import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/media_url.dart';

class MomentMedia extends StatelessWidget {
  final String url;
  final String mediaType;

  const MomentMedia({
    super.key,
    required this.url,
    required this.mediaType,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = resolveMediaUrl(url) ?? "";
    if (mediaType == "video") {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MomentPlayer(url: resolved),
            ),
          );
        },
        child: Container(
          height: 320,
          color: AppColors.ink,
          alignment: Alignment.center,
          child: const Icon(
            Icons.play_circle_fill_rounded,
            color: Colors.white,
            size: 72,
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: resolved,
      width: double.infinity,
      height: 320,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(height: 320, color: AppColors.blush),
      errorWidget: (_, _, _) => Container(
        height: 320,
        alignment: Alignment.center,
        color: AppColors.blush,
        child: const Icon(Icons.broken_image_outlined),
      ),
    );
  }
}

class MomentPlayer extends StatefulWidget {
  final String url;

  const MomentPlayer({super.key, required this.url});

  @override
  State<MomentPlayer> createState() => _MomentPlayerState();
}

class _MomentPlayerState extends State<MomentPlayer> {
  late final VideoPlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          controller.play();
        }
      });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Center(
        child: controller.value.isInitialized
            ? AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
