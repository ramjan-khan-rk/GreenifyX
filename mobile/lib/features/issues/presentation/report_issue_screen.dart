import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/emirates.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/friendly_error.dart';
import '../../profile/application/providers/my_profile_provider.dart';
import '../data/issue_api.dart';
import 'issue_widgets.dart';
import 'package:greenifyx/core/i18n/app_locale.dart';

class ReportIssueScreen extends ConsumerStatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  ConsumerState<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends ConsumerState<ReportIssueScreen> {
  final _landmark = TextEditingController();
  final _description = TextEditingController();
  final List<File> _photos = [];
  String? _category;
  String _emirate = "";
  Position? _position;
  bool _locating = false;
  String? _locationError;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _emirate = ref.read(myProfileProvider).maybeWhen(data: (p) => p.emirate, orElse: () => "");
    WidgetsBinding.instance.addPostFrameCallback((_) => _locate());
  }

  @override
  void dispose() {
    _landmark.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw "Turn on location services.";
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
        throw "Location permission is needed to pin the problem.";
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
      );
      if (mounted) setState(() => _position = pos);
    } catch (e) {
      if (mounted) setState(() => _locationError = e is String ? e : "Could not get your location. Try again.");
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _photo() async {
    if (_photos.length >= 3) return;
    final shot = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 1600);
    if (shot != null) setState(() => _photos.add(File(shot.path)));
  }

  Future<void> _send() async {
    final messenger = ScaffoldMessenger.of(context);
    String? problem;
    if (_photos.isEmpty) problem = "Take a photo of the problem";
    if (_category == null) problem ??= "Choose what kind of problem it is";
    if (_position == null) problem ??= "We need your location to pin the problem";
    if (problem != null) {
      messenger.showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    setState(() => _sending = true);
    try {
      final message = await ref.read(issueApiProvider).submit(
            photos: _photos,
            category: _category!,
            description: _description.text.trim(),
            landmark: _landmark.text.trim(),
            emirate: _emirate,
            lat: _position!.latitude,
            lng: _position!.longitude,
            accuracyM: _position!.accuracy,
          );
      ref.invalidate(myIssuesProvider);
      ref.invalidate(nearbyIssuesProvider);
      messenger.showSnackBar(SnackBar(content: Text(message)));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e, fallback: "Could not send. Check your connection."))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(tr("Report a problem"), style: AppTextStyles.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          Text(tr("What did you see?"), style: AppTextStyles.title.copyWith(fontSize: 17)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.05,
            children: [
              for (final (name, icon) in issueCategories)
                _CategoryTile(
                  name: name,
                  icon: icon,
                  selected: _category == name,
                  onTap: () => setState(() => _category = name),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Text(tr("Photo"), style: AppTextStyles.title.copyWith(fontSize: 17)),
          const SizedBox(height: 4),
          Text(tr("Taken now with the camera. Up to 3."), style: TextStyle(color: AppColors.subtitle, fontSize: 13)),
          const SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (var i = 0; i < _photos.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(_photos[i], width: 100, height: 100, fit: BoxFit.cover),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _photos.removeAt(i)),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, size: 16),
                        ),
                      ),
                    ),
                  ]),
                ),
              if (_photos.length < 3)
                InkWell(
                  onTap: _photo,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.photo_camera_rounded, color: AppColors.primary, size: 28),
                      SizedBox(height: 4),
                      Text(tr("Add photo"), style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12.5)),
                    ]),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 22),
          Text(tr("Where is it?"), style: AppTextStyles.title.copyWith(fontSize: 17)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _position != null ? AppColors.eco.withValues(alpha: 0.5) : AppColors.border),
            ),
            child: Row(children: [
              _locating
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))
                  : Icon(_position != null ? Icons.where_to_vote_rounded : Icons.location_off_rounded,
                      color: _position != null ? AppColors.eco : AppColors.subtitle),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _locating
                      ? "Pinning your location…"
                      : _locationError ??
                          (_position == null
                              ? "Location not set"
                              : "Pinned within ±${_position!.accuracy.round()} m of where you are"),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (!_locating) IconButton(onPressed: _locate, icon: const Icon(Icons.my_location_rounded), tooltip: tr("Use my location")),
            ]),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _landmark,
            maxLength: 160,
            decoration: InputDecoration(
              labelText: tr("Nearby landmark (optional)"),
              hintText: tr("e.g. behind the community mosque"),
              prefixIcon: Icon(Icons.signpost_rounded),
            ),
          ),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in kEmirates)
              ChoiceChip(
                label: Text(e),
                selected: _emirate == e,
                selectedColor: AppColors.primary.withValues(alpha: 0.16),
                side: BorderSide(color: _emirate == e ? AppColors.primary : AppColors.border),
                onSelected: (_) => setState(() => _emirate = e),
              ),
          ]),
          const SizedBox(height: 18),
          TextField(
            controller: _description,
            maxLines: 3,
            maxLength: 1000,
            decoration: InputDecoration(labelText: tr("Details (optional)"), hintText: tr("How big is it? How long has it been there?")),
          ),
          const SizedBox(height: 6),
          Text(
            tr("Your report goes to the GreenifyX team for review. We'll update you at every step, and you earn Eco Points when it's resolved."),
            style: TextStyle(color: AppColors.subtitle, fontSize: 12.5, height: 1.45),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
              label: Text(_sending ? "Sending…" : "Send report"),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String name;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryTile({required this.name, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: selected ? Colors.white : AppColors.primary, size: 28),
            const SizedBox(height: 6),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.ink,
                height: 1.2,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
