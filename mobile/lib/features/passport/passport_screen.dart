import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/i18n/app_locale.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/friendly_error.dart';
import '../post/domain/eco_activity.dart';

typedef Json = Map<String, dynamic>;

/// Impact passport: verified actions and volunteer hours, with a QR a school or employer can scan.
class PassportScreen extends StatefulWidget {
  const PassportScreen({super.key});

  @override
  State<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends State<PassportScreen> {
  Json? _d;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ApiService.dio.get("/passport");
      await EcoActivityApi.load();
      if (mounted) setState(() => _d = Json.from(r.data as Map));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _setPublic(bool v) async {
    try {
      await ApiService.dio.patch("/passport", data: {"public": v});
      setState(() => _d!["public"] = v);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  static const _icons = {"action": "🌱", "campaign": "🤝", "checkin": "📍", "recycling": "♻️"};

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final p = d == null ? null : Json.from(d["passport"] as Map);
    final t = p == null ? null : Json.from(p["totals"] as Map);
    final record = (p?["record"] as List? ?? []).map((e) => Json.from(e as Map)).toList();
    final shared = d?["public"] == true;
    return Scaffold(
      appBar: AppBar(title: Text(tr("Impact passport"))),
      body: p == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(colors: [Color(0xFF2B2440), Color(0xFF1F8A70)])),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(tr("IMPACT PASSPORT"), style: const TextStyle(color: Colors.white70, letterSpacing: 1.4, fontWeight: FontWeight.w800, fontSize: 12)),
                          const SizedBox(height: 6),
                          Text(p["name"].toString(), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                          if (p["verifiedResident"] == true)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(children: [
                                const Icon(Icons.verified_user_rounded, color: Colors.white, size: 16),
                                const SizedBox(width: 4),
                                Text(tr("UAE PASS verified resident"), style: const TextStyle(color: Colors.white)),
                              ]),
                            ),
                          const SizedBox(height: 6),
                          Text(p["code"].toString(), style: const TextStyle(color: Colors.white70, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: QrImageView(data: d!["verifyUrl"].toString(), size: 96, padding: EdgeInsets.zero),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      _Big("${t!["verifiedActions"]}", tr("verified actions")),
                      _Big("${t["volunteerHours"]}", tr("volunteer hours")),
                      _Big("${t["campaigns"]}", tr("campaigns")),
                    ]),
                  ]),
                ),
                const SizedBox(height: 12),
                Card(
                  child: SwitchListTile(
                    value: shared,
                    onChanged: _setPublic,
                    title: Text(tr("Let others check my passport"), style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(shared ? tr("Anyone with the QR or link can see your verified record.") : tr("Off: the QR shows nothing until you turn this on.")),
                  ),
                ),
                if (shared)
                  OutlinedButton.icon(
                    onPressed: () => SharePlus.instance.share(ShareParams(text: "${tr("My verified GreenifyX impact passport")}: ${d["verifyUrl"]}")),
                    icon: const Icon(Icons.ios_share_rounded),
                    label: Text(tr("Share passport link")),
                  ),
                const SizedBox(height: 16),
                Text(tr("Verified record"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                if (record.isEmpty) Text(tr("Your verified actions will appear here."), style: TextStyle(color: AppColors.subtitle)),
                for (final r in record)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Text(_icons[r["kind"]] ?? "🌱", style: const TextStyle(fontSize: 24)),
                    title: Text(r["kind"] == "action" ? activityName(r["title"].toString()) : r["title"].toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      "${DateFormat("d MMM yyyy").format(DateTime.tryParse(r["at"]?.toString() ?? "")?.toLocal() ?? DateTime.now())} · ${tr(r["method"].toString())}"
                      "${r["hours"] != null ? " · ${r["hours"]} h" : ""}",
                    ),
                  ),
                const SizedBox(height: 8),
                Text(tr(p["methodology"].toString()), style: TextStyle(color: AppColors.subtitle, fontSize: 12)),
              ]),
            ),
    );
  }
}

class _Big extends StatelessWidget {
  final String value;
  final String label;
  const _Big(this.value, this.label);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      );
}
