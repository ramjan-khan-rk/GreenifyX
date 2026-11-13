import 'package:flutter/material.dart';

import '../../core/i18n/app_locale.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/friendly_error.dart';

typedef Json = Map<String, dynamic>;

/// Eco Academy: a 60-second lesson a day with a 3-question quiz.
class AcademyScreen extends StatefulWidget {
  const AcademyScreen({super.key});

  @override
  State<AcademyScreen> createState() => _AcademyScreenState();
}

class _AcademyScreenState extends State<AcademyScreen> {
  Json? _d;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ApiService.dio.get("/academy");
      if (mounted) setState(() => _d = Json.from(r.data as Map));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _open(String id) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => LessonScreen(id: id)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final today = Json.from(d?["today"] as Map? ?? const {});
    final library = (d?["library"] as List? ?? []).map((e) => Json.from(e as Map)).toList();
    return Scaffold(
      appBar: AppBar(title: Text(tr("Eco Academy"))),
      body: d == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
                Row(children: [
                  _Stat("🔥", "${d["streak"]}", tr("day streak")),
                  const SizedBox(width: 10),
                  _Stat("🎓", "${d["passed"]}/${d["total"]}", tr("lessons passed")),
                ]),
                const SizedBox(height: 14),
                Material(
                  borderRadius: BorderRadius.circular(24),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _open(today["id"].toString()),
                    child: Ink(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF7F53AC), Color(0xFF647DEE)])),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tr("TODAY'S LESSON · 60 SECONDS"), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 12)),
                        const SizedBox(height: 10),
                        Text("${today["emoji"]}  ${tr(today["title"].toString())}", style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        Text(
                          today["passed"] == true ? "✅ ${tr("Done today. Come back tomorrow for a new one!")}" : "${tr("Pass the quiz for")} +${d["points"]} ${tr("Eco Points")}",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(tr("All lessons"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                for (final l in library)
                  Card(
                    child: ListTile(
                      leading: Text(l["emoji"].toString(), style: const TextStyle(fontSize: 26)),
                      title: Text(tr(l["title"].toString()), style: const TextStyle(fontWeight: FontWeight.w700)),
                      trailing: l["passed"] == true
                          ? const Icon(Icons.check_circle_rounded, color: AppColors.eco)
                          : (l["score"] != null ? Text("${l["score"]}/3", style: TextStyle(color: AppColors.subtitle)) : const Icon(Icons.chevron_right_rounded)),
                      onTap: () => _open(l["id"].toString()),
                    ),
                  ),
              ]),
            ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  const _Stat(this.emoji, this.value, this.label);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              Text(label, style: TextStyle(color: AppColors.subtitle, fontSize: 12)),
            ]),
          ]),
        ),
      );
}

/// Three swipeable lesson cards, then the quiz.
class LessonScreen extends StatefulWidget {
  final String id;
  const LessonScreen({super.key, required this.id});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  Json? _l;
  final _pages = PageController();
  int _page = 0;
  final Map<int, int> _answers = {};
  Json? _result;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    ApiService.dio.get("/academy/${widget.id}").then((r) {
      if (mounted) setState(() => _l = Json.from(r.data["lesson"] as Map));
    }).catchError((Object e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      final quiz = _l!["quiz"] as List;
      final r = await ApiService.dio.post("/academy/${widget.id}/answers", data: {
        "answers": [for (var i = 0; i < quiz.length; i++) _answers[i] ?? -1],
      });
      if (mounted) setState(() => _result = Json.from(r.data as Map));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _l;
    if (l == null) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    final cards = (l["cards"] as List).map((e) => e.toString()).toList();
    final quiz = (l["quiz"] as List).map((e) => Json.from(e as Map)).toList();
    final pageCount = cards.length + 1;
    return Scaffold(
      appBar: AppBar(title: Text("${l["emoji"]} ${tr(l["title"].toString())}")),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(children: [
            for (var i = 0; i < pageCount; i++)
              Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(color: i <= _page ? const Color(0xFF7F53AC) : AppColors.border, borderRadius: BorderRadius.circular(4)),
                ),
              ),
          ]),
        ),
        Expanded(
          child: PageView(
            controller: _pages,
            onPageChanged: (p) => setState(() => _page = p),
            children: [
              for (var i = 0; i < cards.length; i++)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(l["emoji"].toString(), style: const TextStyle(fontSize: 56)),
                    const SizedBox(height: 20),
                    Text(tr(cards[i]), textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, height: 1.45, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 30),
                    FilledButton(
                      onPressed: () => _pages.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                      child: Text(i == cards.length - 1 ? tr("Take the quiz") : tr("Next")),
                    ),
                  ]),
                ),
              ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
                for (var i = 0; i < quiz.length; i++) ...[
                  Text("${i + 1}. ${tr(quiz[i]["q"].toString())}", style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  for (var o = 0; o < (quiz[i]["options"] as List).length; o++)
                    _Option(
                      label: tr((quiz[i]["options"] as List)[o].toString()),
                      selected: _answers[i] == o,
                      state: _result == null
                          ? null
                          : ((_result!["results"] as List)[i]["answer"] == o ? true : (_answers[i] == o ? false : null)),
                      onTap: _result != null ? null : () => setState(() => _answers[i] = o),
                    ),
                  if (_result != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 6),
                      child: Text("💡 ${tr(((_result!["results"] as List)[i] as Map)["why"].toString())}", style: TextStyle(color: AppColors.subtitle)),
                    ),
                  const SizedBox(height: 14),
                ],
                if (_result == null)
                  FilledButton(onPressed: _sending || _answers.length < quiz.length ? null : _submit, child: Text(tr("Check answers")))
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: _result!["passed"] == true ? AppColors.eco.withValues(alpha: 0.12) : AppColors.surfaceAlt, borderRadius: BorderRadius.circular(18)),
                    child: Column(children: [
                      Text("${_result!["score"]}/3", style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                      Text(
                        _result!["passed"] == true
                            ? ((_result!["earned"] ?? 0) > 0 ? "${tr("Passed!")} +${_result!["earned"]} ${tr("Eco Points")} 🎉" : tr("Passed! You already earned points for this one."))
                            : tr("So close. Read the tips and try again."),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      if (_result!["passed"] != true)
                        OutlinedButton(onPressed: () => setState(() { _result = null; _answers.clear(); }), child: Text(tr("Try again")))
                      else
                        FilledButton(onPressed: () => Navigator.pop(context), child: Text(tr("Done"))),
                    ]),
                  ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

class _Option extends StatelessWidget {
  final String label;
  final bool selected;
  final bool? state; // true = correct answer, false = your wrong pick
  final VoidCallback? onTap;
  const _Option({required this.label, required this.selected, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = state == true ? AppColors.eco : (state == false ? AppColors.error : (selected ? const Color(0xFF7F53AC) : AppColors.border));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color, width: selected || state != null ? 2 : 1),
            color: color.withValues(alpha: selected || state != null ? 0.08 : 0),
          ),
          child: Row(children: [
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
            if (state == true) const Icon(Icons.check_circle_rounded, color: AppColors.eco),
            if (state == false) const Icon(Icons.cancel_rounded, color: AppColors.error),
          ]),
        ),
      ),
    );
  }
}
