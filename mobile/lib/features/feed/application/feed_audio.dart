import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Plays one post soundtrack at a time across the feed.
class FeedAudio extends ChangeNotifier {
  FeedAudio._() {
    _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) {
        _player.seek(Duration(seconds: _startSec));
      }
      notifyListeners();
    });
  }

  static final FeedAudio instance = FeedAudio._();

  final _player = AudioPlayer();
  String? _url;
  int _startSec = 0;
  bool loading = false;

  bool isPlaying(String url) => _url == url && _player.playing;
  bool isLoading(String url) => _url == url && loading;

  Future<void> toggle(String url, {int startSec = 0}) async {
    if (_url == url) {
      _player.playing ? await _player.pause() : await _player.play();
      return;
    }
    await play(url, startSec: startSec);
  }

  Future<void> play(String url, {int startSec = 0}) async {
    _url = url;
    _startSec = startSec;
    loading = true;
    notifyListeners();
    try {
      await _player.setUrl(url);
      await _player.setLoopMode(LoopMode.one);
      if (startSec > 0) await _player.seek(Duration(seconds: startSec));
      loading = false;
      notifyListeners();
      await _player.play();
    } catch (_) {
      loading = false;
      _url = null;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _url = null;
    notifyListeners();
  }
}
