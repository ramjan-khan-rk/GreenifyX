import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/i18n/app_locale.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/friendly_error.dart';

typedef Json = Map<String, dynamic>;

const _providers = ["DEWA", "ADDC", "AADC", "SEWA", "Etihad WE", "Other"];

/// Utility bill scan: snap a DEWA / ADDC / SEWA bill, track electricity and water month by month.
class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  List<Json>? _bills;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _toast(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Future<void> _load() async {
    try {
      final r = await ApiService.dio.get("/bills");
      if (mounted) setState(() => _bills = (r.data["bills"] as List).map((e) => Json.from(e as Map)).toList());
    } catch (e) {
      if (mounted) {
        setState(() => _bills = []);
        _toast(friendlyError(e));
      }
    }
  }

  Future<void> _scan(ImageSource source) async {
    final x = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 2200);
    if (x == null) return;
    setState(() => _busy = true);
    try {
      final form = FormData.fromMap({
        "photo": await MultipartFile.fromFile(x.path, filename: x.name, contentType: MediaType("image", "jpeg")),
      });
      final r = await ApiService.dio.post("/bills/scan",
          data: form, options: Options(sendTimeout: const Duration(minutes: 1), receiveTimeout: const Duration(minutes: 1)));
      if (!mounted) return;
      if (r.data["aiAvailable"] != true) {
        _toast(tr("We couldn't read it automatically. Type the numbers in instead."));
        await _openForm(null, null);
      } else {
        await _openForm(Json.from(r.data["bill"] as Map), r.data["scanId"]?.toString());
      }
    } catch (e) {
      _toast(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Json b) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr("Delete this bill?")),
        content: Text("${b["provider"]} · ${b["month"]}"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr("Cancel"))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr("Delete"))),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await ApiService.dio.delete("/bills/${b["_id"]}");
      _toast(tr("Bill deleted"));
      _load();
    } catch (e) {
      _toast(friendlyError(e));
    }
  }

  Future<void> _openForm(Json? bill, String? scanId) async {
    final saved = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BillForm(bill: bill, scanId: scanId),
    );
    if (saved == null) return;
    _toast(saved > 0 ? "+$saved ${tr("Eco Points for using less")} 🎉" : tr("Bill saved"));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final bills = _bills;
    return Scaffold(
      appBar: AppBar(title: Text(tr("My bills"))),
      body: bills == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), gradient: const LinearGradient(colors: [Color(0xFF0083B0), Color(0xFF00B4DB)])),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("⚡ 💧", style: TextStyle(fontSize: 30)),
                    const SizedBox(height: 8),
                    Text(tr("Use less, earn more"), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(
                      tr("Snap your DEWA, ADDC, SEWA or Etihad WE bill each month. Use less than last month and earn up to 80 Eco Points. Points need a photo of the bill."),
                      style: const TextStyle(color: Colors.white, height: 1.4),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _scan(ImageSource.camera),
                      icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.document_scanner_rounded),
                      label: Text(_busy ? tr("Reading…") : tr("Scan a bill")),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(onPressed: _busy ? null : () => _scan(ImageSource.gallery), icon: const Icon(Icons.photo_library_rounded), tooltip: tr("From photos")),
                  IconButton.outlined(onPressed: _busy ? null : () => _openForm(null, null), icon: const Icon(Icons.edit_rounded), tooltip: tr("Type it in")),
                ]),
                if (bills.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text(tr("Electricity"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  _Bars(bills: bills, field: "electricityKwh", unit: "kWh", color: AppColors.sun),
                  const SizedBox(height: 18),
                  Text(tr("Water"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  _Bars(bills: bills, field: "waterLitres", unit: "L", color: const Color(0xFF00B4DB)),
                  const SizedBox(height: 18),
                  for (final b in bills) _BillTile(b: b, onDelete: b["source"] == "manual" ? () => _delete(b) : null),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 30),
                    child: Text(tr("No bills yet. Scan your latest one to set your starting point."), textAlign: TextAlign.center, style: TextStyle(color: AppColors.subtitle)),
                  ),
              ]),
            ),
    );
  }
}

class _Bars extends StatelessWidget {
  final List<Json> bills;
  final String field;
  final String unit;
  final Color color;
  const _Bars({required this.bills, required this.field, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) {
    final rows = bills.where((b) => (b[field] ?? 0) > 0).take(6).toList().reversed.toList();
    if (rows.isEmpty) return Text(tr("No readings yet"), style: TextStyle(color: AppColors.subtitle));
    final max = rows.map((b) => (b[field] as num).toDouble()).reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: 150,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final b in rows)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text("${(b[field] as num).round()}", style: TextStyle(fontSize: 10.5, color: AppColors.subtitle)),
                const SizedBox(height: 4),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: (b[field] as num) / max),
                  duration: const Duration(milliseconds: 700),
                  builder: (_, v, _) => Container(height: 100 * v + 2, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8))),
                ),
                const SizedBox(height: 6),
                Text(b["month"].toString().substring(2), style: TextStyle(fontSize: 11, color: AppColors.subtitle)),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _BillTile extends StatelessWidget {
  final Json b;
  /// Only typed-in bills can be deleted (photo bills earned points).
  final VoidCallback? onDelete;
  const _BillTile({required this.b, this.onDelete});

  Widget _change(num? pct) {
    if (pct == null) return const SizedBox.shrink();
    final down = pct < 0;
    return Text("${down ? "▼" : "▲"} ${pct.abs()}%", style: TextStyle(color: down ? AppColors.eco : AppColors.error, fontWeight: FontWeight.w800, fontSize: 12));
  }

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: CircleAvatar(backgroundColor: AppColors.surfaceAlt, child: Text(b["source"] == "ai" ? "📷" : "✍️")),
          title: Text("${b["provider"]} · ${b["month"]}", style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Text("⚡ ${b["electricityKwh"]} kWh  "), _change(b["electricityChange"] as num?)]),
            Row(children: [Text("💧 ${b["waterLitres"]} L  "), _change(b["waterChange"] as num?)]),
            Text("≈ ${b["co2Kg"]} kg CO₂", style: TextStyle(fontSize: 12, color: AppColors.subtitle)),
          ]),
          trailing: (b["points"] ?? 0) > 0
              ? Text("+${b["points"]}", style: const TextStyle(color: AppColors.eco, fontWeight: FontWeight.w900, fontSize: 16))
              : (onDelete != null ? IconButton(tooltip: tr("Delete"), icon: const Icon(Icons.delete_outline_rounded), onPressed: onDelete) : null),
        ),
      );
}

class _BillForm extends StatefulWidget {
  final Json? bill;
  final String? scanId;
  const _BillForm({this.bill, this.scanId});

  @override
  State<_BillForm> createState() => _BillFormState();
}

class _BillFormState extends State<_BillForm> {
  late String _provider = _providers.contains(widget.bill?["provider"]) ? widget.bill!["provider"] as String : "DEWA";
  late final _month = TextEditingController(text: widget.bill?["month"]?.toString() ?? _lastMonth());
  late final _kwh = TextEditingController(text: _num(widget.bill?["electricityKwh"]));
  late final _water = TextEditingController(text: _num(widget.bill?["waterLitres"]));
  late final _aed = TextEditingController(text: _num(widget.bill?["amountAed"]));
  bool _saving = false;

  static String _num(dynamic v) => v == null || v == 0 ? "" : v.toString();
  static String _lastMonth() {
    final n = DateTime.now();
    final d = DateTime(n.year, n.month - 1);
    return "${d.year}-${d.month.toString().padLeft(2, "0")}";
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final r = await ApiService.dio.post("/bills", data: {
        if (widget.scanId != null) "scanId": widget.scanId,
        "provider": _provider,
        "month": _month.text.trim(),
        "electricityKwh": double.tryParse(_kwh.text.trim()) ?? 0,
        "waterLitres": double.tryParse(_water.text.trim()) ?? 0,
        "amountAed": double.tryParse(_aed.text.trim()) ?? 0,
      });
      if (mounted) Navigator.pop(context, (r.data["points"] as num?)?.toInt() ?? 0);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.viewInsetsOf(context).bottom + 18),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.scanId != null ? tr("Check what we read") : tr("Add a bill"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          if (widget.scanId != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(tr("Changing the numbers turns this into a typed-in bill, which is tracked but earns no points."),
                  style: TextStyle(color: AppColors.subtitle, fontSize: 12.5)),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _provider,
            decoration: InputDecoration(labelText: tr("Provider")),
            items: [for (final p in _providers) DropdownMenuItem(value: p, child: Text(p == "Other" ? tr("Other") : p))],
            onChanged: (v) => setState(() => _provider = v ?? _provider),
          ),
          const SizedBox(height: 10),
          TextField(controller: _month, decoration: InputDecoration(labelText: tr("Month (YYYY-MM)"))),
          const SizedBox(height: 10),
          TextField(controller: _kwh, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: tr("Electricity (kWh)"))),
          const SizedBox(height: 10),
          TextField(controller: _water, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: tr("Water (litres)"))),
          const SizedBox(height: 10),
          TextField(controller: _aed, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: tr("Amount (AED, optional)"))),
          const SizedBox(height: 16),
          FilledButton(onPressed: _saving ? null : _save, child: Text(tr("Save bill"))),
        ]),
      );
}
