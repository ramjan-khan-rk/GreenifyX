import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/i18n/app_locale.dart';
import '../../core/services/api_service.dart';
import '../../core/services/session_user.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/utils/media_url.dart';
import 'package:url_launcher/url_launcher.dart';
import '../post/domain/eco_activity.dart';
import '../post/presentation/screens/create_post_screen.dart';

typedef Json = Map<String, dynamic>;

const _statusText = {
  "applied": "Applied · waiting for the brand",
  "accepted": "Accepted · post your action, then link it",
  "rejected": "Not selected this time",
  "delivered": "Delivered · payment on its way",
  "paid": "Paid",
};

/// Brand deals: paid briefs from brands for eco creators.
class DealsScreen extends StatefulWidget {
  const DealsScreen({super.key});

  @override
  State<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends State<DealsScreen> {
  Json? _d;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _toast(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Json? _payout;

  Future<void> _load() async {
    try {
      final r = await ApiService.dio.get("/deals");
      if (mounted) setState(() => _d = Json.from(r.data as Map));
      final p = await ApiService.dio.get("/deals/payouts");
      if (mounted) setState(() => _payout = Json.from(p.data as Map));
    } catch (e) {
      if (mounted) _toast(friendlyError(e));
    }
  }

  /// Opens Stripe's own page to add bank details; GreenifyX never sees them.
  Future<void> _setupPayouts() async {
    try {
      final r = await ApiService.dio.post("/deals/payouts/setup");
      await launchUrl(Uri.parse(r.data["url"].toString()), mode: LaunchMode.externalApplication);
    } catch (e) {
      _toast(friendlyError(e));
    }
  }

  Widget _payoutCard() {
    final p = _payout;
    if (p == null || p["available"] != true) return const SizedBox.shrink();
    final ready = p["ready"] == true;
    return Card(
      child: ListTile(
        leading: Icon(ready ? Icons.account_balance_rounded : Icons.account_balance_outlined, color: ready ? AppColors.eco : AppColors.ink),
        title: Text(ready ? tr("Payouts are set up") : tr("Set up payouts"), style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(ready ? tr("Brand payments go straight to your bank through Stripe.") : tr("Add your bank details on Stripe's secure page to get paid automatically.")),
        trailing: ready ? null : FilledButton(onPressed: _setupPayouts, child: Text(p["started"] == true ? tr("Finish") : tr("Start"))),
      ),
    );
  }

  Future<void> _apply(Json deal) async {
    final c = TextEditingController();
    final pitch = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("${tr("Apply to")} ${deal["brand"]}"),
        content: TextField(
          controller: c,
          maxLines: 4,
          maxLength: 500,
          decoration: InputDecoration(hintText: tr("Why you? What will you post? (optional)")),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr("Cancel"))),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: Text(tr("Send application"))),
        ],
      ),
    );
    if (pitch == null) return;
    try {
      await ApiService.dio.post("/deals/${deal["_id"]}/apply", data: {"pitch": pitch});
      _toast(tr("Application sent. We'll let you know!"));
      _load();
    } catch (e) {
      _toast(friendlyError(e));
    }
  }

  Future<void> _deliver(Json deal) async {
    List<Json> posts;
    try {
      final r = await ApiService.dio.get("/discover/creators/${SessionUser.id}");
      posts = ((r.data["posts"] as List?) ?? []).map((e) => Json.from(e as Map)).toList();
    } catch (_) {
      posts = [];
    }
    if (!mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
          Text(tr("Which post is for this brand?"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => CreatePostScreen(presetActivity: (deal["activity"] ?? "").toString().isEmpty ? null : deal["activity"].toString())));
            },
            icon: const Icon(Icons.add_a_photo_rounded),
            label: Text(tr("Make the post first")),
          ),
          const SizedBox(height: 8),
          for (final p in posts.take(12))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: p["mediaType"] == "video"
                      ? Container(color: AppColors.surfaceAlt, child: const Icon(Icons.play_arrow_rounded))
                      : CachedNetworkImage(imageUrl: resolveMediaUrl(p["image"]?.toString()) ?? "", fit: BoxFit.cover),
                ),
              ),
              title: Text(p["activity"]?.toString() ?? ""),
              subtitle: Text(p["description"]?.toString() ?? "", maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.pop(context, p["_id"].toString()),
            ),
        ]),
      ),
    );
    if (picked == null) return;
    try {
      await ApiService.dio.post("/deals/${deal["_id"]}/deliver", data: {"postId": picked});
      _toast(tr("Delivered! The brand will review it."));
      _load();
    } catch (e) {
      _toast(friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final deals = (d?["deals"] as List? ?? []).map((e) => Json.from(e as Map)).toList();
    return Scaffold(
      appBar: AppBar(title: Text(tr("Brand deals"))),
      body: d == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), gradient: const LinearGradient(colors: [Color(0xFF2B2440), Color(0xFFE36A4A)])),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("🤝", style: TextStyle(fontSize: 32)),
                    const SizedBox(height: 6),
                    Text(tr("Get paid for real impact"), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(
                      "${tr("Brands pay eco creators to post real actions. You have")} ${d["followers"]} ${tr("followers")}.",
                      style: const TextStyle(color: Colors.white, height: 1.4),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                _payoutCard(),
                if (deals.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 30),
                    child: Text(tr("No open deals right now. Keep posting, more brands are coming."), textAlign: TextAlign.center, style: TextStyle(color: AppColors.subtitle)),
                  ),
                for (final deal in deals) _DealCard(deal: deal, onApply: () => _apply(deal), onDeliver: () => _deliver(deal)),
              ]),
            ),
    );
  }
}

class _DealCard extends StatelessWidget {
  final Json deal;
  final VoidCallback onApply;
  final VoidCallback onDeliver;
  const _DealCard({required this.deal, required this.onApply, required this.onDeliver});

  @override
  Widget build(BuildContext context) {
    final app = deal["application"] is Map ? Json.from(deal["application"] as Map) : null;
    final deadline = DateTime.tryParse(deal["deadline"]?.toString() ?? "")?.toLocal();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: AppColors.surfaceAlt,
              backgroundImage: (deal["brandLogo"] ?? "").toString().isNotEmpty ? CachedNetworkImageProvider(deal["brandLogo"].toString()) : null,
              child: (deal["brandLogo"] ?? "").toString().isEmpty ? Text(deal["brand"].toString().characters.first) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(deal["brand"].toString(), style: TextStyle(color: AppColors.subtitle, fontWeight: FontWeight.w700)),
                Text(deal["title"].toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text("AED ${deal["youReceiveAed"]}", style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.eco, fontSize: 16)),
              Text(tr("to you"), style: TextStyle(color: AppColors.subtitle, fontSize: 11)),
            ]),
          ]),
          if ((deal["brief"] ?? "").toString().isNotEmpty) ...[const SizedBox(height: 10), Text(deal["brief"].toString(), style: const TextStyle(height: 1.4))],
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            if ((deal["activity"] ?? "").toString().isNotEmpty) Chip(label: Text("🌱 ${activityName(deal["activity"].toString())}"), visualDensity: VisualDensity.compact),
            if ((deal["hashtag"] ?? "").toString().isNotEmpty) Chip(label: Text("#${deal["hashtag"]}"), visualDensity: VisualDensity.compact),
            if ((deal["minFollowers"] ?? 0) > 0) Chip(label: Text("${deal["minFollowers"]}+ ${tr("followers")}"), visualDensity: VisualDensity.compact),
            if (deadline != null) Chip(label: Text("${tr("Until")} ${DateFormat("d MMM").format(deadline)}"), visualDensity: VisualDensity.compact),
          ]),
          const SizedBox(height: 6),
          Text("${tr("Brand pays")} AED ${deal["payoutAed"]} · ${tr("GreenifyX fee")} ${deal["platformFeePct"]}%", style: TextStyle(color: AppColors.subtitle, fontSize: 12)),
          const SizedBox(height: 10),
          if (app != null) ...[
            Text(tr(_statusText[app["status"]] ?? app["status"].toString()), style: const TextStyle(fontWeight: FontWeight.w800)),
            if (app["status"] == "accepted") ...[
              const SizedBox(height: 8),
              FilledButton.icon(onPressed: onDeliver, icon: const Icon(Icons.link_rounded), label: Text(tr("Link my post"))),
            ],
          ] else
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: deal["canApply"] == true ? onApply : null,
                child: Text(deal["canApply"] == true ? tr("Apply") : tr(deal["reason"]?.toString() ?? "Not available")),
              ),
            ),
        ]),
      ),
    );
  }
}
