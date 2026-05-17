import 'package:flutter_test/flutter_test.dart';
import 'package:delta_erp/features/dashboard/presentation/dashboard_cubit.dart';

void main() {
  test('buildDashboardDrillDownRoute preserves filters in query string', () {
    final route = buildDashboardDrillDownRoute(
      kind: 'revenue',
      fromDate: DateTime(2026, 4, 1, 8, 30),
      toDate: DateTime(2026, 4, 2, 18, 45),
      granularity: 'week',
      categoryId: 12,
      accountId: 7,
    );

    expect(route, contains('/dashboard/drilldown/revenue?'));
    expect(route, contains('granularity=week'));
    expect(route, contains('categoryId=12'));
    expect(route, contains('accountId=7'));
    expect(route, contains('from='));
    expect(route, contains('to='));
  });

  test('buildInvoiceFocusRoute routes to sales and preserves pagination', () {
    final route = buildInvoiceFocusRoute(
      invoiceType: 'sale',
      invoiceId: 44,
      fromDate: DateTime(2026, 4, 1),
      toDate: DateTime(2026, 4, 30),
      sourcePage: 3,
      sourcePageSize: 25,
      accountId: 5,
      categoryId: 2,
    );

    expect(route, startsWith('/sales?'));
    expect(route, contains('selectedInvoiceId=44'));
    expect(route, contains('page=3'));
    expect(route, contains('pageSize=25'));
    expect(route, contains('accountId=5'));
    expect(route, contains('categoryId=2'));
  });

  test('buildInvoiceFocusRoute routes to purchases', () {
    final route = buildInvoiceFocusRoute(
      invoiceType: 'purchase',
      invoiceId: 77,
      fromDate: DateTime(2026, 4, 1),
      toDate: DateTime(2026, 4, 30),
      sourcePage: 0,
      sourcePageSize: 50,
    );

    expect(route, startsWith('/purchases?'));
    expect(route, contains('selectedInvoiceId=77'));
    expect(route, contains('page=0'));
    expect(route, contains('pageSize=50'));
  });
}
