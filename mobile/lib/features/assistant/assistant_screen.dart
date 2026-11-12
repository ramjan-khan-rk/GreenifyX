import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/friendly_error.dart';
import 'assistant_api.dart';
import 'assistant_cards.dart';
import 'snap_sort_screen.dart';

const _suggestions = [
  "Campaigns I can join this weekend",
  "Where do I drop old batteries?",
  "How do I recycle a pizza box?",
  "Water refill points near me",
  "How many Eco Points do I have?",
  "What happened to my report?",
];

class AssistantScreen extends StatefulWidget {
  final String? initialQuestion;
  const AssistantScreen({super.key, this.initialQuestion});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _api = AssistantApi();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatTurn> _turns = [];
  bool _thinking = false;
  Position? _here;

  @override
  void initState() {
    super.initState();
    quietPosition().then((p) => _here = p);
    final q = widget.initialQuestion;
    if (q != null && q.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _send(q));
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final q = text.trim();
    if (q.isEmpty || _thinking) return;
    _input.clear();
    setState(() {
      _turns.add(ChatTurn("user", q));
      _thinking = true;
    });
    _toBottom();
    try {
      final reply = await _api.ask(_turns, at: _here);
      if (mounted) setState(() => _turns.add(reply));
    } catch (e) {
      if (mounted) setState(() => _turns.add(ChatTurn("assistant", friendlyError(e, fallback: "I couldn't reach the server. Try again in a moment."))));
    } finally {
      if (mounted) setState(() => _thinking = false);
      _toBottom();
    }
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 200, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.eco, Color(0xFF2A9D8F)]),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Ask GreenifyX", style: AppTextStyles.title.copyWith(fontSize: 18)),
            Text("Answers from live campaigns, places and your activity", style: AppTextStyles.tagline.copyWith(fontSize: 11)),
          ]),
        ]),
        actions: [
          IconButton(
            tooltip: "Snap & Sort",
            icon: const Icon(Icons.camera_alt_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SnapSortScreen())),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: _turns.isEmpty
              ? _Welcome(onPick: _send)
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  itemCount: _turns.length + (_thinking ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i >= _turns.length) return const _Typing();
                    return _Bubble(turn: _turns[i]);
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _send,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: "Ask about campaigns, recycling, your points…",
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.border)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                onPressed: _thinking ? null : () => _send(_input.text),
                style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Welcome extends StatelessWidget {
  final ValueChanged<String> onPick;
  const _Welcome({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(20), children: [
      const SizedBox(height: 12),
      Center(
        child: Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.eco, Color(0xFF2A9D8F)]),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 34),
        ),
      ),
      const SizedBox(height: 16),
      Text("How can I help you go green today?", textAlign: TextAlign.center, style: AppTextStyles.title),
      const SizedBox(height: 6),
      Text(
        "I know the live campaigns, recycling and refill points, and your own points and reports.",
        textAlign: TextAlign.center,
        style: AppTextStyles.subtitle,
      ),
      const SizedBox(height: 22),
      Material(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SnapSortScreen())),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(children: [
              Icon(Icons.camera_alt_rounded, color: AppColors.sun),
              SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("Snap & Sort", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  Text("Point your camera at an item to see where it goes",
                      style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 12.5)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 18),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final s in _suggestions)
          ActionChip(
            label: Text(s),
            backgroundColor: Colors.white,
            side: const BorderSide(color: AppColors.border),
            onPressed: () => onPick(s),
          ),
      ]),
    ]);
  }
}

class _Bubble extends StatelessWidget {
  final ChatTurn turn;
  const _Bubble({required this.turn});

  @override
  Widget build(BuildContext context) {
    final mine = turn.role == "user";
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * (mine ? 0.78 : 0.9)),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: mine ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(mine ? 18 : 4),
                  bottomRight: Radius.circular(mine ? 4 : 18),
                ),
                border: mine ? null : Border.all(color: AppColors.border),
              ),
              child: Text(turn.text, style: TextStyle(color: mine ? Colors.white : AppColors.ink, height: 1.4)),
            ),
            for (final c in turn.cards) AssistantCard(card: c),
          ]),
        ),
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text("Looking that up…", style: TextStyle(color: AppColors.subtitle)),
        ]),
      ),
    );
  }
}
