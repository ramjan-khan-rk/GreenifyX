import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/friendly_error.dart';
import '../campaign/presentation/screens/campaigns_screen.dart';
import '../../core/i18n/app_locale.dart';

typedef Json = Map<String, dynamic>;

const _catStyle = {
  "cleanup": (Icons.cleaning_services_rounded, Color(0xFF3A7BD5)),
  "planting": (Icons.park_rounded, Color(0xFF1F8A70)),
  "workshop": (Icons.handyman_rounded, Color(0xFFE36A4A)),
  "talk": (Icons.mic_rounded, Color(0xFF7F53AC)),
  "market": (Icons.storefront_rounded, Color(0xFFF2B544)),
  "campaign": (Icons.campaign_rounded, Color(0xFF2B2440)),
};

(IconData, Color) _style(String? c) => _catStyle[c] ?? (Icons.event_rounded, AppColors.joy);

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  bool _loading = true;
  String? _error;
  List<Json> _items = [];
  DateTime? _day; // null = all upcoming
  bool _goingOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ApiService.dio.get("/events");
      if (!mounted) return;
      setState(() {
        _items = (r.data["items"] as List).map((e) => Json.from(e as Map)).toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  DateTime _start(Json e) => DateTime.tryParse(e["startsAt"]?.toString() ?? "")?.toLocal() ?? DateTime.now();

  bool _same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(14, (i) => DateTime(today.year, today.month, today.day + i));
    var list = _items;
    if (_day != null) {
      list = list.where((e) {
        final s = _start(e);
        final end = DateTime.tryParse(e["endsAt"]?.toString() ?? "")?.toLocal() ?? s;
        final dayEnd = _day!.add(const Duration(days: 1));
        return s.isBefore(dayEnd) && !end.isBefore(_day!);
      }).toList();
    }
    if (_goingOnly) list = list.where((e) => e["going"] == true).toList();

    // Group by start day.
    final groups = <String, List<Json>>{};
    for (final e in list) {
      final s = _start(e);
      final key = _same(s, today)
          ? tr("Today")
          : _same(s, today.add(const Duration(days: 1)))
              ? tr("Tomorrow")
              : s.isBefore(today)
                  ? tr("Happening now")
                  : DateFormat("EEEE, d MMMM").format(s);
      groups.putIfAbsent(key, () => []).add(e);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr("Green events")),
        actions: [
          FilterChip(
            label: Text(tr("Going")),
            selected: _goingOnly,
            onSelected: (v) => setState(() => _goingOnly = v),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(children: [
        SizedBox(
          height: 86,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              _DayPill(top: "All", bottom: "∞", selected: _day == null, hasItems: true, onTap: () => setState(() => _day = null)),
              for (final d in days)
                _DayPill(
                  top: DateFormat("EEE").format(d),
                  bottom: "${d.day}",
                  selected: _day != null && _same(_day!, d),
                  hasItems: _items.any((e) => _same(_start(e), d)),
                  onTap: () => setState(() => _day = d),
                ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: TextButton(onPressed: _load, child: Text("$_error\nTap to retry", textAlign: TextAlign.center)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: list.isEmpty
                          ? ListView(children: const [
                              SizedBox(height: 80),
                              Icon(Icons.event_busy_rounded, size: 56, color: AppColors.subtitle),
                              SizedBox(height: 10),
                              Center(child: Text("Nothing on this day — try another date")),
                            ])
                          : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
                              for (final g in groups.entries) ...[
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                                  child: Text(g.key, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
                                ),
                                for (final e in g.value)
                                  _EventCard(
                                    e: e,
                                    onTap: () async {
                                      if (e["kind"] == "campaign") {
                                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const CampaignsScreen()));
                                      } else {
                                        final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => EventDetailScreen(event: e)));
                                        if (changed == true) _load();
                                      }
                                    },
                                  ),
                              ],
                            ]),
                    ),
        ),
      ]),
    );
  }
}

class _DayPill extends StatelessWidget {
  final String top;
  final String bottom;
  final bool selected;
  final bool hasItems;
  final VoidCallback onTap;
  const _DayPill({required this.top, required this.bottom, required this.selected, required this.hasItems, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 54,
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(top, style: TextStyle(fontSize: 12, color: selected ? Colors.white70 : AppColors.subtitle, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(bottom, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: selected ? Colors.white : AppColors.ink)),
            const SizedBox(height: 3),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: hasItems ? AppColors.joy : Colors.transparent),
            ),
          ]),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Json e;
  final VoidCallback onTap;
  const _EventCard({required this.e, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _style(e["kind"] == "campaign" ? "campaign" : e["category"]?.toString());
    final s = DateTime.tryParse(e["startsAt"]?.toString() ?? "")?.toLocal();
    final img = (e["coverImage"] ?? "").toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Row(children: [
            SizedBox(
              width: 96,
              height: 112,
              child: img.isEmpty
                  ? Container(color: color.withValues(alpha: 0.15), child: Icon(icon, color: color, size: 36))
                  : CachedNetworkImage(imageUrl: img, fit: BoxFit.cover, errorWidget: (_, _, _) => Container(color: color.withValues(alpha: 0.15))),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(icon, size: 15, color: color),
                    const SizedBox(width: 4),
                    Text(
                      (e["kind"] == "campaign" ? "Campaign" : (e["category"] ?? "event").toString()).toUpperCase(),
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                    ),
                    const Spacer(),
                    if (e["going"] == true)
                      const Icon(Icons.check_circle_rounded, color: AppColors.eco, size: 18),
                  ]),
                  const SizedBox(height: 4),
                  Text(e["title"] ?? "", maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(
                    "${s == null ? "" : DateFormat("h:mm a").format(s)} · ${e["venue"] ?? e["emirate"] ?? ""}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.subtitle, fontSize: 12.5),
                  ),
                  const SizedBox(height: 2),
                  Text("${e["attendeeCount"] ?? 0} going", style: const TextStyle(color: AppColors.subtitle, fontSize: 12.5)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class EventDetailScreen extends StatefulWidget {
  final Json event;
  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late Json _e = widget.event;
  bool _busy = false;
  bool _changed = false;

  Future<void> _rsvp() async {
    setState(() => _busy = true);
    try {
      final r = await ApiService.dio.post("/events/${_e["_id"]}/rsvp");
      setState(() {
        _e = {..._e, ...Json.from(r.data["event"] as Map)};
        _changed = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_e["going"] == true ? "You're going! See you there 🌱" : "RSVP removed")));
      }
    } catch (err) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(err))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = DateTime.tryParse(_e["startsAt"]?.toString() ?? "")?.toLocal();
    final end = DateTime.tryParse(_e["endsAt"]?.toString() ?? "")?.toLocal();
    final (icon, color) = _style(_e["category"]?.toString());
    final img = (_e["coverImage"] ?? "").toString();
    final going = _e["going"] == true;
    final cap = (_e["capacity"] as num?)?.toInt() ?? 0;
    final count = (_e["attendeeCount"] as num?)?.toInt() ?? 0;
    final loc = _e["location"];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        body: CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 240,
            foregroundColor: Colors.white,
            backgroundColor: color,
            flexibleSpace: FlexibleSpaceBar(
              background: img.isEmpty
                  ? Container(color: color, child: Icon(icon, size: 80, color: Colors.white54))
                  : CachedNetworkImage(imageUrl: img, fit: BoxFit.cover),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
            sliver: SliverList.list(children: [
              Text((_e["category"] ?? "").toString().toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
              const SizedBox(height: 6),
              Text(_e["title"] ?? "", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.2)),
              const SizedBox(height: 16),
              _InfoRow(Icons.event_rounded, s == null ? "" : DateFormat("EEEE, d MMMM").format(s)),
              _InfoRow(Icons.schedule_rounded, s == null ? "" : "${DateFormat("h:mm a").format(s)}${end == null ? "" : " – ${DateFormat("h:mm a").format(end)}"}"),
              _InfoRow(Icons.place_rounded, "${_e["venue"] ?? ""}${(_e["emirate"] ?? "").toString().isEmpty ? "" : ", ${_e["emirate"]}"}"),
              _InfoRow(Icons.groups_rounded, cap > 0 ? "$count of $cap spots taken" : "$count going"),
              _InfoRow(Icons.verified_rounded, "Hosted by ${_e["organizer"] ?? "GreenifyX"}"),
              const SizedBox(height: 16),
              Text(_e["description"] ?? "", style: const TextStyle(fontSize: 15, height: 1.5)),
              if (loc is Map && loc["lat"] != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse("https://www.google.com/maps/search/?api=1&query=${loc["lat"]},${loc["lng"]}"),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.directions_rounded),
                  label: const Text("Get directions"),
                ),
              ],
            ]),
          ),
        ]),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: going
                ? OutlinedButton.icon(onPressed: _busy ? null : _rsvp, icon: const Icon(Icons.check_rounded), label: const Text("You're going · Cancel RSVP"))
                : FilledButton.icon(
                    onPressed: _busy || (cap > 0 && count >= cap) ? null : _rsvp,
                    icon: const Icon(Icons.event_available_rounded),
                    label: Text(cap > 0 && count >= cap ? "Event full" : "I'm going"),
                  ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Icon(icon, size: 20, color: AppColors.subtitle),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
        ]),
      );
}
