class IssueStep {
  final String status;
  final String label;
  final String note;
  final DateTime at;
  const IssueStep(this.status, this.label, this.note, this.at);
}

class IssueReport {
  final String id;
  final String category;
  final String description;
  final String landmark;
  final String emirate;
  final List<String> photos;
  final double lat;
  final double lng;
  final String status;
  final String statusLabel;
  final String forwardedTo;
  final List<IssueStep> history;
  final int confirmations;
  final bool confirmedByMe;
  final bool isMine;
  final int pointsCredited;
  final int? distanceM;
  final DateTime createdAt;

  const IssueReport({
    required this.id,
    required this.category,
    required this.description,
    required this.landmark,
    required this.emirate,
    required this.photos,
    required this.lat,
    required this.lng,
    required this.status,
    required this.statusLabel,
    required this.forwardedTo,
    required this.history,
    required this.confirmations,
    required this.confirmedByMe,
    required this.isMine,
    required this.pointsCredited,
    required this.distanceM,
    required this.createdAt,
  });

  bool get isOpen => status == "submitted" || status == "under_review" || status == "forwarded";

  factory IssueReport.fromJson(Map<String, dynamic> j) {
    final loc = (j["location"] as Map?) ?? const {};
    DateTime date(dynamic v) => DateTime.tryParse(v?.toString() ?? "")?.toLocal() ?? DateTime.now();
    return IssueReport(
      id: j["_id"]?.toString() ?? "",
      category: j["category"]?.toString() ?? "",
      description: j["description"]?.toString() ?? "",
      landmark: j["landmark"]?.toString() ?? "",
      emirate: j["emirate"]?.toString() ?? "",
      photos: (j["photos"] as List? ?? const []).map((e) => e.toString()).toList(),
      lat: (loc["lat"] as num?)?.toDouble() ?? 0,
      lng: (loc["lng"] as num?)?.toDouble() ?? 0,
      status: j["status"]?.toString() ?? "submitted",
      statusLabel: j["statusLabel"]?.toString() ?? "",
      forwardedTo: j["forwardedTo"]?.toString() ?? "",
      history: (j["history"] as List? ?? const [])
          .whereType<Map>()
          .map((h) => IssueStep(
                h["status"]?.toString() ?? "",
                h["label"]?.toString() ?? "",
                h["note"]?.toString() ?? "",
                date(h["at"]),
              ))
          .toList(),
      confirmations: (j["confirmations"] as num?)?.toInt() ?? 0,
      confirmedByMe: j["confirmedByMe"] == true,
      isMine: j["isMine"] == true,
      pointsCredited: (j["pointsCredited"] as num?)?.toInt() ?? 0,
      distanceM: (j["distanceM"] as num?)?.toInt(),
      createdAt: date(j["createdAt"]),
    );
  }
}
