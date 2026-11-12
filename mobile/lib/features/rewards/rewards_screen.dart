import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/friendly_error.dart';

typedef Json = Map<String, dynamic>;

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  bool _loading = true;
  String? _error;
  int _balance = 0;
  List<Json> _rewards = [];
  List<Json> _mine = [];
  String _category = "all";

  static const _cats = {
    "all": ("All", Icons.apps_rounded),
    "voucher": ("Vouchers", Icons.local_offer_rounded),
    "experience": ("Experiences", Icons.kayaking_rounded),
    "donation": ("Give back", Icons.park_rounded),
    "transport": ("Transport", Icons.directions_bus_rounded),
    "merch": ("Merch", Icons.shopping_bag_rounded),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await Future.wait([ApiService.dio.get("/rewards"), ApiService.dio.get("/rewards/mine")]);
      if (!mounted) return;
      setState(() {
        _balance = (r[0].data["balance"] as num?)?.toInt() ?? 0;
        _rewards = (r[0].data["rewards"] as List).map((e) => Json.from(e as Map)).toList();
        _mine = (r[1].data["redemptions"] as List).map((e) => Json.from(e as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyError(e);
          _loading = false;
        });
      }
    }
  }

  Future<void> _redeem(Json reward) async {
    final cost = (reward["cost"] as num).toInt();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(reward["title"] ?? "", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            if ((reward["partner"] ?? "").toString().isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 4), child: Text(reward["partner"], style: const TextStyle(color: AppColors.subtitle))),
            const SizedBox(height: 12),
            Text(reward["description"] ?? "", style: const TextStyle(height: 1.45)),
            if ((reward["terms"] ?? "").toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(reward["terms"], style: const TextStyle(fontSize: 12.5, color: AppColors.subtitle)),
            ],
            const SizedBox(height: 18),
            Row(children: [
              const Icon(Icons.stars_rounded, color: AppColors.sun),
              const SizedBox(width: 6),
              Text("$cost points", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const Spacer(),
              Text("You have $_balance", style: const TextStyle(color: AppColors.subtitle)),
            ]),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _balance >= cost ? () => Navigator.pop(ctx, true) : null,
              child: Text(_balance >= cost ? "Redeem now" : "${cost - _balance} more points needed"),
            ),
          ]),
        ),
      ),
    );
    if (ok != true) return;
    try {
      final r = await ApiService.dio.post("/rewards/${reward["_id"]}/redeem");
      final code = r.data["redemption"]["code"].toString();
      await _load();
      if (!mounted) return;
      _tabs.animateTo(1);
      _showCode(reward["title"]?.toString() ?? "Reward", code);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  void _showCode(String title, String code) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.celebration_rounded, color: AppColors.joy, size: 40),
        title: Text(title, textAlign: TextAlign.center),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("Show this code at the partner counter", textAlign: TextAlign.center),
          const SizedBox(height: 16),
          _CodeBox(code: code),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Done"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _category == "all" ? _rewards : _rewards.where((r) => r["category"] == _category).toList();
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (_, _) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 210,
            backgroundColor: AppColors.ink,
            foregroundColor: Colors.white,
            title: const Text("Rewards"),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF2B2440), Color(0xFF1F5A4B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                padding: const EdgeInsets.fromLTRB(20, 96, 20, 56),
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text("Available to spend", style: TextStyle(color: Colors.white.withValues(alpha: 0.75))),
                    Text("$_balance", style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800, height: 1.1)),
                  ]),
                  const Spacer(),
                  const Icon(Icons.redeem_rounded, color: AppColors.sun, size: 48),
                ]),
              ),
            ),
            bottom: TabBar(
              controller: _tabs,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              indicatorColor: AppColors.sun,
              tabs: [const Tab(text: "Catalogue"), Tab(text: "My codes (${_mine.where((m) => m["status"] == "issued").length})")],
            ),
          ),
        ],
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _load, child: const Text("Try again")),
                  ])))
                : TabBarView(controller: _tabs, children: [
                    RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 30), children: [
                        SizedBox(
                          height: 40,
                          child: ListView(scrollDirection: Axis.horizontal, children: [
                            for (final c in _cats.entries)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  avatar: Icon(c.value.$2, size: 17),
                                  label: Text(c.value.$1),
                                  selected: _category == c.key,
                                  onSelected: (_) => setState(() => _category = c.key),
                                ),
                              ),
                          ]),
                        ),
                        const SizedBox(height: 14),
                        if (list.isEmpty)
                          const Padding(padding: EdgeInsets.all(40), child: Center(child: Text("No rewards here yet — check back soon."))),
                        for (final r in list) _RewardCard(reward: r, balance: _balance, onTap: () => _redeem(r)),
                      ]),
                    ),
                    RefreshIndicator(
                      onRefresh: _load,
                      child: _mine.isEmpty
                          ? ListView(children: const [
                              SizedBox(height: 80),
                              Icon(Icons.confirmation_number_outlined, size: 56, color: AppColors.subtitle),
                              SizedBox(height: 12),
                              Center(child: Text("Your reward codes will appear here")),
                            ])
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
                              itemCount: _mine.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (_, i) => _RedemptionTile(item: _mine[i], onTap: () => _showCode(_mine[i]["rewardTitle"] ?? "", _mine[i]["code"] ?? "")),
                            ),
                    ),
                  ]),
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  final Json reward;
  final int balance;
  final VoidCallback onTap;
  const _RewardCard({required this.reward, required this.balance, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cost = (reward["cost"] as num).toInt();
    final affordable = balance >= cost;
    final stock = reward["stock"];
    final img = (reward["image"] ?? "").toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AspectRatio(
              aspectRatio: 2.3,
              child: Stack(fit: StackFit.expand, children: [
                if (img.isNotEmpty)
                  CachedNetworkImage(imageUrl: img, fit: BoxFit.cover, errorWidget: (_, _, _) => Container(color: AppColors.blush))
                else
                  Container(color: AppColors.blush),
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.stars_rounded, color: AppColors.sun, size: 16),
                      const SizedBox(width: 4),
                      Text("$cost", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
                if (stock != null)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.joy, borderRadius: BorderRadius.circular(20)),
                      child: Text("$stock left", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(reward["title"] ?? "", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(reward["partner"] ?? "", style: const TextStyle(color: AppColors.subtitle, fontSize: 13)),
                  ]),
                ),
                const SizedBox(width: 10),
                affordable
                    ? FilledButton(onPressed: onTap, child: const Text("Redeem"))
                    : Text("${cost - balance} to go", style: const TextStyle(color: AppColors.subtitle, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _RedemptionTile extends StatelessWidget {
  final Json item;
  final VoidCallback onTap;
  const _RedemptionTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = item["status"]?.toString() ?? "issued";
    final date = DateTime.tryParse(item["createdAt"]?.toString() ?? "")?.toLocal();
    final color = status == "issued" ? AppColors.eco : status == "used" ? AppColors.subtitle : AppColors.error;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: ListTile(
        onTap: status == "issued" ? onTap : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(Icons.confirmation_number_rounded, color: color)),
        title: Text(item["rewardTitle"] ?? "", style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text("${item["code"]}  ·  ${date == null ? "" : DateFormat("d MMM").format(date)}"),
        trailing: Text(status.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11.5)),
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  final String code;
  const _CodeBox({required this.code});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Clipboard.setData(ClipboardData(text: code));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Code copied")));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.sun, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(code, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 2)),
          const SizedBox(width: 10),
          const Icon(Icons.copy_rounded, size: 18, color: AppColors.subtitle),
        ]),
      ),
    );
  }
}
