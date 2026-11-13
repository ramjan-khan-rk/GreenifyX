import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/i18n/app_locale.dart';
import '../../core/services/session_user.dart';
import '../../core/services/socket_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/utils/media_url.dart';
import '../../core/widgets/user_avatar.dart';
import '../chat/data/api/message_api.dart';
import '../chat/presentation/widgets/voice_note.dart';
import '../social/social_api.dart';

/// Community group chat: text, photos and voice notes, live for every member.
class GroupChatScreen extends StatefulWidget {
  final String communityId;
  final String name;
  const GroupChatScreen({super.key, required this.communityId, required this.name});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _recorder = VoiceRecorder();
  final _api = MessageApi();
  final List<Json> _msgs = [];
  int _members = 0;
  bool _loading = true;
  bool _sending = false;
  bool _recording = false;
  bool _older = true;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    SocketService.instance.on("groupMessage", _onLive);
    _load();
  }

  @override
  void dispose() {
    SocketService.instance.off("groupMessage", _onLive);
    _tick?.cancel();
    _recorder.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onLive(dynamic raw) {
    if (!mounted || raw is! Map || raw["community"]?.toString() != widget.communityId) return;
    setState(() => _msgs.add(Json.from(raw)));
    _bottom();
  }

  Future<void> _load({bool older = false}) async {
    try {
      final r = await SocialApi.groupMessages(widget.communityId, before: older && _msgs.isNotEmpty ? _msgs.first["createdAt"]?.toString() : null);
      final list = maps(r["messages"]);
      if (!mounted) return;
      setState(() {
        _members = ((r["community"] as Map?)?["members"] as num?)?.toInt() ?? 0;
        if (older) {
          _msgs.insertAll(0, list);
        } else {
          _msgs
            ..clear()
            ..addAll(list);
        }
        _older = list.length >= 50;
        _loading = false;
      });
      if (!older) _bottom(jump: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  void _bottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      jump ? _scroll.jumpTo(end) : _scroll.animateTo(end, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  Future<void> _send(Json body) async {
    setState(() => _sending = true);
    try {
      final m = await SocialApi.sendGroupMessage(widget.communityId, body);
      setState(() => _msgs.add(m));
      _bottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendText() async {
    final t = _input.text.trim();
    if (t.isEmpty) return;
    _input.clear();
    await _send({"text": t});
  }

  Future<void> _photo() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1600);
    if (x == null) return;
    setState(() => _sending = true);
    try {
      final url = await _api.uploadImage(File(x.path));
      await _send({"image": url});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _mic() async {
    if (_recording) {
      _tick?.cancel();
      final r = await _recorder.stop();
      setState(() => _recording = false);
      if (r == null) return;
      setState(() => _sending = true);
      try {
        final url = await _api.uploadAudio(r.file);
        await _send({"audio": url, "durationSec": r.seconds});
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
        if (mounted) setState(() => _sending = false);
      }
      return;
    }
    if (!await _recorder.start()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr("Allow the microphone to record voice notes"))));
      return;
    }
    setState(() => _recording = true);
    _tick = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = SessionUser.id;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        titleSpacing: 0,
        title: Row(children: [
          const CircleAvatar(backgroundColor: AppColors.eco, child: Icon(Icons.groups_rounded, color: Colors.white)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text("$_members ${tr("members")}", style: TextStyle(fontSize: 12, color: AppColors.subtitle)),
            ]),
          ),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: _msgs.length + (_older ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (_older && i == 0) return TextButton(onPressed: () => _load(older: true), child: Text(tr("Load earlier messages")));
                    final m = _msgs[i - (_older ? 1 : 0)];
                    final sender = Json.from((m["sender"] ?? {}) as Map);
                    final mine = sender["_id"]?.toString() == me;
                    final t = DateTime.tryParse(m["createdAt"]?.toString() ?? "")?.toLocal();
                    Widget body;
                    if ((m["audio"] ?? "").toString().isNotEmpty) {
                      body = VoiceNotePlayer(url: m["audio"].toString(), durationSec: (m["durationSec"] as num?)?.toInt() ?? 0, mine: mine);
                    } else if ((m["image"] ?? "").toString().isNotEmpty) {
                      body = ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(resolveMediaUrl(m["image"].toString()) ?? "", width: 220, fit: BoxFit.cover));
                    } else {
                      body = Text(m["text"]?.toString() ?? "", style: TextStyle(color: mine ? Colors.white : AppColors.ink, fontSize: 15.5, height: 1.35));
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start, crossAxisAlignment: CrossAxisAlignment.end, children: [
                        if (!mine) ...[UserAvatar(imageUrl: sender["profileImage"]?.toString(), name: sender["name"]?.toString(), radius: 14), const SizedBox(width: 6)],
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                            decoration: BoxDecoration(
                              gradient: mine ? const LinearGradient(colors: [AppColors.joy, Color(0xFFEB7F5C)]) : null,
                              color: mine ? null : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                              if (!mine)
                                Text(sender["name"]?.toString() ?? "", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppColors.eco)),
                              body,
                              const SizedBox(height: 2),
                              Text(t == null ? "" : DateFormat("h:mm a").format(t), style: TextStyle(fontSize: 10.5, color: mine ? Colors.white70 : AppColors.subtitle)),
                            ]),
                          ),
                        ),
                      ]),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Row(children: [
              IconButton(onPressed: _sending || _recording ? null : _photo, icon: const Icon(Icons.add_photo_alternate_outlined)),
              Expanded(
                child: _recording
                    ? Container(
                        height: 48,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24)),
                        child: Text("● ${formatDuration(_recorder.elapsed)}  ${tr("Recording…")}", style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
                      )
                    : TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(hintText: tr("Message"), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                      ),
              ),
              const SizedBox(width: 6),
              FloatingActionButton.small(
                heroTag: "gsend",
                elevation: 1,
                onPressed: _sending ? null : (_input.text.trim().isNotEmpty ? _sendText : _mic),
                child: _sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(_input.text.trim().isNotEmpty || _recording ? Icons.send_rounded : Icons.mic_rounded),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
