import 'package:sqflite/sqflite.dart';

/// Stores checkout payment channel on [sales] for list rows when no [payments]
/// rows exist (e.g. full deferred / zero paid at issue).
class MigrationV10 {
  Future<void> up(Database db) async {
    await db.execute(
      'ALTER TABLE sales ADD COLUMN primary_payment_method TEXT',
    );

    await db.execute('''
      UPDATE sales
      SET primary_payment_method = (
        SELECT GROUP_CONCAT(DISTINCT payment_method)
        FROM payments
        WHERE invoice_type = 'sale'
          AND invoice_id = sales.id
          AND reversal_for_id IS NULL
          AND is_refund = 0
          AND amount > 0
      )
      WHERE EXISTS (
        SELECT 1 FROM payments
        WHERE invoice_type = 'sale'
          AND invoice_id = sales.id
          AND reversal_for_id IS NULL
          AND is_refund = 0
          AND amount > 0
      )
    ''');
  }
}
