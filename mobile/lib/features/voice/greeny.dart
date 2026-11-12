import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/i18n/app_locale.dart';
import '../../core/routes/app_router.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import 'greeny_actions.dart';

typedef Json = Map<String, dynamic>;

/// "Hey Greeny" — the in-app voice assistant.
/// Tap the Greeny button, or turn on hands-free to say "Hey Greeny …" while the app is open.
class Greeny {
  Greeny._();
  static final instance = Greeny._();

  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool _sheetOpen = false;
  bool _loopRunning = false;
  final ValueNotifier<bool> handsFree = ValueNotifier(false);
  final ValueNotifier<bool> wakeListening = ValueNotifier(false);

  static const _prefKey = "greeny_hands_free";
  static final _wake = RegExp(r"\b(hey|hi|ok|okay)?\s*(greeny|greenie|greeni|green e|greenee|grini)\b|غريني|جريني", caseSensitive: false);

  String get _locale => AppLocale.isArabic ? "ar_AE" : "en_US";

  Future<bool> init() async {
    if (_ready) return true;
    try {
      _ready = await _stt.initialize(onError: (_) => _restartLoopSoon(), onStatus: (s) {
        if ((s == "done" || s == "notListening") && handsFree.value && !_sheetOpen) _restartLoopSoon();
      });
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.05);
    } catch (_) {
      _ready = false;
    }
    return _ready;
  }

  Future<void> loadPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      handsFree.value = p.getBool(_prefKey) ?? false;
      if (handsFree.value) _startWakeLoop();
    } catch (_) {}
  }

  Future<void> setHandsFree(bool v) async {
    handsFree.value = v;
    try {
      (await SharedPreferences.getInstance()).setBool(_prefKey, v);
    } catch (_) {}
    if (v) {
      _startWakeLoop();
    } else {
      wakeListening.value = false;
      await _stt.stop();
    }
  }

  Future<void> speak(String text) async {
    try {
      await _tts.setLanguage(AppLocale.isArabic ? "ar" : "en-US");
      await _tts.speak(text);
    } catch (_) {}
  }

  // ---- Hands-free wake word (foreground only) ----
  void _restartLoopSoon() {
    if (!handsFree.value || _sheetOpen) return;
    Future.delayed(const Duration(milliseconds: 700), _startWakeLoop);
  }

  Future<void> _startWakeLoop() async {
    if (_loopRunning || !handsFree.value || _sheetOpen) return;
    if (!await init()) return;
    if (_stt.isListening) return;
    _loopRunning = true;
    wakeListening.value = true;
    try {
      await _stt.listen(
        localeId: _locale,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
        listenOptions: SpeechListenOptions(partialResults: true, cancelOnError: false, listenMode: ListenMode.dictation),
        onResult: (r) {
          final words = r.recognizedWords;
          final m = _wake.firstMatch(words);
          if (m == null) return;
          final rest = words.substring(m.end).trim();
          if (r.finalResult || rest.split(" ").length >= 3) {
            _stt.stop();
            final ctx = AppRouter.router.routerDelegate.navigatorKey.currentContext;
            if (ctx != null) open(ctx, initialCommand: rest.isEmpty ? null : rest);
          }
        },
      );
    } catch (_) {
      _restartLoopSoon();
    } finally {
      _loopRunning = false;
    }
  }

  /// Opens the Greeny sheet. With [initialCommand] it runs right away.
  Future<void> open(BuildContext context, {String? initialCommand}) async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    wakeListening.value = false;
    await _stt.stop();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GreenySheet(initialCommand: initialCommand),
    );
    _sheetOpen = false;
    _restartLoopSoon();
  }

  // ---- One command ----
  Future<void> listenOnce({required void Function(String words, bool done) onWords}) async {
    if (!await init()) {
      onWords("", true);
      return;
    }
    await _stt.listen(
      localeId: _locale,
      listenFor: const Duration(seconds: 12),
      pauseFor: const Duration(milliseconds: 2200),
      listenOptions: SpeechListenOptions(partialResults: true, listenMode: ListenMode.confirmation),
      onResult: (SpeechRecognitionResult r) => onWords(r.recognizedWords, r.finalResult),
    );
  }

  Future<void> stopListening() => _stt.stop();
  bool get isListening => _stt.isListening;

  Future<Json> ask(String text) async {
    final r = await ApiService.dio.post("/assistant/command", data: {"text": text, "lang": AppLocale.isArabic ? "ar" : "en"});
    return Json.from(r.data as Map);
  }
}

/// The listening UI: glowing orb, live transcript, Greeny's reply and suggestions.
class GreenySheet extends StatefulWidget {
  final String? initialCommand;
  const GreenySheet({super.key, this.initialCommand});

  @override
  State<GreenySheet> createState() => _GreenySheetState();
}

class _GreenySheetState extends State<GreenySheet> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  String _heard = "";
  String _reply = "";
  bool _listening = false;
  bool _thinking = false;
  final _type = TextEditingController();

  static const _suggestions = ["Call Sara", "Chat with Ramjan Khan", "Open my rewards", "How many points do I have?", "Take me to the eco map", "Go live"];

  @override
  void initState() {
    super.initState();
    if (widget.initialCommand != null) {
      _heard = widget.initialCommand!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _run(_heard));
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _type.dispose();
    Greeny.instance.stopListening();
    super.dispose();
  }

  Future<void> _listen() async {
    setState(() {
      _listening = true;
      _heard = "";
      _reply = "";
    });
    await Greeny.instance.listenOnce(onWords: (w, done) {
      if (!mounted) return;
      setState(() => _heard = w);
      if (done) {
        setState(() => _listening = false);
        if (w.trim().isNotEmpty) {
          _run(w);
        } else {
          setState(() => _reply = tr("I didn't catch that. Tap the mic and try again."));
        }
      }
    });
  }

  Future<void> _run(String text) async {
    setState(() {
      _thinking = true;
      _heard = text;
    });
    try {
      final res = await Greeny.instance.ask(text);
      if (!mounted) return;
      final reply = res["reply"]?.toString() ?? "";
      setState(() {
        _reply = reply;
        _thinking = false;
      });
      if (reply.isNotEmpty) Greeny.instance.speak(reply);
      final nav = AppRouter.router.routerDelegate.navigatorKey.currentContext;
      if (res["action"] != "say" && nav != null) {
        await Future.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
        Navigator.pop(context);
        if (nav.mounted) await runGreenyAction(nav, res);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _thinking = false;
          _reply = tr("Greeny is offline right now. Try again in a moment.");
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        gradient: LinearGradient(colors: [Color(0xFF0F2A24), Color(0xFF1B1730)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: _listening ? () => Greeny.instance.stopListening() : _listen,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, _) {
                final glow = _listening ? 18 + 22 * _pulse.value : (_thinking ? 12 + 8 * _pulse.value : 8);
                return Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const SweepGradient(colors: [Color(0xFF38EF7D), Color(0xFF11998E), Color(0xFF00B4DB), Color(0xFF7F53AC), Color(0xFF38EF7D)]),
                    boxShadow: [BoxShadow(color: const Color(0xFF38EF7D).withValues(alpha: 0.55), blurRadius: glow.toDouble(), spreadRadius: glow / 4)],
                  ),
                  child: Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF0F2A24)),
                      child: Icon(_listening ? Icons.graphic_eq_rounded : _thinking ? Icons.more_horiz_rounded : Icons.mic_rounded, color: Colors.white, size: 40),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Text("Greeny", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text(
            _heard.isNotEmpty ? "“$_heard”" : (_listening ? tr("Listening…") : tr("Tap the orb and talk")),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.4),
          ),
          if (_reply.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white12)),
              child: Text(_reply, style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w600, height: 1.4)),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
            for (final s in _suggestions)
              ActionChip(
                backgroundColor: Colors.white10,
                side: const BorderSide(color: Colors.white24),
                label: Text(tr(s), style: const TextStyle(color: Colors.white)),
                onPressed: () => _run(s),
              ),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: _type,
            style: const TextStyle(color: Colors.white),
            textInputAction: TextInputAction.send,
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) _run(v.trim());
              _type.clear();
            },
            decoration: InputDecoration(
              hintText: tr("…or type a command"),
              hintStyle: const TextStyle(color: Colors.white38),
              fillColor: Colors.white10,
              prefixIcon: const Icon(Icons.keyboard_rounded, color: Colors.white38),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white12)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.eco)),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Small floating orb that opens Greeny (shown on the main screens).
class GreenyButton extends StatelessWidget {
  const GreenyButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: Greeny.instance.wakeListening,
      builder: (_, listening, _) => GestureDetector(
        onTap: () => Greeny.instance.open(context),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [Color(0xFF38EF7D), Color(0xFF11998E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            boxShadow: [BoxShadow(color: const Color(0xFF11998E).withValues(alpha: listening ? 0.7 : 0.4), blurRadius: listening ? 22 : 12, offset: const Offset(0, 4))],
            border: listening ? Border.all(color: Colors.white, width: 2) : null,
          ),
          child: const Icon(Icons.mic_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
