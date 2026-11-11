import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../../../core/services/api_service.dart';
import '../domain/campaign_model.dart';

class EvidenceShot {
  final File file;
  final String kind; // before | after | other
  const EvidenceShot(this.file, this.kind);
}

class ReportResult {
  final int distanceM;
  final bool withinGeofence;
  final List<String> flags;
  final String message;
  const ReportResult(this.distanceM, this.withinGeofence, this.flags, this.message);
}

class CampaignApi {
  Dio get _dio => ApiService.dio;

  List<Map<String, dynamic>> _list(dynamic v) =>
      (v as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  Future<List<CampaignModel>> list({String filter = 'open'}) async {
    final res = await _dio.get('/campaigns', queryParameters: {'filter': filter, 'limit': 50});
    return _list(res.data['campaigns']).map(CampaignModel.fromJson).toList();
  }

  Future<CampaignModel> get(String id) async {
    final res = await _dio.get('/campaigns/$id');
    return CampaignModel.fromJson(Map<String, dynamic>.from(res.data['campaign'] as Map));
  }

  Future<void> join(String id) => _dio.post('/campaigns/$id/join');

  Future<void> leave(String id) => _dio.delete('/campaigns/$id/join');

  Future<List<PointsEntry>> myPoints() async {
    final res = await _dio.get('/users/me/points', queryParameters: {'limit': 100});
    return _list(res.data['transactions']).map(PointsEntry.fromJson).toList();
  }

  Future<List<CampaignModel>> verifierCampaigns() async {
    final res = await _dio.get('/verifier/campaigns');
    return _list(res.data['campaigns']).map(CampaignModel.fromJson).toList();
  }

  Future<List<MyReport>> verifierReports() async {
    final res = await _dio.get('/verifier/reports');
    return _list(res.data['reports']).map(MyReport.fromJson).toList();
  }

  Future<ReportResult> submitReport({
    required String campaignId,
    required List<EvidenceShot> shots,
    required double lat,
    required double lng,
    double? accuracyM,
    bool mockLocation = false,
    required String outcome,
    required int outputCount,
    required List<String> species,
    required String notes,
    required List<String> attendeeIds,
  }) async {
    final form = FormData();
    for (final s in shots) {
      final name = s.file.path.split(Platform.pathSeparator).last;
      final lower = name.toLowerCase();
      final sub = lower.endsWith('.png')
          ? 'png'
          : lower.endsWith('.webp')
              ? 'webp'
              : lower.endsWith('.heic')
                  ? 'heic'
                  : 'jpeg';
      form.files.add(MapEntry(
        'photos',
        await MultipartFile.fromFile(s.file.path, filename: name, contentType: MediaType('image', sub)),
      ));
    }
    form.fields
      ..add(MapEntry('photoKinds', shots.map((s) => s.kind).join(',')))
      ..add(MapEntry('lat', lat.toString()))
      ..add(MapEntry('lng', lng.toString()))
      ..add(MapEntry('outcome', outcome))
      ..add(MapEntry('outputCount', outputCount.toString()))
      ..add(MapEntry('species', species.join(',')))
      ..add(MapEntry('notes', notes))
      ..add(MapEntry('attendees', attendeeIds.join(',')))
      ..add(MapEntry('mockLocation', mockLocation.toString()));
    if (accuracyM != null) form.fields.add(MapEntry('accuracyM', accuracyM.toStringAsFixed(0)));

    final res = await _dio.post(
      '/verifier/campaigns/$campaignId/reports',
      data: form,
      options: Options(sendTimeout: const Duration(minutes: 3), receiveTimeout: const Duration(minutes: 3)),
    );
    final r = Map<String, dynamic>.from(res.data['report'] as Map);
    return ReportResult(
      (r['distanceM'] as num?)?.toInt() ?? 0,
      r['withinGeofence'] == true,
      (r['flags'] as List? ?? const []).map((e) => e.toString()).toList(),
      res.data['message']?.toString() ?? 'Report submitted',
    );
  }
}
