import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/deeds.dart';
import '../../domain/eco_activity.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../friends/data/repositories/friend_repository.dart';
import '../../../friends/domain/models/friend_model.dart';
import '../../domain/looks.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/services/media_upload.dart';
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
  List<EcoActivity> activities = fallbackActivities;
  String query = "";
  final List<FriendModel> tagged = [];

  @override
  void initState() {
    super.initState();
    EcoActivityApi.load().then((list) {
      if (!mounted) return;
      setState(() {
        activities = list;
        final first = list.where((a) => a.lane == lane);
        if (first.isNotEmpty && !list.any((a) => a.name == activity)) activity = first.first.name;
      });
    });
  }

  Future<void> _pickTags() async {
    List<FriendModel> friends;
    try {
      friends = await FriendRepository().getFriends();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      return;
    }
    if (!mounted) return;
    if (friends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Add friends first to tag them")));
      return;
    }
    final picked = {for (final t in tagged) t.id};
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.6,
            child: Column(children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(children: [
                  Icon(Icons.person_add_alt_1_rounded, color: AppColors.joy),
                  SizedBox(width: 10),
                  Text("Who was with you?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ]),
              ),
              Expanded(
                child: ListView(children: [
                  for (final f in friends)
                    CheckboxListTile(
                      value: picked.contains(f.id),
                      onChanged: (v) => setSheet(() => v == true ? picked.add(f.id) : picked.remove(f.id)),
                      secondary: UserAvatar(imageUrl: f.profileImage, name: f.name, radius: 20),
                      title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(picked.isEmpty ? "Done" : "Tag ${picked.length} friend${picked.length == 1 ? "" : "s"}"),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      tagged
        ..clear()
        ..addAll(friends.where((f) => picked.contains(f.id)));
    });
  }
  String look = "hd";

  // Sound
  File? musicFile;
  String musicTitle = "";
  bool muteOriginal = false;
  final AudioPlayer musicPreview = AudioPlayer();
  bool previewingMusic = false;
  VideoPlayerController? videoPreview;

  @override
  void dispose() {
    descriptionController.dispose();
    musicPreview.dispose();
    videoPreview?.dispose();
    super.dispose();
  }

  Future<void> _setupVideoPreview(File file) async {
    await videoPreview?.dispose();
    final c = VideoPlayerController.file(file);
    videoPreview = c;
    await c.initialize();
    await c.setLooping(true);
    await c.setVolume(muteOriginal ? 0 : 1);
    if (mounted) setState(() {});
  }

  Future<void> pickMusic() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    final path = result?.files.single.path;
    if (path == null) return;
    final name = result!.files.single.name;
    final title = name.contains(".") ? name.substring(0, name.lastIndexOf(".")) : name;
    await musicPreview.stop();
    setState(() {
      musicFile = File(path);
      musicTitle = title.replaceAll(RegExp(r"[_-]+"), " ").trim();
      previewingMusic = false;
    });
  }

  Future<void> toggleMusicPreview() async {
    if (musicFile == null) return;
    if (previewingMusic) {
      await musicPreview.pause();
      videoPreview?.pause();
      setState(() => previewingMusic = false);
      return;
    }
    await musicPreview.setFilePath(musicFile!.path);
    setState(() => previewingMusic = true);
    videoPreview?.play();
    await musicPreview.play();
  }

  Future<void> removeMusic() async {
    await musicPreview.stop();
    setState(() {
      musicFile = null;
      musicTitle = "";
      previewingMusic = false;
    });
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
    });
    if (video) {
      await _setupVideoPreview(File(file.path));
    } else {
      await videoPreview?.dispose();
      setState(() {
        videoPreview = null;
        muteOriginal = false;
      });
    }
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

      await musicPreview.stop();
      videoPreview?.pause();
      final musicUrl = musicFile == null ? null : await uploadAudioFile(musicFile!);
      final formData = FormData.fromMap({
        "description": descriptionController.text.trim(),
        "activity": activity,
        if (tagged.isNotEmpty) "taggedUsers": jsonEncode([for (final t in tagged) t.id]),
        "cause": lane,
        "look": look,
        "musicUrl": ?musicUrl,
        if (musicUrl != null) "musicTitle": musicTitle,
        "muteOriginal": isVideo && muteOriginal ? "true" : "false",
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
    final shown = query.trim().isEmpty
        ? activities.where((a) => a.lane == lane).toList()
        : activities.where((a) => a.matches(query)).toList();
    final selected = activities.firstWhere((a) => a.name == activity, orElse: () => activities.first);
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
            video: videoPreview,
            onPhoto: () => pick(false),
            onVideo: () => pick(true),
          ),
          if (selectedFile != null) ...[
            const SizedBox(height: 14),
            Text("Filter", style: AppTextStyles.title.copyWith(fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              isVideo ? "Applied when friends watch your clip." : "A cleaner finish on the photo. The original stays yours.",
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
          if (selectedFile != null) ...[
            const SizedBox(height: 18),
            Text("Sound", style: AppTextStyles.title.copyWith(fontSize: 16)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(children: [
                if (musicFile == null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.joy, AppColors.sun]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.library_music_rounded, color: Colors.white),
                    ),
                    title: const Text("Add music", style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text("Pick a track from your phone"),
                    trailing: const Icon(Icons.add_rounded),
                    onTap: pickMusic,
                  )
                else
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: AppColors.joy),
                      onPressed: toggleMusicPreview,
                      icon: Icon(previewingMusic ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
                    ),
                    title: Text(musicTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text("Tap play to preview"),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(tooltip: "Change", onPressed: pickMusic, icon: const Icon(Icons.swap_horiz_rounded)),
                      IconButton(tooltip: "Remove", onPressed: removeMusic, icon: const Icon(Icons.close_rounded)),
                    ]),
                  ),
                if (isVideo) ...[
                  const Divider(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(muteOriginal ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: AppColors.navy),
                    title: const Text("Original sound", style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(muteOriginal ? "Muted" : "On"),
                    value: !muteOriginal,
                    onChanged: (on) {
                      setState(() => muteOriginal = !on);
                      videoPreview?.setVolume(on ? 1 : 0);
                    },
                  ),
                ],
              ]),
            ),
            if (musicFile != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text("Only use music you have the right to share.", style: AppTextStyles.subtitle.copyWith(fontSize: 12)),
              ),
          ],
          const SizedBox(height: 18),
          Text("What did you do?", style: AppTextStyles.title.copyWith(fontSize: 16)),
          const SizedBox(height: 10),
          TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: "Search: beach, metro, compost, e-waste…",
            ),
          ),
          const SizedBox(height: 12),
          if (query.trim().isEmpty)
            SizedBox(
              height: 40,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final item in deedLanes)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(item),
                      selected: lane == item,
                      onSelected: (_) => setState(() => lane = item),
                    ),
                  ),
              ]),
            ),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text("No activity matches \"$query\"", style: AppTextStyles.subtitle),
            ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [
              for (final a in shown)
                _ActivityTile(
                  activity: a,
                  selected: activity == a.name,
                  onTap: () => setState(() {
                    activity = a.name;
                    lane = a.lane;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Material(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: _pickTags,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  const Icon(Icons.person_add_alt_1_rounded, color: AppColors.joy),
                  const SizedBox(width: 12),
                  Expanded(
                    child: tagged.isEmpty
                        ? Text("Tag friends", style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700))
                        : Wrap(spacing: 6, runSpacing: 6, children: [
                            for (final t in tagged)
                              Chip(
                                avatar: UserAvatar(imageUrl: t.profileImage, name: t.name, radius: 11),
                                label: Text(t.name.split(" ").first),
                                onDeleted: () => setState(() => tagged.remove(t)),
                                visualDensity: VisualDensity.compact,
                              ),
                          ]),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.subtitle),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: descriptionController,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: selected.lane == "Stories"
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
  final VideoPlayerController? video;
  final VoidCallback onPhoto;
  final VoidCallback onVideo;

  const _MediaStage({
    required this.file,
    required this.isVideo,
    required this.look,
    required this.onPhoto,
    required this.onVideo,
    this.video,
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
            else if (isVideo && video != null && video!.value.isInitialized)
              GestureDetector(
                onTap: () => video!.value.isPlaying ? video!.pause() : video!.play(),
                child: ColorFiltered(
                  colorFilter: ColorFilter.matrix(look.matrix),
                  child: FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: video!.value.size.width,
                      height: video!.value.size.height,
                      child: VideoPlayer(video!),
                    ),
                  ),
                ),
              )
            else if (isVideo)
              const Center(child: CircularProgressIndicator(color: Colors.white))
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


class _ActivityTile extends StatelessWidget {
  final EcoActivity activity;
  final bool selected;
  final VoidCallback onTap;
  const _ActivityTile({required this.activity, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = laneColor(activity.lane);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: selected ? c.withValues(alpha: 0.10) : AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: selected ? c : AppColors.border, width: selected ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(11)),
                child: Icon(activityIcon(activity.icon), color: c, size: 20),
              ),
              const Spacer(),
              Text("+${activity.points}", style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 13)),
            ]),
            const Spacer(),
            Text(activity.label, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, height: 1.2, color: AppColors.ink)),
          ]),
        ),
      ),
    );
  }
}
