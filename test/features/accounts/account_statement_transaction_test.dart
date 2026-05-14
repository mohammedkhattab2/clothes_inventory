import 'package:flutter_test/flutter_test.dart';
import 'package:clothes_inventory/features/accounts/data/account_statement_repository.dart';

void main() {
  group('AccountStatementTransaction amounts', () {
    test('debit/credit split for positive signed amount', () {
      final tx = AccountStatementTransaction(
        id: 1,
        accountId: 1,
        createdAt: DateTime(2026, 4, 1),
        type: 'sale',
        referenceId: 100,
        signedAmount: 120.5,
        runningBalance: 120.5,
      );

      expect(tx.debit, 120.5);
      expect(tx.credit, 0);
    });

    test('debit/credit split for negative signed amount', () {
      final tx = AccountStatementTransaction(
        id: 2,
        accountId: 1,
        createdAt: DateTime(2026, 4, 1),
        type: 'payment',
        referenceId: 200,
        signedAmount: -35,
        runningBalance: 85.5,
      );

      expect(tx.debit, 0);
      expect(tx.credit, 35);
    });
  });
}
