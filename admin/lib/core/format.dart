import 'package:intl/intl.dart';

class Fmt {
  Fmt._();

  static final _int = NumberFormat.decimalPattern('en');
  static final _compact = NumberFormat.compact(locale: 'en');
  static final _date = DateFormat('d MMM yyyy');
  static final _short = DateFormat('d MMM');

  static String number(num? v) => _int.format(v ?? 0);
  static String compact(num? v) => (v ?? 0) < 10000 ? number(v) : _compact.format(v ?? 0);

  /// Dates come from the API as UTC; show them in UAE time (UTC+4, no DST).
  static DateTime? uae(dynamic iso) {
    if (iso == null) return null;
    final parsed = DateTime.tryParse(iso.toString());
    return parsed?.toUtc().add(const Duration(hours: 4));
  }

  static String date(dynamic iso) {
    final d = uae(iso);
    return d == null ? '—' : _date.format(d);
  }

  /// Formats a calendar day as-is (no time-zone shift), e.g. from a date picker.
  static String day(DateTime d) => _date.format(d);

  static String shortDay(String ymd) {
    final d = DateTime.tryParse(ymd);
    return d == null ? ymd : _short.format(d);
  }

  static String ago(dynamic iso) {
    final parsed = DateTime.tryParse(iso?.toString() ?? '');
    if (parsed == null) return '—';
    final diff = DateTime.now().toUtc().difference(parsed.toUtc());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return date(iso);
  }

  static String co2(num? kg) {
    final v = (kg ?? 0).toDouble();
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)} t';
    return '${v.toStringAsFixed(v < 100 ? 1 : 0)} kg';
  }
}
