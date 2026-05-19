import 'package:sqflite/sqflite.dart';

/// Persists monetary value of each return for reporting (walk-in sales have no ledger).
class MigrationV12 {
  Future<void> up(Database db) async {
    await db.execute(
      'ALTER TABLE returns ADD COLUMN amount REAL NOT NULL DEFAULT 0',
    );
    await db.execute('''
      UPDATE returns
      SET amount = (
        SELECT lt.amount
        FROM ledger_transactions lt
        WHERE lt.source_type = 'return'
          AND lt.source_id = returns.id
          AND lt.reversal_for_id IS NULL
        LIMIT 1
      )
      WHERE amount = 0
        AND EXISTS (
          SELECT 1
          FROM ledger_transactions lt
          WHERE lt.source_type = 'return'
            AND lt.source_id = returns.id
            AND lt.reversal_for_id IS NULL
        )
    ''');
    await db.execute('''
      UPDATE returns
      SET amount = (
        SELECT ret.quantity * (
          si.unit_price
          - CASE
              WHEN ABS(si.quantity) > 0.000001
              THEN si.discount_amount / si.quantity
              ELSE 0
            END
        )
        FROM returns ret
        INNER JOIN sale_items si ON si.id = ret.original_line_id
        WHERE ret.id = returns.id
      )
      WHERE amount = 0
        AND invoice_type = 'sale'
        AND EXISTS (
          SELECT 1
          FROM sale_items si
          WHERE si.id = returns.original_line_id
        )
    ''');
  }
}
