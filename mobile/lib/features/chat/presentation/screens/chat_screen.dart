import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/socket_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/chat_launcher.dart';
import '../../../../core/utils/friendly_error.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/app_status.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../application/providers/chat_provider.dart';
import '../../application/providers/chats_provider.dart';
import '../../domain/models/message_model.dart';
import '../widgets/voice_note.dart';

class ChatScreen extends ConsumerStatefulWidget {
  /// The friend whose chat is on screen, so new-message popups can be skipped.
  static String? activeUserId;

  final String userId;
  final String userName;
  final String profileImage;

  const ChatScreen({super.key, required this.userId, required this.userName, this.profileImage = ""});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _recorder = VoiceRecorder();
  Timer? _recTick;
  bool _sending = false;
  bool _recording = false;
  bool _hasText = false;

  // Presence and typing.
  bool _online = false;
  DateTime? _lastSeen;
  bool _peerTyping = false;
  bool _iAmTyping = false;
  Timer? _peerTypingTimeout;
  Timer? _myTypingStop;

  @override
  void initState() {
    super.initState();
    _input.addListener(() {
      final has = _input.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
      if (has) _typingPing();
    });
    ChatScreen.activeUserId = widget.userId;
    SocketService.instance.on("receiveMessage", _onIncoming);
    SocketService.instance.on("typing", _onTyping);
    SocketService.instance.on("presence", _onPresence);
    SocketService.instance.on("messagesRead", _onRead);
    _loadPresence();
    ref.read(messageRepositoryProvider).markRead(widget.userId);
  }

  @override
  void dispose() {
    if (ChatScreen.activeUserId == widget.userId) ChatScreen.activeUserId = null;
    SocketService.instance.off("receiveMessage", _onIncoming);
    SocketService.instance.off("typing", _onTyping);
    SocketService.instance.off("presence", _onPresence);
    SocketService.instance.off("messagesRead", _onRead);
    if (_iAmTyping) SocketService.instance.emit("typing", {"to": widget.userId, "typing": false});
    _peerTypingTimeout?.cancel();
    _myTypingStop?.cancel();
    _recTick?.cancel();
    _recorder.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onIncoming(dynamic raw) {
    if (!mounted || raw is! Map) return;
    final sender = raw["sender"];
    final from = sender is Map ? sender["_id"]?.toString() : sender?.toString();
    if (from == widget.userId) {
      ref.invalidate(chatProvider(widget.userId));
      ref.read(messageRepositoryProvider).markRead(widget.userId);
    }
  }

  Future<void> _loadPresence() async {
    final (online, seen) = await ref.read(messageRepositoryProvider).presence(widget.userId);
    if (!mounted) return;
    setState(() {
      _online = online;
      _lastSeen = seen;
    });
  }

  void _onTyping(dynamic raw) {
    if (!mounted || raw is! Map || raw["from"]?.toString() != widget.userId) return;
    final typing = raw["typing"] == true;
    _peerTypingTimeout?.cancel();
    // Clear the indicator even if the "stopped" event never arrives.
    if (typing) {
      _peerTypingTimeout = Timer(const Duration(seconds: 6), () {
        if (mounted) setState(() => _peerTyping = false);
      });
    }
    setState(() {
      _peerTyping = typing;
      if (typing) _online = true;
    });
  }

  void _onPresence(dynamic raw) {
    if (!mounted || raw is! Map || raw["userId"]?.toString() != widget.userId) return;
    setState(() {
      _online = raw["online"] == true;
      if (!_online) {
        _peerTyping = false;
        _lastSeen = DateTime.tryParse(raw["lastSeenAt"]?.toString() ?? "")?.toLocal() ?? DateTime.now();
      }
    });
  }

  void _onRead(dynamic raw) {
    if (!mounted || raw is! Map || raw["by"]?.toString() != widget.userId) return;
    ref.invalidate(chatProvider(widget.userId));
  }

  void _typingPing() {
    if (!_iAmTyping) {
      _iAmTyping = true;
      SocketService.instance.emit("typing", {"to": widget.userId, "typing": true});
    }
    _myTypingStop?.cancel();
    _myTypingStop = Timer(const Duration(milliseconds: 2500), _typingDone);
  }

  void _typingDone() {
    _myTypingStop?.cancel();
    if (!_iAmTyping) return;
    _iAmTyping = false;
    SocketService.instance.emit("typing", {"to": widget.userId, "typing": false});
  }

  String get _status {
    if (_peerTyping) return "typing…";
    if (_online) return "Online";
    final s = _lastSeen;
    if (s == null) return "Tap the call buttons to talk";
    final now = DateTime.now();
    final diff = now.difference(s);
    if (diff.inMinutes < 1) return "Last seen just now";
    if (diff.inMinutes < 60) return "Last seen ${diff.inMinutes} min ago";
    if (_sameDay(s, now)) return "Last seen today at ${DateFormat("h:mm a").format(s)}";
    if (_sameDay(s, now.subtract(const Duration(days: 1)))) return "Last seen yesterday at ${DateFormat("h:mm a").format(s)}";
    return "Last seen ${DateFormat("d MMM").format(s)}";
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final shot = await ImagePicker().pickImage(source: source, imageQuality: 80, maxWidth: 1600);
    if (shot == null || !mounted) return;
    final file = File(shot.path);
    final caption = TextEditingController();
    final send = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(onPressed: () => Navigator.pop(ctx, false), icon: const Icon(Icons.close_rounded, color: Colors.white)),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
              child: Image.file(file, fit: BoxFit.contain),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: caption,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Add a caption…",
                      hintStyle: const TextStyle(color: Colors.white60),
                      filled: true,
                      fillColor: Colors.white12,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  heroTag: "send-photo",
                  backgroundColor: AppColors.joy,
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
    if (send != true || !mounted) return;
    setState(() => _sending = true);
    try {
      await ref.read(messageRepositoryProvider).sendPhoto(receiverId: widget.userId, file: file, caption: caption.text.trim());
      ref.invalidate(chatProvider(widget.userId));
      ref.invalidate(chatsProvider);
      _toBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, fallback: "Photo failed to send."))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _attachSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _AttachOption(icon: Icons.photo_camera_rounded, label: "Camera", color: AppColors.joy, onTap: () {
              Navigator.pop(ctx);
              _pickPhoto(ImageSource.camera);
            }),
            _AttachOption(icon: Icons.photo_library_rounded, label: "Gallery", color: const Color(0xFF7F53AC), onTap: () {
              Navigator.pop(ctx);
              _pickPhoto(ImageSource.gallery);
            }),
          ]),
        ),
      ),
    );
  }

  void _toBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      animate ? _scroll.animateTo(end, duration: const Duration(milliseconds: 250), curve: Curves.easeOut) : _scroll.jumpTo(end);
    });
  }

  Future<void> _sendText() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    _typingDone();
    setState(() => _sending = true);
    try {
      await ref.read(messageRepositoryProvider).sendMessage(receiverId: widget.userId, text: text);
      _input.clear();
      ref.invalidate(chatProvider(widget.userId));
      ref.invalidate(chatsProvider);
      _toBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _startRecording() async {
    final ok = await _recorder.start();
    if (!ok) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Allow the microphone to record voice notes")));
      return;
    }
    setState(() => _recording = true);
    _recTick = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      if (_recorder.elapsed.inSeconds >= 120) {
        _finishRecording();
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _cancelRecording() async {
    _recTick?.cancel();
    await _recorder.cancel();
    if (mounted) setState(() => _recording = false);
  }

  Future<void> _finishRecording() async {
    _recTick?.cancel();
    final result = await _recorder.stop();
    if (!mounted) return;
    setState(() => _recording = false);
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Too short. Hold on a little longer.")));
      return;
    }
    setState(() => _sending = true);
    try {
      await ref.read(messageRepositoryProvider).sendVoiceNote(receiverId: widget.userId, file: result.file, durationSec: result.seconds);
      ref.invalidate(chatProvider(widget.userId));
      ref.invalidate(chatsProvider);
      _toBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, fallback: "Voice note failed to send."))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider(widget.userId));
    return Scaffold(
      backgroundColor: const Color(0xFFF7F1EB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0.5,
        shadowColor: Colors.black12,
        titleSpacing: 0,
        title: Row(children: [
          Stack(children: [
            UserAvatar(imageUrl: widget.profileImage, name: widget.userName, radius: 19),
            if (_online)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ECC71),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.userName,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5, color: AppColors.ink)),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _status,
                  key: ValueKey(_status),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: _peerTyping || _online ? FontWeight.w700 : FontWeight.w500,
                    color: _peerTyping || _online ? AppColors.eco : AppColors.subtitle,
                  ),
                ),
              ),
            ]),
          ),
        ]),
        actions: [
          _HeaderAction(
            icon: Icons.call_rounded,
            tooltip: "Voice call",
            onTap: () => startCall(context, userId: widget.userId, name: widget.userName, video: false),
          ),
          _HeaderAction(
            icon: Icons.videocam_rounded,
            tooltip: "Video call",
            onTap: () => startCall(context, userId: widget.userId, name: widget.userName, video: true),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: messages.when(
            loading: () => const AppLoading(),
            error: (e, _) => AppErrorState(message: friendlyError(e), onRetry: () => ref.invalidate(chatProvider(widget.userId))),
            data: (list) {
              if (list.isEmpty) return _EmptyChat(name: widget.userName, image: widget.profileImage);
              _toBottom(animate: false);
              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final m = list[i];
                  final mine = m.senderId != widget.userId;
                  final prev = i > 0 ? list[i - 1] : null;
                  final next = i < list.length - 1 ? list[i + 1] : null;
                  final newDay = prev == null || !_sameDay(prev.createdAt, m.createdAt);
                  final groupedWithNext = next != null && next.senderId == m.senderId && _sameDay(next.createdAt, m.createdAt) &&
                      next.createdAt.difference(m.createdAt).inMinutes < 3;
                  return Column(children: [
                    if (newDay) _DayChip(date: m.createdAt),
                    _Bubble(message: m, mine: mine, tail: !groupedWithNext),
                  ]);
                },
              );
            },
          ),
        ),
        _Composer(
          controller: _input,
          hasText: _hasText,
          sending: _sending,
          recording: _recording,
          elapsed: _recorder.elapsed,
          onSend: _sendText,
          onAttach: _attachSheet,
          onMic: _startRecording,
          onCancelRecording: _cancelRecording,
          onFinishRecording: _finishRecording,
        ),
      ]),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _HeaderAction({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: IconButton.filledTonal(
        tooltip: tooltip,
        style: IconButton.styleFrom(backgroundColor: AppColors.eco.withValues(alpha: 0.12), foregroundColor: AppColors.eco),
        onPressed: onTap,
        icon: Icon(icon),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final DateTime date;
  const _DayChip({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final label = _sameDay(date, now)
        ? "Today"
        : _sameDay(date, now.subtract(const Duration(days: 1)))
            ? "Yesterday"
            : DateFormat(now.year == date.year ? "EEE, d MMM" : "d MMM yyyy").format(date);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.subtitle)),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool mine;
  final bool tail;
  const _Bubble({required this.message, required this.mine, required this.tail});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat("h:mm a").format(message.createdAt);
    final fg = mine ? Colors.white : AppColors.ink;
    const r = Radius.circular(18);
    const small = Radius.circular(5);
    Widget content;
    if (message.type == "audio" && message.audio.isNotEmpty) {
      content = VoiceNotePlayer(url: message.audio, durationSec: message.durationSec, mine: mine);
    } else if (message.type == "image" && message.image.isNotEmpty) {
      final url = resolveMediaUrl(message.image) ?? message.image;
      content = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _PhotoViewer(url: url))),
          child: Hero(
            tag: "${message.id}-$url",
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url,
                width: 230,
                height: 260,
                fit: BoxFit.cover,
                loadingBuilder: (c, child, p) => p == null
                    ? child
                    : Container(width: 230, height: 260, color: Colors.black12, child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                errorBuilder: (_, _, _) => Container(width: 230, height: 120, color: Colors.black12, child: const Icon(Icons.broken_image_outlined)),
              ),
            ),
          ),
        ),
        if (message.text.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 230),
              child: Text(message.text, style: TextStyle(color: fg, fontSize: 15, height: 1.35)),
            ),
          ),
      ]);
    } else {
      content = Text(message.text, style: TextStyle(color: fg, fontSize: 15.5, height: 1.35));
    }
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: tail ? 8 : 2, left: mine ? 48 : 0, right: mine ? 0 : 48),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          gradient: mine ? const LinearGradient(colors: [AppColors.joy, Color(0xFFEB7F5C)]) : null,
          color: mine ? null : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: r,
            topRight: r,
            bottomLeft: mine || !tail ? r : small,
            bottomRight: !mine || !tail ? r : small,
          ),
          boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 1))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
          content,
          const SizedBox(height: 3),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(time, style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 10.5)),
            if (mine) ...[
              const SizedBox(width: 3),
              Icon(message.isRead ? Icons.done_all_rounded : Icons.done_rounded, size: 14, color: fg.withValues(alpha: 0.85)),
            ],
          ]),
        ]),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  final String name;
  final String image;
  const _EmptyChat({required this.name, required this.image});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          UserAvatar(imageUrl: image, radius: 44),
          const SizedBox(height: 14),
          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 6),
          const Text(
            "Say hello, send a voice note, or start a call from the top bar.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.subtitle, height: 1.4),
          ),
        ]),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool hasText;
  final bool sending;
  final bool recording;
  final Duration elapsed;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onMic;
  final VoidCallback onCancelRecording;
  final VoidCallback onFinishRecording;

  const _Composer({
    required this.controller,
    required this.hasText,
    required this.sending,
    required this.recording,
    required this.elapsed,
    required this.onSend,
    required this.onAttach,
    required this.onMic,
    required this.onCancelRecording,
    required this.onFinishRecording,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        color: Colors.transparent,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 50),
              padding: EdgeInsets.only(left: recording ? 16 : 4, right: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))],
              ),
              child: recording
                  ? Row(children: [
                      const _RecDot(),
                      const SizedBox(width: 10),
                      Text(formatDuration(elapsed), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(width: 10),
                      const Expanded(child: Text("Recording…", style: TextStyle(color: AppColors.subtitle))),
                      TextButton(onPressed: onCancelRecording, child: const Text("Cancel")),
                    ])
                  : Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      IconButton(
                        tooltip: "Send a photo",
                        onPressed: sending ? null : onAttach,
                        icon: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.subtitle),
                      ),
                      Expanded(child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: "Message",
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    )),
                    ]),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 50,
            height: 50,
            child: Material(
              color: recording ? AppColors.eco : AppColors.joy,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: sending
                    ? null
                    : recording
                        ? onFinishRecording
                        : hasText
                            ? onSend
                            : onMic,
                child: Center(
                  child: sending
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : Icon(
                          recording ? Icons.send_rounded : hasText ? Icons.send_rounded : Icons.mic_rounded,
                          color: Colors.white,
                        ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _RecDot extends StatefulWidget {
  const _RecDot();

  @override
  State<_RecDot> createState() => _RecDotState();
}

class _RecDotState extends State<_RecDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.3, end: 1.0).animate(_c),
        child: Container(width: 12, height: 12, decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle)),
      );
}

class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AttachOption({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(radius: 30, backgroundColor: color, child: Icon(icon, color: Colors.white, size: 28)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  final String url;
  const _PhotoViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0),
      body: Center(
        child: InteractiveViewer(minScale: 1, maxScale: 4, child: Image.network(url, fit: BoxFit.contain)),
      ),
    );
  }
}
