import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/i18n/app_locale.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/friendly_error.dart';
import '../post/presentation/screens/create_post_screen.dart';

typedef Json = Map<String, dynamic>;

Color _hex(String? h) {
  final v = int.tryParse((h ?? "").replaceFirst("#", ""), radix: 16);
  return v == null ? AppColors.eco : Color(0xFF000000 | v);
}

/// Horizontal strip of brand challenges (Home and For you).
class SponsoredStrip extends StatefulWidget {
  const SponsoredStrip({super.key});

  @override
  State<SponsoredStrip> createState() => _SponsoredStripState();
}

class _SponsoredStripState extends State<SponsoredStrip> {
  List<Json> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ApiService.dio.get("/sponsored");
      if (mounted) setState(() => _items = (r.data["challenges"] as List).map((e) => Json.from(e as Map)).toList());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 158,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final c = _items[i];
          final sp = Json.from(c["sponsor"] as Map);
          final color = _hex(sp["color"]?.toString());
          final p = ((c["myProgress"] as num) / (c["target"] as num)).clamp(0, 1).toDouble();
          return GestureDetector(
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => SponsoredDetailScreen(challenge: c)));
              _load();
            },
            child: Container(
              width: 290,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), color: color),
              child: Stack(fit: StackFit.expand, children: [
                if ((c["coverImage"] ?? "").toString().isNotEmpty)
                  CachedNetworkImage(imageUrl: c["coverImage"].toString(), fit: BoxFit.cover, color: color.withValues(alpha: 0.75), colorBlendMode: BlendMode.multiply),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.surface24, borderRadius: BorderRadius.circular(8)),
                        child: Text(tr("Sponsored"), style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: Text(sp["name"].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))),
                    ]),
                    const Spacer(),
                    Text(c["title"].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                    Text("+${c["rewardPoints"]} ${tr("Eco Points")}${(c["prize"] ?? "").toString().isEmpty ? "" : " · ${c["prize"]}"}",
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5)),
                    const SizedBox(height: 8),
                    if (c["joined"] == true)
                      ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: p, minHeight: 7, color: Colors.white, backgroundColor: Colors.white24))
                    else
                      Text("${c["participants"]} ${tr("joined")} · ${tr("Tap to join")}", style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class SponsoredDetailScreen extends StatefulWidget {
  final Json challenge;
  const SponsoredDetailScreen({super.key, required this.challenge});

  @override
  State<SponsoredDetailScreen> createState() => _SponsoredDetailScreenState();
}

class _SponsoredDetailScreenState extends State<SponsoredDetailScreen> {
  late Json _c = widget.challenge;
  bool _busy = false;

  Future<void> _join() async {
    setState(() => _busy = true);
    try {
      final r = await ApiService.dio.post("/sponsored/${_c["_id"]}/join");
      setState(() => _c = Json.from(r.data["challenge"] as Map));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sp = Json.from(_c["sponsor"] as Map);
    final color = _hex(sp["color"]?.toString());
    final target = (_c["target"] as num).toInt();
    final mine = (_c["myProgress"] as num).toInt();
    final ends = DateTime.tryParse(_c["endsAt"].toString())?.toLocal();
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 230,
          backgroundColor: color,
          foregroundColor: Colors.white,
          flexibleSpace: FlexibleSpaceBar(
            background: (_c["coverImage"] ?? "").toString().isEmpty
                ? Container(color: color)
                : CachedNetworkImage(imageUrl: _c["coverImage"].toString(), fit: BoxFit.cover, color: color.withValues(alpha: 0.55), colorBlendMode: BlendMode.multiply),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
          sliver: SliverList.list(children: [
            Row(children: [
              if ((sp["logo"] ?? "").toString().isNotEmpty)
                ClipRRect(borderRadius: BorderRadius.circular(10), child: CachedNetworkImage(imageUrl: sp["logo"].toString(), width: 36, height: 36, fit: BoxFit.cover)),
              const SizedBox(width: 10),
              Expanded(child: Text("${tr("Sponsored by")} ${sp["name"]}", style: TextStyle(color: color, fontWeight: FontWeight.w800))),
            ]),
            const SizedBox(height: 10),
            Text(_c["title"].toString(), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(_c["description"]?.toString() ?? "", style: const TextStyle(fontSize: 15, height: 1.5)),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              Chip(avatar: const Icon(Icons.flag_rounded, size: 16), label: Text("$target× ${(_c["activity"] ?? "").toString().isEmpty ? tr("any eco action") : _c["activity"]}")),
              if ((_c["hashtag"] ?? "").toString().isNotEmpty) Chip(label: Text("#${_c["hashtag"]}")),
              Chip(avatar: const Icon(Icons.stars_rounded, size: 16, color: AppColors.sun), label: Text("+${_c["rewardPoints"]}")),
              if (ends != null) Chip(avatar: const Icon(Icons.timer_rounded, size: 16), label: Text("${ends.difference(DateTime.now()).inDays}d ${tr("left")}")),
              if (_c["spotsLeft"] != null) Chip(label: Text("${_c["spotsLeft"]} ${tr("prizes left")}")),
            ]),
            if ((_c["prize"] ?? "").toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.blush, borderRadius: BorderRadius.circular(16)),
                child: Row(children: [const Text("🎁", style: TextStyle(fontSize: 26)), const SizedBox(width: 10), Expanded(child: Text(_c["prize"].toString(), style: const TextStyle(fontWeight: FontWeight.w800)))]),
              ),
            ],
            if (_c["joined"] == true) ...[
              const SizedBox(height: 20),
              Text(_c["done"] == true ? "✅ ${tr("Completed — reward added!")}" : "${tr("Your progress")}: $mine / $target", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: (mine / target).clamp(0, 1).toDouble(), minHeight: 12, color: color, backgroundColor: AppColors.border)),
              const SizedBox(height: 8),
              Text(tr("Post your actions with the activity or hashtag above — they count automatically."), style: TextStyle(color: AppColors.subtitle)),
            ],
            const SizedBox(height: 14),
            Text("${_c["participants"]} ${tr("joined")} · ${_c["completed"]} ${tr("completed")}", style: TextStyle(color: AppColors.subtitle)),
          ]),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: _c["joined"] == true
              ? FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: color),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostScreen())),
                  icon: const Icon(Icons.add_a_photo_rounded),
                  label: Text(tr("Post an action")),
                )
              : FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: color), onPressed: _busy ? null : _join, icon: const Icon(Icons.bolt_rounded), label: Text(tr("Join challenge"))),
        ),
      ),
    );
  }
}
