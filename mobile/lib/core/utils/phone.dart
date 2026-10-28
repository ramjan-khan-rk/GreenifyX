String withIndiaCountryCode(String raw) {
  final digits = raw.replaceAll(RegExp(r"\D"), "");
  if (digits.isEmpty) return raw.trim();
  if (digits.startsWith("91") && digits.length > 10) {
    return "+$digits";
  }
  return "+91$digits";
}
