import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config/app_config.dart';
import '../../core/i18n/app_locale.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/friendly_error.dart';
import '../wrapped/wrapped_screen.dart';
import '../passport/passport_screen.dart';

typedef Json = Map<String, dynamic>;

/// Verified impact totals and a shareable certificate with a QR anyone can check.
class ImpactScreen extends StatefulWidget {
  const ImpactScreen({super.key});

  @override
  State<ImpactScreen> createState() => _ImpactScreenState();
}

class _ImpactScreenState extends State<ImpactScreen> {
  Json? _d;
  Json? _cert;
  bool _issuing = false;
  final _cardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ApiService.dio.get("/impact/me");
      if (!mounted) return;
      setState(() {
        _d = Json.from(r.data as Map);
        final certs = (r.data["certificates"] as List? ?? []);
        if (certs.isNotEmpty) _cert = Json.from(certs.first as Map);
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _issue() async {
    setState(() => _issuing = true);
    try {
      final r = await ApiService.dio.post("/impact/certificate");
      setState(() => _cert = Json.from(r.data["certificate"] as Map));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _issuing = false);
    }
  }

  String get _verifyUrl => "${AppConfig.publicSiteUrl}/#/verify/${_cert?["code"]}";

  Future<void> _share() async {
    try {
      final boundary = _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await boundary.toImage(pixelRatio: 3);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final f = File("${dir.path}/greenifyx-impact-${_cert?["code"] ?? "card"}.png");
      await f.writeAsBytes(bytes!.buffer.asUint8List());
      await SharePlus.instance.share(ShareParams(
        files: [XFile(f.path)],
        text: "${tr("My verified environmental impact on GreenifyX")} 🌱\n${tr("Check it")}: $_verifyUrl",
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final t = d == null ? null : Json.from(d["total"] as Map);
    final m = d == null ? null : Json.from(d["month"] as Map);
    final stats = _cert == null ? t : Json.from(_cert!["stats"] as Map);
    return Scaffold(
      appBar: AppBar(title: Text(tr("My impact"))),
      body: d == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.95,
                children: [
                  _Tile("🌳", "${t!["treesPlanted"]}", tr("Trees")),
                  _Tile("♻️", "${t["wasteKg"]} kg", tr("Waste")),
                  _Tile("🌍", "${t["co2Kg"]} kg", "CO₂"),
                  _Tile("⏱️", "${t["volunteerHours"]} h", tr("Volunteer hours")),
                  _Tile("✅", "${t["verifiedActions"]}", tr("Verified actions")),
                  _Tile("⭐", "${t["ecoPoints"]}", tr("Eco Points")),
                ],
              ),
              const SizedBox(height: 10),
              Text("${tr("This month")}: ${m!["verifiedActions"]} ${tr("actions")} · ${m["co2Kg"]} kg CO₂ · ${m["wasteKg"]} kg ${tr("waste")}",
                  style: TextStyle(color: AppColors.subtitle, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Material(
                color: const Color(0xFF0E3B2E),
                borderRadius: BorderRadius.circular(18),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  leading: const Text("🎁", style: TextStyle(fontSize: 26)),
                  title: Text("${tr("Green Wrapped")} ${wrappedYear()}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  subtitle: Text(tr("Your year in green, ready to share"), style: const TextStyle(color: Colors.white70)),
                  trailing: const Icon(Icons.play_circle_fill_rounded, color: Colors.white),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WrappedScreen(year: wrappedYear()))),
                ),
              ),
              const SizedBox(height: 10),
              Material(
                color: const Color(0xFF2B2440),
                borderRadius: BorderRadius.circular(18),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  leading: const Icon(Icons.badge_rounded, color: Colors.white),
                  title: Text(tr("Impact passport"), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  subtitle: Text(tr("Verified actions and volunteer hours, with a QR for schools and employers"), style: const TextStyle(color: Colors.white70)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PassportScreen())),
                ),
              ),
              const SizedBox(height: 20),
              Text(tr("Impact certificate"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(tr("Add it to your CV, university application or company ESG report. Anyone can scan the QR to verify it."),
                  style: TextStyle(color: AppColors.subtitle, height: 1.4)),
              const SizedBox(height: 14),
              if (_cert == null)
                FilledButton.icon(
                  onPressed: _issuing ? null : _issue,
                  icon: const Icon(Icons.workspace_premium_rounded),
                  label: Text(tr("Generate my certificate")),
                )
              else ...[
                RepaintBoundary(key: _cardKey, child: _Certificate(cert: _cert!, stats: stats!, url: _verifyUrl)),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: FilledButton.icon(onPressed: _share, icon: const Icon(Icons.ios_share_rounded), label: Text(tr("Share")))),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton.icon(onPressed: _issuing ? null : _issue, icon: const Icon(Icons.refresh_rounded), label: Text(tr("Update")))),
                ]),
              ],
            ]),
    );
  }
}

class _Tile extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  const _Tile(this.emoji, this.value, this.label);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          Text(label, textAlign: TextAlign.center, style: TextStyle(color: AppColors.subtitle, fontSize: 11.5)),
        ]),
      );
}

class _Certificate extends StatelessWidget {
  final Json cert;
  final Json stats;
  final String url;
  const _Certificate({required this.cert, required this.stats, required this.url});

  @override
  Widget build(BuildContext context) {
    final issued = DateTime.tryParse(cert["createdAt"]?.toString() ?? "")?.toLocal() ?? DateTime.now();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD9B45A), width: 2),
        boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 20, offset: Offset(0, 8))],
      ),
      child: Column(children: [
        Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset("assets/brand/app_icon_rounded.png", width: 36, height: 36)),
          const SizedBox(width: 10),
          Text("GreenifyX", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.ink)),
          const Spacer(),
          const Icon(Icons.workspace_premium_rounded, color: Color(0xFFD9B45A), size: 30),
        ]),
        const SizedBox(height: 16),
        Text(tr("CERTIFICATE OF VERIFIED IMPACT"), textAlign: TextAlign.center, style: const TextStyle(letterSpacing: 1.6, fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF9A7B2F))),
        const SizedBox(height: 10),
        Text(cert["name"]?.toString() ?? "", textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.ink)),
        const SizedBox(height: 6),
        Text(tr("has taken part in verified environmental action in the UAE"), textAlign: TextAlign.center, style: TextStyle(color: AppColors.subtitle)),
        const SizedBox(height: 16),
        Wrap(alignment: WrapAlignment.center, spacing: 18, runSpacing: 10, children: [
          _Stat("${stats["verifiedActions"]}", tr("actions")),
          _Stat("${stats["volunteerHours"]} h", tr("volunteering")),
          _Stat("${stats["treesPlanted"]}", tr("trees")),
          _Stat("${stats["wasteKg"]} kg", tr("waste")),
          _Stat("${stats["co2Kg"]} kg", "CO₂"),
        ]),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("${tr("Issued")} ${DateFormat("d MMM yyyy").format(issued)}", style: TextStyle(fontSize: 12, color: AppColors.subtitle)),
              Text(cert["code"]?.toString() ?? "", style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
              Text(tr("Scan to verify"), style: TextStyle(fontSize: 11, color: AppColors.subtitle)),
            ]),
          ),
          QrImageView(data: url, size: 84, padding: EdgeInsets.zero, eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.ink)),
        ]),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat(this.value, this.label);
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.eco)),
        Text(label, style: TextStyle(fontSize: 11.5, color: AppColors.subtitle)),
      ]);
}
