import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/deeds.dart';
import '../../domain/looks.dart';
import '../../data/repositories/post_repository.dart';
import '../../../../core/utils/friendly_error.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final descriptionController = TextEditingController();
  final picker = ImagePicker();
  final repository = PostRepository();

  File? selectedFile;
  bool isVideo = false;
  bool submitting = false;
  String lane = deedLanes.first;
  String activity = deeds.first.name;
  String look = "hd";

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> pick(bool video) async {
    final file = video
        ? await picker.pickVideo(
            source: ImageSource.gallery,
            maxDuration: const Duration(seconds: 45),
          )
        : await picker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 95,
            maxWidth: 3840,
          );

    if (file == null) return;
    setState(() {
      selectedFile = File(file.path);
      isVideo = video;
      if (video) look = "natural";
    });
  }

  Future<void> submit() async {
    if (selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Add a photo or a short video")),
      );
      return;
    }

    setState(() => submitting = true);

    try {
      final name = selectedFile!.path.split(RegExp(r"[/\\]")).last;
      final media = isVideo
          ? MediaType("video", name.toLowerCase().endsWith(".mov") ? "quicktime" : "mp4")
          : MediaType("image", "jpeg");

      final formData = FormData.fromMap({
        "description": descriptionController.text.trim(),
        "activity": activity,
        "cause": lane,
        "look": look,
        "image": await MultipartFile.fromFile(
          selectedFile!.path,
          filename: name,
          contentType: media,
        ),
      });

      await repository.createPost(formData);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.card,
          title: Text("You put something good out there", style: AppTextStyles.title),
          content: Text(
            "Friends can feel it now. Eco Points arrive when one of them verifies it.",
            style: AppTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Love that"),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final laneDeeds = deeds.where((deed) => deed.lane == lane).toList();
    final selectedDeed = laneDeeds.firstWhere(
      (deed) => deed.name == activity,
      orElse: () => laneDeeds.first,
    );
    final selectedLook = lookById(look);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Share a moment", style: AppTextStyles.title),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            "Planet, people, animals, or the feeling after you helped.",
            style: AppTextStyles.subtitle.copyWith(height: 1.4),
          ),
          const SizedBox(height: 16),
          _MediaStage(
            file: selectedFile,
            isVideo: isVideo,
            look: selectedLook,
            onPhoto: () => pick(false),
            onVideo: () => pick(true),
          ),
          if (!isVideo && selectedFile != null) ...[
            const SizedBox(height: 14),
            Text("Look", style: AppTextStyles.title.copyWith(fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              "A cleaner finish on the photo. The original stays yours.",
              style: AppTextStyles.subtitle,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final item in momentLooks)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(item.label),
                        selected: look == item.id,
                        onSelected: (_) => setState(() => look = item.id),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text("Who is this for?", style: AppTextStyles.title.copyWith(fontSize: 16)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in deedLanes)
                ChoiceChip(
                  label: Text(item),
                  selected: lane == item,
                  onSelected: (_) {
                    final next = deeds.firstWhere((deed) => deed.lane == item);
                    setState(() {
                      lane = item;
                      activity = next.name;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          for (final deed in laneDeeds)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: activity == deed.name ? AppColors.blush : AppColors.card,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() => activity = deed.name),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          activity == deed.name
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: AppColors.joy,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(deed.name, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
                              Text(deed.line, style: AppTextStyles.subtitle),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: descriptionController,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: selectedDeed.lane == "Stories"
                  ? "What stayed with you?"
                  : "Tell it the way it happened",
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: submitting ? null : submit,
              child: submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text("Share the moment"),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaStage extends StatelessWidget {
  final File? file;
  final bool isVideo;
  final MomentLook look;
  final VoidCallback onPhoto;
  final VoidCallback onVideo;

  const _MediaStage({
    required this.file,
    required this.isVideo,
    required this.look,
    required this.onPhoto,
    required this.onVideo,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 280,
        width: double.infinity,
        color: AppColors.ink,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (file == null)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: AppColors.sun, size: 42),
                  const SizedBox(height: 8),
                  Text(
                    "A photo or a short clip",
                    style: AppTextStyles.body.copyWith(color: Colors.white),
                  ),
                ],
              )
            else if (isVideo)
              const Center(
                child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 64),
              )
            else
              ColorFiltered(
                colorFilter: ColorFilter.matrix(look.matrix),
                child: Image.file(file!, fit: BoxFit.cover),
              ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Row(
                children: [
                  _PickButton(label: "Photo", icon: Icons.photo_rounded, onTap: onPhoto),
                  const SizedBox(width: 8),
                  _PickButton(label: "Video", icon: Icons.videocam_rounded, onTap: onVideo),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PickButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FilledButton.tonalIcon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.ink,
        ),
      ),
    );
  }
}
