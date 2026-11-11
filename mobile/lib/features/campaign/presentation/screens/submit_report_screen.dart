import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/friendly_error.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../application/campaign_providers.dart';
import '../../data/campaign_api.dart';
import '../../domain/campaign_model.dart';

const _flagText = {
  'outside_geofence': 'You were outside the approved site area',
  'outside_campaign_dates': 'Submitted outside the campaign dates',
  'low_gps_accuracy': 'GPS signal was weak',
  'duplicate_photo': 'A photo matches an earlier report',
  'output_above_target': 'Count is well above the target',
  'no_after_photo': 'No "after" photo attached',
  'mock_location': 'Device reported a simulated location',
};

class SubmitReportScreen extends ConsumerStatefulWidget {
  final CampaignModel campaign;
  const SubmitReportScreen({super.key, required this.campaign});

  @override
  ConsumerState<SubmitReportScreen> createState() => _SubmitReportScreenState();
}

class _SubmitReportScreenState extends ConsumerState<SubmitReportScreen> {
  final _count = TextEditingController();
  final _species = TextEditingController();
  final _notes = TextEditingController();
  final List<EvidenceShot> _shots = [];
  late final Set<String> _attendees = {
    for (final p in widget.campaign.participants)
      if (p.status == "joined") p.id,
  };
  String _outcome = "completed";
  Position? _position;
  bool _locating = false;
  String? _locationError;
  bool _submitting = false;

  CampaignModel get c => widget.campaign;
  bool get _isPlanting => c.category == "Tree Plantation" || c.category == "Mangrove Restoration";

  @override
  void initState() {
    super.initState();
    if (_isPlanting && c.category == "Mangrove Restoration") _species.text = "Grey mangrove (Avicennia marina)";
    if (_isPlanting && c.category == "Tree Plantation") _species.text = "Ghaf (Prosopis cineraria)";
    WidgetsBinding.instance.addPostFrameCallback((_) => _locate());
  }

  @override
  void dispose() {
    _count.dispose();
    _species.dispose();
    _notes.dispose();
    super.dispose();
  }

  double? get _distance => _position == null
      ? null
      : Geolocator.distanceBetween(_position!.latitude, _position!.longitude, c.lat, c.lng);

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw "Turn on location services to continue.";
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw "Location permission is needed to verify you are on site.";
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 25)),
      );
      if (mounted) setState(() => _position = pos);
    } catch (e) {
      if (mounted) setState(() => _locationError = e is String ? e : "Could not get your location. Move to open sky and try again.");
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _capture(String kind) async {
    if (_shots.length >= 6) return;
    final shot = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (shot != null) setState(() => _shots.add(EvidenceShot(File(shot.path), kind)));
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_position == null) {
      messenger.showSnackBar(const SnackBar(content: Text("Get your GPS location first")));
      return;
    }
    if (_shots.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text("Take at least one photo on site")));
      return;
    }
    if (_outcome != "unsuccessful" && _attendees.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text("Select the volunteers who attended")));
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await ref.read(campaignApiProvider).submitReport(
            campaignId: c.id,
            shots: _shots,
            lat: _position!.latitude,
            lng: _position!.longitude,
            accuracyM: _position!.accuracy,
            mockLocation: _position!.isMocked,
            outcome: _outcome,
            outputCount: int.tryParse(_count.text.trim()) ?? 0,
            species: _species.text.split(",").map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
            notes: _notes.text.trim(),
            attendeeIds: _outcome == "unsuccessful" ? const [] : _attendees.toList(),
          );
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (_) => _ResultDialog(result: result));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e, fallback: "Upload failed. Check your connection and try again."))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eligible = c.participants.where((p) => p.status != "verified").toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text("Field report", style: AppTextStyles.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Text(c.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 4),
          Text(c.locationName, style: const TextStyle(color: AppColors.subtitle)),
          _step(1, "Confirm you're on site"),
          _LocationCard(
            locating: _locating,
            error: _locationError,
            position: _position,
            distance: _distance,
            radius: c.geofenceRadiusM,
            onRetry: _locate,
          ),
          _step(2, "Capture evidence"),
          const Text(
            "Use the camera in the app. Gallery photos are not accepted as proof.",
            style: TextStyle(color: AppColors.subtitle, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _ShotButton(label: "Before", icon: Icons.photo_camera_back_rounded, onTap: () => _capture("before"))),
            const SizedBox(width: 8),
            Expanded(child: _ShotButton(label: "After", icon: Icons.photo_camera_rounded, onTap: () => _capture("after"))),
            const SizedBox(width: 8),
            Expanded(child: _ShotButton(label: "Extra", icon: Icons.add_a_photo_outlined, onTap: () => _capture("other"))),
          ]),
          if (_shots.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _shots.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _Thumb(shot: _shots[i], onRemove: () => setState(() => _shots.removeAt(i))),
              ),
            ),
          ],
          _step(3, "Record the outcome"),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: "completed", label: Text("Completed")),
              ButtonSegment(value: "partial", label: Text("Partial")),
              ButtonSegment(value: "unsuccessful", label: Text("Didn't happen")),
            ],
            selected: {_outcome},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _outcome = s.first),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _count,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: "Actual ${c.outputUnit} recorded",
              helperText: c.targetOutput > 0 ? "Campaign target: ${c.targetOutput} ${c.outputUnit}" : null,
              prefixIcon: const Icon(Icons.tag_rounded),
            ),
          ),
          if (_isPlanting) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _species,
              decoration: const InputDecoration(
                labelText: "Species planted",
                helperText: "Separate with commas",
                prefixIcon: Icon(Icons.park_rounded),
              ),
            ),
          ],
          if (_outcome != "unsuccessful") ...[
            _step(4, "Check in volunteers"),
            if (eligible.isEmpty)
              const Text("No registered volunteers to check in.", style: TextStyle(color: AppColors.subtitle))
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(children: [
                  CheckboxListTile(
                    value: _attendees.length == eligible.length,
                    onChanged: (on) => setState(() {
                      _attendees.clear();
                      if (on == true) _attendees.addAll(eligible.map((p) => p.id));
                    }),
                    title: Text("All present (${_attendees.length}/${eligible.length})",
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const Divider(height: 1),
                  for (final p in eligible)
                    CheckboxListTile(
                      value: _attendees.contains(p.id),
                      onChanged: (on) => setState(() => on == true ? _attendees.add(p.id) : _attendees.remove(p.id)),
                      secondary: UserAvatar(imageUrl: p.profileImage, radius: 16),
                      title: Text(p.name),
                      subtitle: p.status == "attended" ? const Text("Already in an earlier report") : null,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                ]),
              ),
          ],
          _step(_outcome == "unsuccessful" ? 4 : 5, "Notes"),
          TextField(
            controller: _notes,
            maxLines: 3,
            maxLength: 2000,
            decoration: const InputDecoration(hintText: "Conditions, issues, anything the reviewer should know"),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cloud_upload_rounded),
              label: Text(_submitting ? "Uploading evidence…" : "Submit report"),
            ),
          ),
        ),
      ),
    );
  }

  Widget _step(int n, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 24, 0, 10),
        child: Row(children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: Text("$n", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
        ]),
      );
}

class _LocationCard extends StatelessWidget {
  final bool locating;
  final String? error;
  final Position? position;
  final double? distance;
  final int radius;
  final VoidCallback onRetry;

  const _LocationCard({
    required this.locating,
    required this.error,
    required this.position,
    required this.distance,
    required this.radius,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final inside = distance != null && distance! <= radius;
    final color = locating || position == null
        ? AppColors.subtitle
        : inside
            ? AppColors.eco
            : AppColors.error;
    final title = locating
        ? "Finding your location…"
        : error != null
            ? "Location unavailable"
            : position == null
                ? "Location needed"
                : inside
                    ? "You're on site"
                    : "You're outside the site area";
    final subtitle = error ??
        (position == null
            ? "We check your GPS against the approved site."
            : "${distance!.round()} m from the site centre (allowed: $radius m) · accuracy ±${position!.accuracy.round()} m");

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        locating
            ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.4))
            : Icon(inside ? Icons.where_to_vote_rounded : Icons.location_searching_rounded, color: color, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.subtitle, height: 1.35)),
            if (position?.isMocked == true)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text("Simulated location detected. The report will be flagged.",
                    style: TextStyle(fontSize: 12.5, color: AppColors.error, fontWeight: FontWeight.w700)),
              ),
          ]),
        ),
        if (!locating) IconButton(tooltip: "Refresh location", onPressed: onRetry, icon: const Icon(Icons.refresh_rounded)),
      ]),
    );
  }
}

class _ShotButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ShotButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
          child: Column(children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
          ]),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final EvidenceShot shot;
  final VoidCallback onRemove;
  const _Thumb({required this.shot, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.file(shot.file, width: 96, height: 96, fit: BoxFit.cover),
      ),
      Positioned(
        left: 6,
        bottom: 6,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: AppColors.ink.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(6)),
          child: Text(shot.kind.toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ),
      ),
      Positioned(
        right: 2,
        top: 2,
        child: GestureDetector(
          onTap: onRemove,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.close_rounded, size: 16, color: AppColors.ink),
          ),
        ),
      ),
    ]);
  }
}

class _ResultDialog extends StatelessWidget {
  final ReportResult result;
  const _ResultDialog({required this.result});

  @override
  Widget build(BuildContext context) {
    final clean = result.flags.isEmpty;
    return AlertDialog(
      icon: Icon(clean ? Icons.task_alt_rounded : Icons.flag_rounded, color: clean ? AppColors.eco : const Color(0xFF8A5A00), size: 40),
      title: Text(clean ? "Report submitted" : "Submitted for extra review"),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          "Recorded ${result.distanceM} m from the site (${result.withinGeofence ? 'inside' : 'outside'} the approved area). "
          "An admin will review it before Eco Points are credited.",
          style: const TextStyle(height: 1.45),
        ),
        if (!clean) ...[
          const SizedBox(height: 12),
          for (final f in result.flags)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.error),
                const SizedBox(width: 6),
                Expanded(child: Text(_flagText[f] ?? f, style: const TextStyle(fontSize: 13))),
              ]),
            ),
        ],
      ]),
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text("Done"))],
    );
  }
}
