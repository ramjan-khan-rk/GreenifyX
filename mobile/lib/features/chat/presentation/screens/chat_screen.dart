import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  void initState() {
    super.initState();
    _input.addListener(() {
      final has = _input.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    ChatScreen.activeUserId = widget.userId;
    SocketService.instance.on("receiveMessage", _onIncoming);
    ref.read(messageRepositoryProvider).markRead(widget.userId);
  }

  @override
  void dispose() {
    if (ChatScreen.activeUserId == widget.userId) ChatScreen.activeUserId = null;
    SocketService.instance.off("receiveMessage", _onIncoming);
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
          UserAvatar(imageUrl: widget.profileImage, name: widget.userName, radius: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.userName,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5, color: AppColors.ink)),
              const Text("GreenifyX friend", style: TextStyle(fontSize: 12, color: AppColors.subtitle)),
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
      content = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(resolveMediaUrl(message.image) ?? message.image, width: 220, fit: BoxFit.cover),
      );
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  : TextField(
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
                    ),
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
