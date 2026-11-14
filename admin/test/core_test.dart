import 'package:flutter_test/flutter_test.dart';
import 'package:greenifyx_admin/core/format.dart';
import 'package:greenifyx_admin/widgets/shell.dart';

void main() {
  group('Fmt', () {
    test('numbers use thousands separators and compact above 10k', () {
      expect(Fmt.number(1234567), '1,234,567');
      expect(Fmt.number(null), '0');
      expect(Fmt.compact(9999), '9,999');
      expect(Fmt.compact(25000), '25K');
    });

    test('dates are shown in UAE time', () {
      // 21:30 UTC on 31 Dec is already 1 Jan in the UAE.
      expect(Fmt.date('2026-12-31T21:30:00Z'), '1 Jan 2027');
      expect(Fmt.date(null), '—');
    });
  });

  group('Navigation', () {
    test('partners and auditors only see their own area', () {
      expect(partnerNavItems.map((n) => n.path), ['/partner']);
      expect(auditorNavItems.map((n) => n.path), ['/audit']);
    });

    test('admins see the new pages and every path is unique', () {
      final paths = navItems.map((n) => n.path).toList();
      for (final p in ['/stations', '/missions', '/partners', '/audit', '/lessons', '/home-health', '/forest', '/deals']) {
        expect(paths, contains(p));
      }
      expect(paths.toSet().length, paths.length);
    });
  });
}
