import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/theme/app_colors.dart';

String formatDuration(Duration d) {
  final m = d.inMinutes.remainder(60).toString();
  final s = d.inSeconds.remainder(60).toString().padLeft(2, "0");
  return "$m:$s";
}

/// Playable voice-note bubble content. Loads the audio only when first played.
class VoiceNotePlayer extends StatefulWidget {
  final String url;
  final int durationSec;
  final bool mine;
  const VoiceNotePlayer({super.key, required this.url, required this.durationSec, required this.mine});

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  final _player = AudioPlayer();
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _posSub;
  bool _loaded = false;
  bool _loading = false;
  bool _playing = false;
  Duration _pos = Duration.zero;
  Duration? _total;

  @override
  void initState() {
    super.initState();
    _stateSub = _player.playerStateStream.listen((s) {
      if (!mounted) return;
      if (s.processingState == ProcessingState.completed) {
        _player.pause();
        _player.seek(Duration.zero);
      }
      setState(() => _playing = s.playing && s.processingState != ProcessingState.completed);
    });
    _posSub = _player.positionStream.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      return;
    }
    if (!_loaded) {
      setState(() => _loading = true);
      try {
        _total = await _player.setUrl(widget.url);
        _loaded = true;
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't play this voice note")));
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
      if (!_loaded) return;
    }
    await _player.play();
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.mine ? Colors.white : AppColors.ink;
    final total = _total ?? Duration(seconds: widget.durationSec);
    final progress = total.inMilliseconds == 0 ? 0.0 : (_pos.inMilliseconds / total.inMilliseconds).clamp(0, 1).toDouble();
    return SizedBox(
      width: 210,
      child: Row(children: [
        InkWell(
          onTap: _loading ? null : _toggle,
          customBorder: const CircleBorder(),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.mine ? Colors.white.withValues(alpha: 0.22) : AppColors.primary.withValues(alpha: 0.12),
            ),
            child: _loading
                ? Padding(padding: const EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                : Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: widget.mine ? Colors.white : AppColors.primary),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            _Waveform(progress: progress, color: fg, seed: widget.url.hashCode),
            const SizedBox(height: 4),
            Text(
              formatDuration(_playing || _pos > Duration.zero ? _pos : total),
              style: TextStyle(color: fg.withValues(alpha: 0.75), fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Static waveform bars, filled up to [progress]. Stable per note via [seed].
class _Waveform extends StatelessWidget {
  final double progress;
  final Color color;
  final int seed;
  const _Waveform({required this.progress, required this.color, required this.seed});

  @override
  Widget build(BuildContext context) {
    const bars = 26;
    return SizedBox(
      height: 22,
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        for (var i = 0; i < bars; i++)
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              height: 5 + ((seed >> (i % 16)) & 7) * 2.2 + (i % 3 == 0 ? 3 : 0),
              decoration: BoxDecoration(
                color: (i / bars) <= progress ? color : color.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Records a voice note to a temp file. Call [start], then [stop] or [cancel].
class VoiceRecorder {
  final _rec = AudioRecorder();
  DateTime? _startedAt;
  String? _path;

  Future<bool> start() async {
    if (!await _rec.hasPermission()) return false;
    final dir = await getTemporaryDirectory();
    _path = "${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a";
    await _rec.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100), path: _path!);
    _startedAt = DateTime.now();
    return true;
  }

  Duration get elapsed => _startedAt == null ? Duration.zero : DateTime.now().difference(_startedAt!);

  /// Returns the file and its length, or null if it was too short to keep.
  Future<({File file, int seconds})?> stop() async {
    final path = await _rec.stop();
    final secs = elapsed.inMilliseconds / 1000;
    _startedAt = null;
    if (path == null || secs < 0.8) return null;
    return (file: File(path), seconds: secs.ceil());
  }

  Future<void> cancel() async {
    await _rec.cancel();
    _startedAt = null;
  }

  void dispose() => _rec.dispose();
}
