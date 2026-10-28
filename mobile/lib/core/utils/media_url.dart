import '../config/app_config.dart';

String? resolveMediaUrl(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) {
    return trimmed;
  }
  final path = trimmed.startsWith("/") ? trimmed : "/uploads/$trimmed";
  return "${AppConfig.origin}$path";
}
