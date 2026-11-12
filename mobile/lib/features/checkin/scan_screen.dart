import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/i18n/app_locale.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/friendly_error.dart';

/// Scan a GreenifyX QR at a recycling bin, refill station or event to check in.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<Position?> _position() async {
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)));
    } catch (_) {
      return null;
    }
  }

  Future<void> _onDetect(BarcodeCapture cap) async {
    if (_busy) return;
    final raw = cap.barcodes.isEmpty ? null : cap.barcodes.first.rawValue;
    if (raw == null) return;
    setState(() => _busy = true);
    await _controller.stop();
    String title;
    String body;
    bool ok;
    try {
      final pos = await _position();
      final r = await ApiService.dio.post("/checkins", data: {"code": raw, if (pos != null) "lat": pos.latitude, if (pos != null) "lng": pos.longitude});
      final cp = Map<String, dynamic>.from(r.data["checkpoint"] as Map);
      ok = true;
      title = "+${r.data["points"]} ${tr("Eco Points")}";
      body = "${tr("Checked in at")} ${cp["name"]}${(cp["partner"] ?? "").toString().isEmpty ? "" : " · ${cp["partner"]}"}";
    } catch (e) {
      ok = false;
      title = tr("Couldn't check in");
      body = friendlyError(e);
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded, size: 64, color: ok ? AppColors.eco : AppColors.error),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(body, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.subtitle, height: 1.4)),
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(tr("Done")))),
          ]),
        ),
      ),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => _busy = false);
      await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(tr("Scan QR check-in")),
        actions: [IconButton(onPressed: () => _controller.toggleTorch(), icon: const Icon(Icons.flash_on_rounded))],
      ),
      body: Stack(alignment: Alignment.center, children: [
        MobileScanner(controller: _controller, onDetect: _onDetect),
        Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white, width: 3)),
        ),
        Positioned(
          bottom: 60,
          left: 30,
          right: 30,
          child: Column(children: [
            if (_busy) const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 12),
            Text(tr("Point at the GreenifyX QR on a recycling bin, refill station or event board"),
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, height: 1.4)),
          ]),
        ),
      ]),
    );
  }
}
