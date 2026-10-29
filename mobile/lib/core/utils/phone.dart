const defaultCountryDigits = "971";
const legacyCountryDigits = "91";

/// New identifier flows default to +971. Explicit +91 numbers stay +91.
String withDefaultCountryCode(String raw) {
  final digits = raw.replaceAll(RegExp(r"\D"), "");
  if (digits.isEmpty) return raw.trim();
  if (digits.startsWith(defaultCountryDigits) && digits.length > 9) {
    return "+$digits";
  }
  if (digits.startsWith(legacyCountryDigits) && digits.length > 10) {
    return "+$digits";
  }
  return "+$defaultCountryDigits$digits";
}

@Deprecated("Use withDefaultCountryCode")
String withIndiaCountryCode(String raw) => withDefaultCountryCode(raw);
