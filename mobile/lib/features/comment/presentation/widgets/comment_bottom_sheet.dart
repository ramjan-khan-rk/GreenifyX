import 'package:flutter/material.dart';

import '../../../../core/i18n/app_locale.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/session_user.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/friendly_error.dart';
import '../../../../core/widgets/rich_caption.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/widgets/verified_tick.dart';

typedef _CJson = Map<String, dynamic>;
List<_CJson> _maps(dynamic v) => (v as List? ?? const []).map((e) => _CJson.from(e as Map)).toList();

String _ago(String? iso) {
  final t = DateTime.tryParse(iso ?? "")?.toLocal();
  if (t == null) return "";
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return tr("now");
  if (d.inMinutes < 60) return "${d.inMinutes}m";
  if (d.inHours < 24) return "${d.inHours}h";
  return "${d.inDays}d";
}

/// Comments: replies, emoji reactions, pinned comment, @mentions.
class CommentBottomSheet extends StatefulWidget {
  final String postId;
  const CommentBottomSheet({super.key, required this.postId});

  @override
  State<CommentBottomSheet> createState() => _CommentBottomSheetState();
}

class _CommentBottomSheetState extends State<CommentBottomSheet> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  List<_CJson>? _comments;
  List<String> _reactions = const ["🌱", "💪", "❤️", "👏", "😂", "😮"];
  bool _canPin = false;
  _CJson? _replyTo;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ApiService.dio.get("/comments/${widget.postId}");
      if (!mounted) return;
      setState(() {
        _comments = _maps(r.data["comments"]);
        _reactions = (r.data["reactions"] as List? ?? _reactions).map((e) => e.toString()).toList();
        _canPin = r.data["canPin"] == true;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ApiService.dio.post("/comments/${widget.postId}", data: {"text": text, if (_replyTo != null) "parentId": _replyTo!["_id"]});
      _input.clear();
      setState(() => _replyTo = null);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _react(_CJson c, String emoji) async {
    try {
      await ApiService.dio.post("/comments/react/${c["_id"]}", data: {"emoji": emoji});
      _load();
    } catch (_) {}
  }

  Future<void> _more(_CJson c) async {
    final mine = (c["user"] as Map?)?["_id"] == SessionUser.id;
    final v = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              for (final e in _reactions) InkWell(onTap: () => Navigator.pop(ctx, "react:$e"), child: Padding(padding: const EdgeInsets.all(6), child: Text(e, style: const TextStyle(fontSize: 30)))),
            ]),
          ),
          ListTile(leading: const Icon(Icons.reply_rounded), title: Text(tr("Reply")), onTap: () => Navigator.pop(ctx, "reply")),
          if (_canPin && c["parent"] == null)
            ListTile(leading: const Icon(Icons.push_pin_rounded), title: Text(c["pinned"] == true ? tr("Unpin") : tr("Pin comment")), onTap: () => Navigator.pop(ctx, "pin")),
          if (mine || _canPin)
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: Text(tr("Delete"), style: const TextStyle(color: AppColors.error)),
              onTap: () => Navigator.pop(ctx, "delete"),
            ),
        ]),
      ),
    );
    if (v == null) return;
    try {
      if (v.startsWith("react:")) {
        await _react(c, v.substring(6));
      } else if (v == "reply") {
        _startReply(c);
      } else if (v == "pin") {
        await ApiService.dio.put("/comments/pin/${c["_id"]}");
        _load();
      } else if (v == "delete") {
        await ApiService.dio.delete("/comments/item/${c["_id"]}");
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  void _startReply(_CJson c) {
    final name = ((c["user"] as Map?)?["name"] ?? "").toString().split(" ").first;
    setState(() => _replyTo = c);
    _input.text = "@$name ";
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
    _focus.requestFocus();
  }

  Widget _comment(_CJson c, {bool reply = false}) {
    final u = _CJson.from((c["user"] ?? {}) as Map);
    final reactions = _CJson.from((c["reactions"] ?? {}) as Map);
    return Padding(
      padding: EdgeInsetsDirectional.only(start: reply ? 52 : 16, end: 16, top: 10),
      child: GestureDetector(
        onLongPress: () => _more(c),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          UserAvatar(imageUrl: u["profileImage"]?.toString(), name: u["name"]?.toString(), radius: reply ? 14 : 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(u["name"]?.toString() ?? "", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5))),
                VerifiedTick(u["verifiedBadge"]?.toString() ?? "", size: 14),
                const SizedBox(width: 6),
                Text(_ago(c["createdAt"]?.toString()), style: TextStyle(color: AppColors.subtitle, fontSize: 12)),
                if (c["pinned"] == true) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.push_pin_rounded, size: 13, color: AppColors.joy),
                  Text(tr("Pinned"), style: const TextStyle(color: AppColors.joy, fontSize: 11.5, fontWeight: FontWeight.w700)),
                ],
              ]),
              const SizedBox(height: 2),
              RichCaption(c["text"]?.toString() ?? "", style: TextStyle(fontSize: 14.5, height: 1.35, color: AppColors.ink)),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                for (final e in reactions.entries)
                  if (((e.value as Map)["count"] as num? ?? 0) > 0)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _react(c, e.key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: (e.value as Map)["mine"] == true ? AppColors.blush : const Color(0xFFF3EEE9),
                          borderRadius: BorderRadius.circular(12),
                          border: (e.value as Map)["mine"] == true ? Border.all(color: AppColors.joy) : null,
                        ),
                        child: Text("${e.key} ${(e.value as Map)["count"]}", style: const TextStyle(fontSize: 12.5)),
                      ),
                    ),
                InkWell(onTap: () => _startReply(c), child: Text(tr("Reply"), style: TextStyle(color: AppColors.subtitle, fontWeight: FontWeight.w700, fontSize: 12.5))),
                InkWell(onTap: () => _more(c), child: Icon(Icons.add_reaction_outlined, size: 17, color: AppColors.subtitle)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _comments;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .78,
          child: Column(children: [
            const SizedBox(height: 4),
            Text(tr("Comments"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const Divider(),
            Expanded(
              child: list == null
                  ? Center(child: _error != null ? TextButton(onPressed: _load, child: Text(_error!)) : const CircularProgressIndicator())
                  : list.isEmpty
                      ? Center(child: Text(tr("No comments yet"), style: TextStyle(color: AppColors.subtitle)))
                      : ListView(padding: const EdgeInsets.only(bottom: 12), children: [
                          for (final c in list) ...[
                            _comment(c),
                            for (final r in _maps(c["replies"])) _comment(r, reply: true),
                          ],
                        ]),
            ),
            if (_replyTo != null)
              Container(
                color: AppColors.background,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(children: [
                  Expanded(child: Text("${tr("Replying to")} ${(_replyTo!["user"] as Map?)?["name"] ?? ""}", style: TextStyle(color: AppColors.subtitle))),
                  IconButton(visualDensity: VisualDensity.compact, onPressed: () => setState(() => _replyTo = null), icon: const Icon(Icons.close_rounded, size: 18)),
                ]),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: Row(children: [
                UserAvatar(imageUrl: SessionUser.profileImage, name: SessionUser.name, radius: 17),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _input,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(hintText: tr("Add a comment… use @ to mention"), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                  ),
                ),
                IconButton(
                  onPressed: _sending ? null : _send,
                  icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded, color: AppColors.joy),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
