import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/friendly_error.dart';
import 'assistant_api.dart';
import 'assistant_cards.dart';
import 'package:greenifyx/core/i18n/app_locale.dart';

class SnapSortScreen extends StatefulWidget {
  const SnapSortScreen({super.key});

  @override
  State<SnapSortScreen> createState() => _SnapSortScreenState();
}

class _SnapSortScreenState extends State<SnapSortScreen> {
  final _api = AssistantApi();
  File? _photo;
  bool _busy = false;
  SnapOutcome? _outcome;
  List<Map<String, dynamic>>? _manualItems;
  String? _error;

  Future<void> _shoot() async {
    final shot = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1280);
    if (shot == null) return;
    setState(() {
      _photo = File(shot.path);
      _busy = true;
      _outcome = null;
      _manualItems = null;
      _error = null;
    });
    try {
      final at = await quietPosition();
      final out = await _api.snap(_photo!, at: at);
      if (!out.aiAvailable || out.result == null) {
        final items = await _api.guideItems();
        if (mounted) setState(() => _manualItems = items);
      } else if (mounted) {
        setState(() => _outcome = out);
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e, fallback: "Couldn't analyse the photo. Try again."));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick(String key) async {
    setState(() => _busy = true);
    try {
      final out = await _api.guide(key, at: await quietPosition());
      if (mounted) setState(() => _outcome = out);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _outcome?.result;
    final confidence = (result?["confidence"] as num?)?.toDouble();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(tr("Snap & Sort"), style: AppTextStyles.title)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 120), children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(fit: StackFit.expand, children: [
              if (_photo != null)
                Image.file(_photo!, fit: BoxFit.cover)
              else
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.ink, Color(0xFF3A3256)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.camera_alt_rounded, color: AppColors.sun, size: 48),
                    SizedBox(height: 10),
                    Text(tr("Point at a bottle, battery, box…"), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text(tr("We'll tell you which bin and where to drop it"), style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 12.5)),
                  ]),
                ),
              if (_busy)
                Container(
                  color: Colors.black45,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text(tr("Identifying…"), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ]),
                ),
            ]),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
        ],
        if (result != null) ...[
          const SizedBox(height: 14),
          if (confidence != null && confidence > 0)
            Row(children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: confidence >= 0.6 ? AppColors.eco : const Color(0xFFB07A00)),
              const SizedBox(width: 6),
              Text(
                confidence >= 0.6 ? "Identified as ${result["item"]}" : "Best guess: ${result["item"]}. Check before sorting.",
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ]),
          GuideCard(data: result),
          if (_outcome!.places.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(tr("Where to take it"), style: AppTextStyles.title.copyWith(fontSize: 17)),
            for (final p in _outcome!.places) AssistantCard(card: p),
          ],
        ],
        if (_manualItems != null && result == null) ...[
          const SizedBox(height: 16),
          Text(tr("What is it?"), style: AppTextStyles.title.copyWith(fontSize: 17)),
          const SizedBox(height: 4),
          Text(tr("Pick the closest match and we'll show how to sort it."), style: TextStyle(color: AppColors.subtitle)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final item in _manualItems!)
              ActionChip(
                avatar: CircleAvatar(backgroundColor: hexColor(item["binColor"]?.toString()), radius: 6),
                label: Text(item["name"]?.toString() ?? ""),
                backgroundColor: Colors.white,
                side: BorderSide(color: AppColors.border),
                onPressed: _busy ? null : () => _pick(item["key"].toString()),
              ),
          ]),
        ],
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _shoot,
              icon: const Icon(Icons.camera_alt_rounded),
              label: Text(_photo == null ? "Take a photo" : "Scan another item"),
            ),
          ),
        ),
      ),
    );
  }
}
