import 'dart:math';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../core/i18n/app_locale.dart';
import '../../core/services/api_service.dart';
import '../../core/services/socket_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/verified_tick.dart';

typedef Json = Map<String, dynamic>;

/// Who's live now + Go live.
class LiveListScreen extends StatefulWidget {
  const LiveListScreen({super.key});

  @override
  State<LiveListScreen> createState() => _LiveListScreenState();
}

class _LiveListScreenState extends State<LiveListScreen> {
  List<Json>? _items;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ApiService.dio.get("/live");
      if (!mounted) return;
      setState(() {
        _items = (r.data["sessions"] as List).map((e) => Json.from(e as Map)).toList();
        _enabled = r.data["enabled"] == true;
      });
    } catch (e) {
      if (mounted) setState(() => _items = []);
    }
  }

  Future<void> _goLive() async {
    final title = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr("Go live"), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          TextField(controller: title, decoration: InputDecoration(labelText: tr("What are you doing?"), hintText: tr("e.g. Beach clean-up at JBR"))),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE8384F)),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.sensors_rounded),
            label: Text(tr("Start live video")),
          ),
        ]),
      ),
    );
    if (ok != true || !mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => LiveRoomScreen(hostTitle: title.text.trim())));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: Text(tr("Live"))),
      floatingActionButton: _enabled
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFFE8384F),
              onPressed: _goLive,
              icon: const Icon(Icons.sensors_rounded),
              label: Text(tr("Go live")),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
          if (!_enabled)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.blush, borderRadius: BorderRadius.circular(18)),
              child: Text(tr("Live video is coming soon. Your admin needs to switch it on."), style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          if (items == null) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
          if (items != null && items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(children: [
                Icon(Icons.sensors_off_rounded, size: 56, color: AppColors.subtitle),
                const SizedBox(height: 10),
                Text(tr("Nobody is live right now. Be the first!"), textAlign: TextAlign.center),
              ]),
            ),
          for (final s in items ?? <Json>[])
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: Stack(clipBehavior: Clip.none, children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE8384F)),
                    child: UserAvatar(imageUrl: (s["host"] as Map)["profileImage"]?.toString(), name: (s["host"] as Map)["name"]?.toString(), radius: 24),
                  ),
                  Positioned(
                    bottom: -6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: const Color(0xFFE8384F), borderRadius: BorderRadius.circular(5)),
                      child: Text(tr("LIVE"), style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ]),
                title: Row(children: [
                  Flexible(child: Text((s["host"] as Map)["name"].toString(), style: const TextStyle(fontWeight: FontWeight.w800))),
                  VerifiedTick((s["host"] as Map)["verifiedBadge"]?.toString() ?? ""),
                ]),
                subtitle: Text("${s["title"]}\n👁 ${s["viewers"]}  ❤ ${s["hearts"]}"),
                isThreeLine: true,
                trailing: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFFE8384F), size: 34),
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => LiveRoomScreen(sessionId: s["_id"].toString())));
                  _load();
                },
              ),
            ),
        ]),
      ),
    );
  }
}

/// Host (hostTitle set) or viewer (sessionId set) of a live video.
class LiveRoomScreen extends StatefulWidget {
  final String? sessionId;
  final String? hostTitle;
  const LiveRoomScreen({super.key, this.sessionId, this.hostTitle});

  @override
  State<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<LiveRoomScreen> {
  final Room _room = Room(roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true));
  EventsListener<RoomEvent>? _listener;
  VideoTrack? _video;
  String? _id;
  String _title = "";
  Json _host = {};
  String? _error;
  bool _ended = false;
  int _hearts = 0;
  final List<Json> _comments = [];
  final List<_Heart> _flying = [];
  final _input = TextEditingController();
  final _rand = Random();

  bool get _isHost => widget.hostTitle != null;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final r = _isHost
          ? await ApiService.dio.post("/live", data: {"title": widget.hostTitle})
          : await ApiService.dio.post("/live/${widget.sessionId}/join");
      final s = Json.from(r.data["session"] as Map);
      _id = s["_id"].toString();
      _title = s["title"]?.toString() ?? "";
      _host = s["host"] is Map ? Json.from(s["host"] as Map) : {};
      _hearts = (s["hearts"] as num?)?.toInt() ?? 0;
      SocketService.instance.emit("live:join", {"id": _id});
      SocketService.instance.on("live:comment", _onComment);
      SocketService.instance.on("live:heart", _onHeart);
      SocketService.instance.on("live:ended", _onEnded);

      _listener = _room.createListener()
        ..on<TrackSubscribedEvent>((e) {
          if (e.track is VideoTrack && mounted) setState(() => _video = e.track as VideoTrack);
        })
        ..on<RoomDisconnectedEvent>((_) {
          if (mounted && !_isHost) setState(() => _ended = true);
        });
      await _room.connect(r.data["url"].toString(), r.data["token"].toString());
      if (_isHost) {
        await _room.localParticipant?.setCameraEnabled(true);
        await _room.localParticipant?.setMicrophoneEnabled(true);
        final pubs = _room.localParticipant?.videoTrackPublications ?? [];
        if (pubs.isNotEmpty && mounted) setState(() => _video = pubs.first.track);
      } else {
        for (final p in _room.remoteParticipants.values) {
          for (final pub in p.videoTrackPublications) {
            if (pub.track != null) _video = pub.track;
          }
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  void _onComment(dynamic raw) {
    if (!mounted || raw is! Map || raw["id"]?.toString() != _id) return;
    setState(() {
      _comments.add(Json.from(raw));
      if (_comments.length > 40) _comments.removeAt(0);
    });
  }

  void _onHeart(dynamic raw) {
    if (!mounted || raw is! Map || raw["id"]?.toString() != _id) return;
    final h = _Heart(UniqueKey(), 0.6 + _rand.nextDouble() * 0.4, Color.lerp(const Color(0xFFE8384F), AppColors.sun, _rand.nextDouble())!);
    setState(() {
      _hearts++;
      _flying.add(h);
    });
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _flying.remove(h));
    });
  }

  void _onEnded(dynamic raw) {
    if (mounted && raw is Map && raw["id"]?.toString() == _id && !_isHost) setState(() => _ended = true);
  }

  Future<void> _end() async {
    if (_isHost && _id != null) {
      SocketService.instance.emit("live:ended", {"id": _id});
      try {
        final r = await ApiService.dio.post("/live/$_id/end");
        final s = Json.from(r.data["summary"] as Map);
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(tr("Live ended")),
              content: Text("👁 ${s["viewers"]} ${tr("viewers")} · ❤ ${s["hearts"]} · 💬 ${s["comments"]} · ⏱ ${s["minutes"]} min"),
              actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(tr("Done")))],
            ),
          );
        }
      } catch (_) {}
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    if (_id != null) SocketService.instance.emit("live:leave", {"id": _id});
    SocketService.instance.off("live:comment", _onComment);
    SocketService.instance.off("live:heart", _onHeart);
    SocketService.instance.off("live:ended", _onEnded);
    _listener?.dispose();
    _room.disconnect();
    _room.dispose();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isHost,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _end();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(fit: StackFit.expand, children: [
          if (_video != null)
            VideoTrackRenderer(_video!, fit: VideoViewFit.cover)
          else
            Center(
              child: _error != null
                  ? Padding(padding: const EdgeInsets.all(30), child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)))
                  : const CircularProgressIndicator(color: Colors.white),
            ),
          if (_ended)
            Container(
              color: Colors.black87,
              alignment: Alignment.center,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.sensors_off_rounded, color: Colors.white, size: 56),
                const SizedBox(height: 10),
                Text(tr("This live has ended"), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                FilledButton(onPressed: () => Navigator.pop(context), child: Text(tr("Close"))),
              ]),
            ),
          SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFE8384F), borderRadius: BorderRadius.circular(6)),
                    child: Text(tr("LIVE"), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
                  const SizedBox(width: 10),
                  if (!_isHost) ...[
                    UserAvatar(imageUrl: _host["profileImage"]?.toString(), name: _host["name"]?.toString(), radius: 14),
                    const SizedBox(width: 6),
                  ],
                  Expanded(child: Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, shadows: [Shadow(blurRadius: 6)]))),
                  Text("❤ $_hearts", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 6),
                  if (_isHost)
                    IconButton(
                      onPressed: () => _room.localParticipant?.videoTrackPublications.isNotEmpty == true
                          ? (_room.localParticipant!.videoTrackPublications.first.track)?.setCameraPosition(CameraPosition.back)
                          : null,
                      icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white),
                    ),
                  IconButton(onPressed: _isHost ? _end : () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white)),
                ]),
              ),
              const Spacer(),
              SizedBox(
                height: 220,
                child: Stack(children: [
                  ListView(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(12, 0, 80, 0),
                    children: [
                      for (final c in _comments.reversed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            UserAvatar(imageUrl: (c["user"] as Map?)?["profileImage"]?.toString(), name: (c["user"] as Map?)?["name"]?.toString(), radius: 12),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(14)),
                                child: Text.rich(
                                  TextSpan(children: [
                                    TextSpan(text: "${(c["user"] as Map?)?["name"] ?? ""}  ", style: const TextStyle(fontWeight: FontWeight.w800)),
                                    TextSpan(text: c["text"].toString()),
                                  ]),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ]),
                        ),
                    ],
                  ),
                  for (final h in _flying) _FlyingHeart(key: h.key, scale: h.scale, color: h.color),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(hintText: tr("Say something…"), hintStyle: const TextStyle(color: Colors.white60), fillColor: Colors.white12),
                      onSubmitted: (_) => _sendComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => SocketService.instance.emit("live:heart", {"id": _id}),
                    icon: const Icon(Icons.favorite_rounded, color: Color(0xFFE8384F), size: 32),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  void _sendComment() {
    final t = _input.text.trim();
    if (t.isEmpty || _id == null) return;
    SocketService.instance.emit("live:comment", {"id": _id, "text": t});
    _input.clear();
  }
}

class _Heart {
  final Key key;
  final double scale;
  final Color color;
  _Heart(this.key, this.scale, this.color);
}

class _FlyingHeart extends StatefulWidget {
  final double scale;
  final Color color;
  const _FlyingHeart({super.key, required this.scale, required this.color});

  @override
  State<_FlyingHeart> createState() => _FlyingHeartState();
}

class _FlyingHeartState extends State<_FlyingHeart> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..forward();
  final double _drift = Random().nextDouble() * 40 - 20;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Positioned(
          right: 24 + _drift * _c.value,
          bottom: 10 + 200 * _c.value,
          child: Opacity(
            opacity: (1 - _c.value).clamp(0, 1),
            child: Transform.scale(scale: widget.scale * (0.6 + _c.value * 0.6), child: Icon(Icons.favorite_rounded, color: widget.color, size: 34)),
          ),
        ),
      );
}
