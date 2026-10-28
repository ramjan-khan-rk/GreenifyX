/// Parse Eco Points from API payloads that may still send legacy keys.
int parseEcoPoints(Map<String, dynamic> json) {
  final value =
      json["ecoPoints"] ?? json["ecoScore"] ?? json["karamCount"] ?? 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}
