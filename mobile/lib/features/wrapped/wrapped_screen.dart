import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config/app_config.dart';
import '../../core/i18n/app_locale.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/friendly_error.dart';
import '../post/domain/eco_activity.dart';

typedef Json = Map<String, dynamic>;

const _months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

/// The current Wrapped year: last year during January, otherwise this year.
int wrappedYear([DateTime? now]) {
  final n = now ?? DateTime.now();
  return n.month == 1 ? n.year - 1 : n.year;
}

/// Green Wrapped is promoted on Home in December and January.
bool wrappedSeason([DateTime? now]) {
  final m = (now ?? DateTime.now()).month;
  return m == 12 || m == 1;
}

/// Green Wrapped: the member's year as full-screen story slides, ending in a shareable card.
class WrappedScreen extends StatefulWidget {
  final int? year;
  const WrappedScreen({super.key, this.year});

  @override
  State<WrappedScreen> createState() => _WrappedScreenState();
}

class _WrappedScreenState extends State<WrappedScreen> with SingleTickerProviderStateMixin {
  static const _slideTime = Duration(seconds: 6);

  Json? _w;
  String? _error;
  int _index = 0;
  late final AnimationController _progress = AnimationController(vsync: this, duration: _slideTime)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _next();
    });
  final _cardKey = GlobalKey();
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ApiService.dio.get("/wrapped", queryParameters: {"year": widget.year ?? wrappedYear()});
      await EcoActivityApi.load();
      if (!mounted) return;
      setState(() => _w = Json.from(r.data["wrapped"] as Map));
      _progress.forward(from: 0);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  List<Widget Function()> get _slides {
    final w = _w!;
    if (w["empty"] == true) return [() => _EmptySlide(year: w["year"] as int)];
    return [
      () => _IntroSlide(w: w),
      () => _ActionsSlide(w: w),
      () => _Co2Slide(w: w),
      if (w["topActivity"] != null) () => _PersonaSlide(w: w),
      if ((w["longestStreak"] ?? 0) > 0) () => _StreakSlide(w: w),
      if (w["rank"] != null) () => _RankSlide(w: w),
      if ((w["likesReceived"] ?? 0) > 0 || (w["friendsTagged"] ?? 0) > 0) () => _LoveSlide(w: w),
      () => _SummarySlide(w: w, cardKey: _cardKey, sharing: _sharing, onShare: _share),
    ];
  }

  bool get _onLast => _w != null && _index == _slides.length - 1;

  void _next() {
    if (_w == null) return;
    if (_index < _slides.length - 1) {
      setState(() => _index++);
      if (_onLast) {
        _progress.value = 1; // the summary waits for the member
      } else {
        _progress.forward(from: 0);
      }
    }
  }

  void _back() {
    if (_index > 0) {
      setState(() => _index--);
      _progress.forward(from: 0);
    }
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final boundary = _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await boundary.toImage(pixelRatio: 3);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final f = File("${dir.path}/greenifyx-wrapped-${_w!["year"]}.png");
      await f.writeAsBytes(bytes!.buffer.asUint8List());
      await SharePlus.instance.share(ShareParams(
        files: [XFile(f.path)],
        text: "${tr("My year in green on GreenifyX")} 🌱 ${_w!["co2Kg"]} kg CO₂ ${tr("saved")}.\n${tr("Join me")}: ${AppConfig.publicSiteUrl}",
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_w == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0E3B2E),
        appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
        body: Center(
          child: _error == null
              ? const CircularProgressIndicator(color: Colors.white)
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: () => setState(() { _error = null; _load(); }), child: Text(tr("Try again"))),
                  ]),
                ),
        ),
      );
    }
    final slides = _slides;
    final i = _index.clamp(0, slides.length - 1);
    final palette = _palettes[i % _palettes.length];
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          if (_onLast) return;
          final w = MediaQuery.sizeOf(context).width;
          final leftSide = d.localPosition.dx < w / 3;
          (AppLocale.isArabic ? !leftSide : leftSide) ? _back() : _next();
        },
        onLongPressStart: (_) => _progress.stop(),
        onLongPressEnd: (_) {
          if (!_onLast) _progress.forward();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: palette)),
          child: SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(children: [
                  for (var s = 0; s < slides.length; s++)
                    Expanded(
                      child: Container(
                        height: 3.5,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
                        child: AnimatedBuilder(
                          animation: _progress,
                          builder: (_, _) => FractionallySizedBox(
                            alignment: AlignmentDirectional.centerStart,
                            widthFactor: s < i ? 1 : (s == i ? _progress.value : 0),
                            child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
              Row(children: [
                const SizedBox(width: 16),
                Text("GreenifyX ${tr("Wrapped")}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white)),
              ]),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(a), child: child),
                  ),
                  child: KeyedSubtree(key: ValueKey(i), child: slides[i]()),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

const _palettes = [
  [Color(0xFF0E3B2E), Color(0xFF1F8A70)],
  [Color(0xFFE36A4A), Color(0xFFF2B544)],
  [Color(0xFF11998E), Color(0xFF38EF7D)],
  [Color(0xFF2B2440), Color(0xFF7F53AC)],
  [Color(0xFFC2413B), Color(0xFFFF8A65)],
  [Color(0xFF0083B0), Color(0xFF00B4DB)],
  [Color(0xFFE8384F), Color(0xFFFF7EB3)],
  [Color(0xFF0E3B2E), Color(0xFF2B2440)],
];

// ---------- building blocks ----------

class _Count extends StatelessWidget {
  final num value;
  final String suffix;
  final double size;
  const _Count(this.value, {this.suffix = "", this.size = 72});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.toDouble()),
        duration: const Duration(milliseconds: 1400),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) {
          final shown = value is int || value == value.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
          return Text("$shown$suffix",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: size, fontWeight: FontWeight.w900, height: 1, letterSpacing: -1.5));
        },
      );
}

class _Slide extends StatelessWidget {
  final String? emoji;
  final String kicker;
  final List<Widget> children;
  const _Slide({this.emoji, required this.kicker, required this.children});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (emoji != null) ...[
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.4, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (_, s, child) => Transform.scale(scale: s, child: child),
              child: Text(emoji!, style: const TextStyle(fontSize: 64)),
            ),
            const SizedBox(height: 18),
          ],
          Text(kicker.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, letterSpacing: 1.6, fontSize: 13)),
          const SizedBox(height: 14),
          ...children,
        ]),
      );
}

Text _line(String s, {double size = 18, FontWeight weight = FontWeight.w600}) =>
    Text(s, textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: size, fontWeight: weight, height: 1.35));

// ---------- slides ----------

class _EmptySlide extends StatelessWidget {
  final int year;
  const _EmptySlide({required this.year});
  @override
  Widget build(BuildContext context) => _Slide(emoji: "🌱", kicker: "$year", children: [
        _line(tr("Your year in green starts with one action."), size: 24, weight: FontWeight.w800),
        const SizedBox(height: 12),
        _line(tr("Post a verified eco action and your Wrapped will fill up here."), size: 15),
        const SizedBox(height: 24),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF0E3B2E)),
          onPressed: () => Navigator.pop(context),
          child: Text(tr("Let's go")),
        ),
      ]);
}

class _IntroSlide extends StatelessWidget {
  final Json w;
  const _IntroSlide({required this.w});
  @override
  Widget build(BuildContext context) {
    final first = (w["name"] ?? "").toString().trim().split(" ").first;
    return _Slide(emoji: "🌍", kicker: w["isFinal"] == true ? "${w["year"]}" : "${w["year"]} ${tr("so far")}", children: [
      _line(first.isEmpty ? tr("Your year in green") : "$first, ${tr("this was your year in green")}", size: 30, weight: FontWeight.w900),
      const SizedBox(height: 16),
      _line(tr("Tap to see what you did for the planet."), size: 15),
    ]);
  }
}

class _ActionsSlide extends StatelessWidget {
  final Json w;
  const _ActionsSlide({required this.w});
  @override
  Widget build(BuildContext context) => _Slide(emoji: "✅", kicker: tr("Verified actions"), children: [
        _Count(w["verifiedActions"] as num),
        const SizedBox(height: 14),
        _line("${tr("real actions, checked by your community")}${(w["activeDays"] ?? 0) > 0 ? " · ${w["activeDays"]} ${tr("active days")}" : ""}"),
        const SizedBox(height: 28),
        _Count(w["pointsEarned"] as num, size: 44),
        const SizedBox(height: 6),
        _line(tr("Eco Points earned")),
      ]);
}

class _Co2Slide extends StatelessWidget {
  final Json w;
  const _Co2Slide({required this.w});
  @override
  Widget build(BuildContext context) {
    final eq = Json.from(w["equivalents"] as Map);
    return _Slide(emoji: "🌬️", kicker: tr("CO₂ saved"), children: [
      _Count(w["co2Kg"] as num, suffix: " kg"),
      const SizedBox(height: 18),
      if ((eq["carKm"] ?? 0) > 0) _line("🚗 ${tr("Like not driving")} ${eq["carKm"]} km"),
      if ((eq["treeYears"] ?? 0) > 0) ...[const SizedBox(height: 6), _line("🌳 ${tr("What")} ${eq["treeYears"]} ${tr("trees absorb in a year")}")],
      if ((w["treesPlanted"] ?? 0) > 0) ...[const SizedBox(height: 6), _line("🌱 ${w["treesPlanted"]} ${tr("trees planted")}")],
      if ((w["wasteKg"] ?? 0) > 0) ...[const SizedBox(height: 6), _line("♻️ ${w["wasteKg"]} kg ${tr("waste kept out of landfill")}")],
      const SizedBox(height: 18),
      Text(tr("Indicative estimates, not certified measurement."), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 11.5)),
    ]);
  }
}

class _PersonaSlide extends StatelessWidget {
  final Json w;
  const _PersonaSlide({required this.w});
  @override
  Widget build(BuildContext context) {
    final p = Json.from(w["persona"] as Map);
    final top = Json.from(w["topActivity"] as Map);
    return _Slide(emoji: p["emoji"]?.toString(), kicker: tr("Your eco personality"), children: [
      _line(tr(p["title"].toString()), size: 32, weight: FontWeight.w900),
      const SizedBox(height: 10),
      _line(tr(p["line"].toString()), size: 16),
      const SizedBox(height: 26),
      _line("${tr("Top action")}: ${activityName(top["name"].toString())} × ${top["count"]}", size: 17, weight: FontWeight.w800),
      for (final a in (w["topActivities"] as List? ?? []).skip(1))
        Padding(padding: const EdgeInsets.only(top: 6), child: _line("${activityName((a as Map)["name"].toString())} × ${a["count"]}", size: 14)),
    ]);
  }
}

class _StreakSlide extends StatelessWidget {
  final Json w;
  const _StreakSlide({required this.w});
  @override
  Widget build(BuildContext context) {
    final m = w["busiestMonth"] is Map ? Json.from(w["busiestMonth"] as Map) : null;
    return _Slide(emoji: "🔥", kicker: tr("Longest streak"), children: [
      _Count(w["longestStreak"] as num),
      const SizedBox(height: 8),
      _line(tr("days in a row")),
      if (m != null) ...[
        const SizedBox(height: 30),
        _line(tr("Your greenest month"), size: 14),
        const SizedBox(height: 4),
        _line(tr(_months[(m["month"] as num).toInt()]), size: 30, weight: FontWeight.w900),
        _line("${m["count"]} ${tr("verified actions")}", size: 14),
      ],
    ]);
  }
}

class _RankSlide extends StatelessWidget {
  final Json w;
  const _RankSlide({required this.w});
  @override
  Widget build(BuildContext context) {
    final r = Json.from(w["rank"] as Map);
    return _Slide(emoji: "🏆", kicker: "${tr("In")} ${tr(r["emirate"].toString())}", children: [
      _line(tr("You were in the top"), size: 18),
      const SizedBox(height: 8),
      _Count(r["topPercent"] as num, suffix: "%"),
      const SizedBox(height: 12),
      _line("#${r["position"]} ${tr("of")} ${r["total"]} ${tr("members earning Eco Points")}", size: 15),
    ]);
  }
}

class _LoveSlide extends StatelessWidget {
  final Json w;
  const _LoveSlide({required this.w});
  @override
  Widget build(BuildContext context) => _Slide(emoji: "💚", kicker: tr("Your community"), children: [
        if ((w["likesReceived"] ?? 0) > 0) ...[
          _Count(w["likesReceived"] as num, size: 60),
          _line(tr("likes on your posts")),
          const SizedBox(height: 22),
        ],
        if ((w["friendsTagged"] ?? 0) > 0) ...[
          _Count(w["friendsTagged"] as num, size: 44),
          _line(tr("friends brought along")),
        ],
      ]);
}

class _SummarySlide extends StatelessWidget {
  final Json w;
  final GlobalKey cardKey;
  final bool sharing;
  final VoidCallback onShare;
  const _SummarySlide({required this.w, required this.cardKey, required this.sharing, required this.onShare});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
        child: Column(children: [
          Expanded(child: Center(child: RepaintBoundary(key: cardKey, child: WrappedCard(w: w)))),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF0E3B2E), padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: sharing ? null : onShare,
              icon: const Icon(Icons.ios_share_rounded),
              label: Text(tr("Share my year")),
            ),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr("Done"), style: const TextStyle(color: Colors.white))),
        ]),
      );
}

/// The shareable summary card (9:16-ish so it fits Instagram and TikTok stories).
class WrappedCard extends StatelessWidget {
  final Json w;
  const WrappedCard({super.key, required this.w});

  @override
  Widget build(BuildContext context) {
    final p = Json.from(w["persona"] as Map);
    final r = w["rank"] is Map ? Json.from(w["rank"] as Map) : null;
    Widget stat(String v, String l) => Expanded(
          child: Column(children: [
            Text(v, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
            Text(l, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
          ]),
        );
    return AspectRatio(
      aspectRatio: 9 / 14,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0E3B2E), Color(0xFF1F8A70), Color(0xFFF2B544)]),
          boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 30, offset: Offset(0, 12))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset("assets/brand/app_icon_rounded.png", width: 28, height: 28)),
            const SizedBox(width: 8),
            Text("GreenifyX ${tr("Wrapped")} ${w["year"]}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ]),
          const Spacer(),
          Text(w["name"]?.toString() ?? "", style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text("${p["emoji"]} ${tr(p["title"].toString())}", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, height: 1.15)),
          const SizedBox(height: 18),
          Text("${w["co2Kg"]} kg", style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w900, height: 1, letterSpacing: -1.5)),
          Text(tr("CO₂ saved"), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          Row(children: [
            stat("${w["verifiedActions"]}", tr("actions")),
            stat("${w["pointsEarned"]}", tr("Eco Points")),
            stat("${w["longestStreak"]}", tr("day streak")),
          ]),
          const Spacer(),
          if (r != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(30)),
              child: Text("🏆 ${tr("Top")} ${r["topPercent"]}% ${tr("in")} ${tr(r["emirate"].toString())}",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
        ]),
      ),
    );
  }
}

/// Home banner shown in Wrapped season.
class WrappedBanner extends StatelessWidget {
  const WrappedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!wrappedSeason()) return const SizedBox.shrink();
    final year = wrappedYear();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Material(
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WrappedScreen(year: year))),
          child: Ink(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0E3B2E), Color(0xFF1F8A70), Color(0xFFF2B544)])),
            child: Row(children: [
              const Text("🎁", style: TextStyle(fontSize: 34)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("${tr("Your")} $year ${tr("Wrapped is here")}", style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(tr("See your year in green and share it"), style: const TextStyle(color: Colors.white70)),
                ]),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
            ]),
          ),
        ),
      ),
    );
  }
}
