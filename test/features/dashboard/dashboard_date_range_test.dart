import 'package:delta_erp/features/dashboard/presentation/utils/dashboard_date_range.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DashboardDateRange', () {
    final anchor = DateTime(2026, 6, 4); // Thursday

    test('day granularity uses today only', () {
      final range = DashboardDateRange.forGranularity('day', anchor: anchor);
      expect(range.from, DateTime(2026, 6, 4));
      expect(range.to, DateTime(2026, 6, 4));
    });

    test('week granularity starts on Monday of current week', () {
      final range = DashboardDateRange.forGranularity('week', anchor: anchor);
      expect(range.from, DateTime(2026, 6, 1)); // Monday
      expect(range.to, DateTime(2026, 6, 4));
    });

    test('month granularity starts on first day of month', () {
      final range = DashboardDateRange.forGranularity('month', anchor: anchor);
      expect(range.from, DateTime(2026, 6, 1));
      expect(range.to, DateTime(2026, 6, 4));
    });
  });
}
