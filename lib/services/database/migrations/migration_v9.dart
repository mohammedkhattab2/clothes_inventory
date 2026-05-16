import 'package:sqflite/sqflite.dart';

/// Allow `visa` as a stored payment channel on invoice payments.
class MigrationV9 {
  Future<void> up(Database db) async {
    await db.execute('''
      CREATE TABLE payments_v9 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER,
        invoice_type TEXT CHECK(invoice_type IN ('sale', 'purchase', 'expense')),
        invoice_id INTEGER,
        payment_method TEXT NOT NULL CHECK(payment_method IN ('cash', 'vodafone_cash', 'visa')),
        amount REAL NOT NULL,
        is_refund INTEGER NOT NULL DEFAULT 0,
        is_standalone INTEGER NOT NULL DEFAULT 0,
        reversal_for_id INTEGER,
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        created_by_user_id INTEGER,
        FOREIGN KEY(account_id) REFERENCES accounts(id),
        FOREIGN KEY(reversal_for_id) REFERENCES payments_v9(id)
      );
    ''');

    await db.execute('''
      INSERT INTO payments_v9 (
        id, account_id, invoice_type, invoice_id, payment_method, amount,
        is_refund, is_standalone, reversal_for_id, notes, created_at, created_by_user_id
      )
      SELECT
        id, account_id, invoice_type, invoice_id, payment_method, amount,
        is_refund, is_standalone, reversal_for_id, notes, created_at, created_by_user_id
      FROM payments;
    ''');

    await db.execute('DROP TABLE payments');
    await db.execute('ALTER TABLE payments_v9 RENAME TO payments');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payments_invoice ON payments(invoice_type, invoice_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payments_created_by ON payments(created_by_user_id);',
    );
  }
}
