DateTime _date(dynamic v) => DateTime.tryParse(v?.toString() ?? '')?.toLocal() ?? DateTime.now();
int _int(dynamic v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
double _dbl(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
String _str(dynamic v) => v?.toString() ?? '';

class PersonRef {
  final String id;
  final String name;
  final String profileImage;
  final String status;

  const PersonRef({required this.id, required this.name, this.profileImage = '', this.status = ''});

  factory PersonRef.fromJson(Map<String, dynamic> j) => PersonRef(
        id: _str(j['_id']),
        name: _str(j['name']),
        profileImage: _str(j['profileImage']),
        status: _str(j['status']),
      );
}

class EvidencePhoto {
  final String url;
  final String kind;
  const EvidencePhoto(this.url, this.kind);
}

class SurvivalCheck {
  final int days;
  final int surviving;
  const SurvivalCheck(this.days, this.surviving);
}

class CampaignModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String organiserName;
  final String organizationName;
  final bool organizationVerified;
  final String emirate;
  final String locationName;
  final double lat;
  final double lng;
  final int geofenceRadiusM;
  final String permitReference;
  final String requirements;
  final DateTime startDate;
  final DateTime endDate;
  final int targetParticipants;
  final int targetOutput;
  final String outputUnit;
  final int pointsPerParticipant;
  final String coverImage;
  final String status;

  /// live | upcoming | ended | completed | cancelled | draft
  final String phase;
  final int verifiedOutput;
  final int participantCount;
  final bool joined;
  final String? myStatus;
  final bool canJoin;

  final List<PersonRef> verifiers;
  final List<EvidencePhoto> evidence;
  final List<SurvivalCheck> survivalChecks;

  // Verifier-only fields
  final List<PersonRef> participants;
  final int myReports;
  final int myPendingReports;

  const CampaignModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.organiserName,
    this.organizationName = '',
    this.organizationVerified = false,
    required this.emirate,
    required this.locationName,
    required this.lat,
    required this.lng,
    required this.geofenceRadiusM,
    required this.permitReference,
    required this.requirements,
    required this.startDate,
    required this.endDate,
    required this.targetParticipants,
    required this.targetOutput,
    required this.outputUnit,
    required this.pointsPerParticipant,
    required this.coverImage,
    required this.status,
    required this.phase,
    required this.verifiedOutput,
    required this.participantCount,
    required this.joined,
    required this.myStatus,
    required this.canJoin,
    this.verifiers = const [],
    this.evidence = const [],
    this.survivalChecks = const [],
    this.participants = const [],
    this.myReports = 0,
    this.myPendingReports = 0,
  });

  factory CampaignModel.fromJson(Map<String, dynamic> j) {
    final loc = (j['location'] as Map?) ?? const {};
    List<PersonRef> people(dynamic v) => (v as List? ?? const [])
        .whereType<Map>()
        .map((e) => PersonRef.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final evidence = <EvidencePhoto>[];
    for (final r in (j['verifiedEvidence'] as List? ?? const []).whereType<Map>()) {
      for (final p in (r['photos'] as List? ?? const []).whereType<Map>()) {
        evidence.add(EvidencePhoto(_str(p['url']), _str(p['kind'])));
      }
    }
    return CampaignModel(
      id: _str(j['_id']),
      title: _str(j['title']),
      description: _str(j['description']),
      category: _str(j['category']),
      organiserName: _str(j['organiserName']),
      organizationName: _str((j['organization'] as Map?)?['name']),
      organizationVerified: (j['organization'] as Map?)?['verified'] == true,
      emirate: _str(j['emirate']),
      locationName: _str(j['locationName']),
      lat: _dbl(loc['lat']),
      lng: _dbl(loc['lng']),
      geofenceRadiusM: _int(j['geofenceRadiusM']),
      permitReference: _str(j['permitReference']),
      requirements: _str(j['requirements']),
      startDate: _date(j['startDate']),
      endDate: _date(j['endDate']),
      targetParticipants: _int(j['targetParticipants']),
      targetOutput: _int(j['targetOutput']),
      outputUnit: _str(j['outputUnit']),
      pointsPerParticipant: _int(j['pointsPerParticipant']),
      coverImage: _str(j['coverImage']),
      status: _str(j['status']),
      phase: _str(j['phase']),
      verifiedOutput: _int(j['verifiedOutput']),
      participantCount: _int(j['participantCount']),
      joined: j['joined'] == true,
      myStatus: j['myStatus'] as String?,
      canJoin: j['canJoin'] == true,
      verifiers: people(j['verifiers']),
      evidence: evidence,
      survivalChecks: (j['survivalChecks'] as List? ?? const [])
          .whereType<Map>()
          .map((s) => SurvivalCheck(_int(s['checkpointDays']), _int(s['surviving'])))
          .toList(),
      participants: people(j['participants']),
      myReports: _int(j['myReports']),
      myPendingReports: _int(j['myPendingReports']),
    );
  }

  double get participantProgress => targetParticipants == 0 ? 0 : (participantCount / targetParticipants).clamp(0, 1).toDouble();
  double get outputProgress => targetOutput == 0 ? 0 : (verifiedOutput / targetOutput).clamp(0, 1).toDouble();
  bool get isPlanting => category == 'Tree Plantation' || category == 'Mangrove Restoration';

  int get spotsLeft => (targetParticipants - participantCount).clamp(0, targetParticipants);
}

class PointsEntry {
  final String id;
  final int amount;
  final String type;
  final String status;
  final String reason;
  final String campaignTitle;
  final DateTime createdAt;

  const PointsEntry({
    required this.id,
    required this.amount,
    required this.type,
    required this.status,
    required this.reason,
    required this.campaignTitle,
    required this.createdAt,
  });

  factory PointsEntry.fromJson(Map<String, dynamic> j) => PointsEntry(
        id: _str(j['_id']),
        amount: _int(j['amount']),
        type: _str(j['type']),
        status: _str(j['status']),
        reason: _str(j['reason']),
        campaignTitle: _str((j['campaign'] as Map?)?['title']),
        createdAt: _date(j['createdAt']),
      );
}

class MyReport {
  final String id;
  final String campaignTitle;
  final String status;
  final int outputCount;
  final List<String> flags;
  final int distanceM;
  final bool withinGeofence;
  final DateTime submittedAt;
  final String reviewNote;
  final int attendeeCount;

  const MyReport({
    required this.id,
    required this.campaignTitle,
    required this.status,
    required this.outputCount,
    required this.flags,
    required this.distanceM,
    required this.withinGeofence,
    required this.submittedAt,
    required this.reviewNote,
    required this.attendeeCount,
  });

  factory MyReport.fromJson(Map<String, dynamic> j) => MyReport(
        id: _str(j['_id']),
        campaignTitle: _str((j['campaign'] as Map?)?['title']),
        status: _str(j['status']),
        outputCount: _int(j['outputCount']),
        flags: (j['flags'] as List? ?? const []).map((e) => e.toString()).toList(),
        distanceM: _int(j['distanceM']),
        withinGeofence: j['withinGeofence'] == true,
        submittedAt: _date(j['submittedAt']),
        reviewNote: _str(j['reviewNote']),
        attendeeCount: _int(j['attendeeCount']),
      );
}
