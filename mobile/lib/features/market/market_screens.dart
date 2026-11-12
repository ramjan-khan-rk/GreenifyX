import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/i18n/app_locale.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/chat_launcher.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/widgets/user_avatar.dart';

typedef Json = Map<String, dynamic>;
List<Json> _maps(dynamic v) => (v as List? ?? const []).map((e) => Json.from(e as Map)).toList();

const _cats = ["Furniture", "Electronics", "Books & School", "Kids & Baby", "Clothes", "Home & Kitchen", "Sports & Bikes", "Plants & Garden", "Other"];
const _emirates = ["Abu Dhabi", "Dubai", "Sharjah", "Ajman", "Umm Al Quwain", "Ras Al Khaimah", "Fujairah"];
const _typeLabel = {"give": "Free", "swap": "Swap", "sell": "Sell"};
const _typeColor = {"give": AppColors.eco, "swap": Color(0xFF7F53AC), "sell": AppColors.joy};

String _price(Json l) => l["type"] == "sell" ? "AED ${(l["priceAed"] as num).toStringAsFixed(0)}" : tr(_typeLabel[l["type"]] ?? "Free");

/// Swap & Share: give away, swap or sell second-hand items near you.
class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  List<Json>? _items;
  int _rehomed = 0;
  String? _type;
  String? _cat;
  String? _emirate;
  bool _mine = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ApiService.dio.get("/market", queryParameters: {"type": ?_type, "category": ?_cat, "emirate": ?_emirate, if (_mine) "mine": "1"});
      if (!mounted) return;
      setState(() {
        _items = _maps(r.data["listings"]);
        _rehomed = (r.data["itemsRehomed"] as num?)?.toInt() ?? 0;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _items = []);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: Text(tr("Swap & Share"))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const CreateListingScreen()));
          if (ok == true) _load();
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(tr("List an item")),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), gradient: const LinearGradient(colors: [Color(0xFF7F53AC), Color(0xFFE36A4A)])),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tr("Give it a second life"), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text("$_rehomed ${tr("items re-homed in the UAE · +15 points each")}", style: const TextStyle(color: Colors.white70)),
                      ]),
                    ),
                    const Icon(Icons.autorenew_rounded, color: Colors.white, size: 48),
                  ]),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    for (final t in [null, "give", "swap", "sell"])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(t == null ? tr("All") : tr(_typeLabel[t]!)),
                          selected: _type == t,
                          onSelected: (_) {
                            setState(() => _type = t);
                            _load();
                          },
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(tr("My listings")),
                        selected: _mine,
                        onSelected: (v) {
                          setState(() => _mine = v);
                          _load();
                        },
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: _cat,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: tr("Category"), isDense: true),
                      items: [DropdownMenuItem(value: null, child: Text(tr("All"))), for (final c in _cats) DropdownMenuItem(value: c, child: Text(tr(c)))],
                      onChanged: (v) {
                        setState(() => _cat = v);
                        _load();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: _emirate,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: tr("Emirate"), isDense: true),
                      items: [DropdownMenuItem(value: null, child: Text(tr("All"))), for (final e in _emirates) DropdownMenuItem(value: e, child: Text(e))],
                      onChanged: (v) {
                        setState(() => _emirate = v);
                        _load();
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
              ]),
            ),
          ),
          if (items == null)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (items.isEmpty)
            SliverFillRemaining(child: Center(child: Text(tr("Nothing listed yet. Be the first!"), style: const TextStyle(color: AppColors.subtitle))))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.72),
                delegate: SliverChildBuilderDelegate((_, i) {
                  final l = items[i];
                  return _ListingCard(l: l, onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => ListingDetailScreen(id: l["_id"].toString())));
                    _load();
                  });
                }, childCount: items.length),
              ),
            ),
        ]),
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final Json l;
  final VoidCallback onTap;
  const _ListingCard({required this.l, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final imgs = (l["images"] as List? ?? []);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              if (imgs.isNotEmpty) CachedNetworkImage(imageUrl: imgs.first.toString(), fit: BoxFit.cover) else Container(color: AppColors.blush),
              Positioned(
                left: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: _typeColor[l["type"]] ?? AppColors.eco, borderRadius: BorderRadius.circular(12)),
                  child: Text(_price(l), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                ),
              ),
              if (l["status"] == "reserved")
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                    child: Text(tr("Reserved"), style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l["title"].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text("${l["area"]?.toString().isNotEmpty == true ? "${l["area"]}, " : ""}${l["emirate"] ?? ""}",
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.subtitle, fontSize: 12)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class ListingDetailScreen extends StatefulWidget {
  final String id;
  const ListingDetailScreen({super.key, required this.id});

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  Json? _l;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ApiService.dio.get("/market/${widget.id}");
      if (mounted) setState(() => _l = Json.from(r.data["listing"] as Map));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _status(String s, {String? receiverId}) async {
    try {
      final r = await ApiService.dio.patch("/market/${widget.id}", data: {"status": s, "receiverId": ?receiverId});
      if (!mounted) return;
      if (s == "done") {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("🎉 +${r.data["pointsAwarded"]} ${tr("Eco Points")} · ${tr("Thanks for keeping it in use!")}")));
      }
      if (s == "removed") {
        Navigator.pop(context);
      } else {
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _interest() async {
    try {
      await ApiService.dio.post("/market/${widget.id}/interest");
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _l;
    if (l == null) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    final imgs = (l["images"] as List? ?? []).map((e) => e.toString()).toList();
    final seller = Json.from((l["user"] ?? {}) as Map);
    final mine = l["isMine"] == true;
    final interested = _maps(l["interested"]);
    final open = l["status"] == "active" || l["status"] == "reserved";
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 320,
          flexibleSpace: FlexibleSpaceBar(
            background: imgs.isEmpty
                ? Container(color: AppColors.blush)
                : PageView(children: [for (final u in imgs) CachedNetworkImage(imageUrl: u, fit: BoxFit.cover)]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
          sliver: SliverList.list(children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: (_typeColor[l["type"]] ?? AppColors.eco).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Text(_price(l), style: TextStyle(color: _typeColor[l["type"]] ?? AppColors.eco, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 8),
              Text("${tr(l["category"].toString())} · ${tr(l["condition"].toString())}", style: const TextStyle(color: AppColors.subtitle)),
            ]),
            const SizedBox(height: 10),
            Text(l["title"].toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            if ((l["swapFor"] ?? "").toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text("${tr("Swap for")}: ${l["swapFor"]}", style: const TextStyle(fontWeight: FontWeight.w700))),
            const SizedBox(height: 10),
            Text(l["description"]?.toString() ?? "", style: const TextStyle(fontSize: 15, height: 1.5)),
            const SizedBox(height: 14),
            Row(children: [
              const Icon(Icons.place_rounded, size: 18, color: AppColors.subtitle),
              const SizedBox(width: 6),
              Text("${l["area"]?.toString().isNotEmpty == true ? "${l["area"]}, " : ""}${l["emirate"] ?? ""}"),
              const Spacer(),
              Text("♻️ ~${l["kgSaved"]} kg ${tr("kept from landfill")}", style: const TextStyle(color: AppColors.eco, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ]),
            const Divider(height: 30),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: UserAvatar(imageUrl: seller["profileImage"]?.toString(), name: seller["name"]?.toString()),
              title: Text(seller["name"]?.toString() ?? "", style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text("${tr("Level")} ${seller["level"] ?? 1}"),
            ),
            if (mine && interested.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text("${tr("Interested")} (${interested.length})", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              for (final u in interested)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: UserAvatar(imageUrl: u["profileImage"]?.toString(), name: u["name"]?.toString()),
                  title: Text(u["name"].toString()),
                  trailing: Wrap(spacing: 4, children: [
                    IconButton(
                      tooltip: tr("Message"),
                      onPressed: () => openChat(context, userId: u["_id"].toString(), name: u["name"].toString(), profileImage: u["profileImage"]?.toString() ?? ""),
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                    ),
                    if (open)
                      IconButton(
                        tooltip: tr("Given to them"),
                        onPressed: () => _status("done", receiverId: u["_id"].toString()),
                        icon: const Icon(Icons.handshake_rounded, color: AppColors.eco),
                      ),
                  ]),
                ),
            ],
          ]),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: !open
              ? Center(child: Text(l["status"] == "done" ? "✅ ${tr("Re-homed")}" : tr("No longer available"), style: const TextStyle(fontWeight: FontWeight.w800)))
              : mine
                  ? Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _status(l["status"] == "reserved" ? "active" : "reserved"),
                          child: Text(l["status"] == "reserved" ? tr("Mark available") : tr("Mark reserved")),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: FilledButton(onPressed: () => _status("done"), child: Text(tr("Mark as done")))),
                      IconButton(onPressed: () => _status("removed"), icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error)),
                    ])
                  : Row(children: [
                      Expanded(
                        child: l["amInterested"] == true
                            ? OutlinedButton.icon(onPressed: _interest, icon: const Icon(Icons.check_rounded), label: Text(tr("Interested")))
                            : FilledButton.icon(onPressed: _interest, icon: const Icon(Icons.favorite_rounded), label: Text(tr("I want this"))),
                      ),
                      if (l["amInterested"] == true) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => openChat(context, userId: seller["_id"].toString(), name: seller["name"].toString(), profileImage: seller["profileImage"]?.toString() ?? ""),
                            icon: const Icon(Icons.chat_rounded),
                            label: Text(tr("Message")),
                          ),
                        ),
                      ],
                    ]),
        ),
      ),
    );
  }
}

class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({super.key});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _swap = TextEditingController();
  final _area = TextEditingController();
  final List<File> _photos = [];
  String _type = "give";
  String _cat = "Furniture";
  String _cond = "good";
  String _emirate = "Dubai";
  bool _saving = false;

  Future<void> _add() async {
    final xs = await ImagePicker().pickMultiImage(imageQuality: 80, maxWidth: 1600, limit: 4);
    setState(() => _photos.addAll(xs.map((x) => File(x.path)).take(4 - _photos.length)));
  }

  Future<void> _save() async {
    if (_photos.isEmpty || _title.text.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr("Add a title and at least one photo"))));
      return;
    }
    setState(() => _saving = true);
    try {
      final form = FormData.fromMap({
        "title": _title.text.trim(),
        "description": _desc.text.trim(),
        "type": _type,
        "category": _cat,
        "condition": _cond,
        "emirate": _emirate,
        "area": _area.text.trim(),
        "priceAed": _price.text.trim(),
        "swapFor": _swap.text.trim(),
        "images": [for (final f in _photos) await MultipartFile.fromFile(f.path, filename: f.path.split(RegExp(r"[/\\]")).last, contentType: MediaType("image", "jpeg"))],
      });
      await ApiService.dio.post("/market", data: form, options: Options(sendTimeout: const Duration(minutes: 2), receiveTimeout: const Duration(minutes: 2)));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr("List an item"))),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 30), children: [
        SizedBox(
          height: 96,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final f in _photos)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Stack(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(f, width: 96, height: 96, fit: BoxFit.cover)),
                  Positioned(
                    right: 2,
                    top: 2,
                    child: GestureDetector(onTap: () => setState(() => _photos.remove(f)), child: const CircleAvatar(radius: 12, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white))),
                  ),
                ]),
              ),
            if (_photos.length < 4)
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _add,
                child: Container(
                  width: 96,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border, width: 2)),
                  child: const Icon(Icons.add_a_photo_rounded, color: AppColors.subtitle),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: "give", label: Text(tr("Free")), icon: const Icon(Icons.volunteer_activism_rounded)),
            ButtonSegment(value: "swap", label: Text(tr("Swap")), icon: const Icon(Icons.swap_horiz_rounded)),
            ButtonSegment(value: "sell", label: Text(tr("Sell")), icon: const Icon(Icons.sell_rounded)),
          ],
          selected: {_type},
          onSelectionChanged: (s) => setState(() => _type = s.first),
        ),
        const SizedBox(height: 14),
        TextField(controller: _title, decoration: InputDecoration(labelText: tr("Title"), hintText: tr("e.g. Kids bicycle, 16 inch"))),
        const SizedBox(height: 12),
        if (_type == "sell") ...[
          TextField(controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "AED")),
          const SizedBox(height: 12),
        ],
        if (_type == "swap") ...[
          TextField(controller: _swap, decoration: InputDecoration(labelText: tr("What would you like in return?"))),
          const SizedBox(height: 12),
        ],
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _cat,
              isExpanded: true,
              decoration: InputDecoration(labelText: tr("Category")),
              items: [for (final c in _cats) DropdownMenuItem(value: c, child: Text(tr(c)))],
              onChanged: (v) => setState(() => _cat = v ?? _cat),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _cond,
              isExpanded: true,
              decoration: InputDecoration(labelText: tr("Condition")),
              items: [for (final c in const ["new", "like-new", "good", "fair"]) DropdownMenuItem(value: c, child: Text(tr(c)))],
              onChanged: (v) => setState(() => _cond = v ?? _cond),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _emirate,
              isExpanded: true,
              decoration: InputDecoration(labelText: tr("Emirate")),
              items: [for (final e in _emirates) DropdownMenuItem(value: e, child: Text(e))],
              onChanged: (v) => setState(() => _emirate = v ?? _emirate),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _area, decoration: InputDecoration(labelText: tr("Area")))),
        ]),
        const SizedBox(height: 12),
        TextField(controller: _desc, maxLines: 4, decoration: InputDecoration(labelText: tr("Description"))),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.publish_rounded),
          label: Text(tr("Publish listing")),
        ),
      ]),
    );
  }
}
