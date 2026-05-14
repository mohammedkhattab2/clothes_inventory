import 'package:sqflite/sqflite.dart';

class MigrationV7 {
  Future<void> up(Database db) async {
    await db.execute('PRAGMA foreign_keys = OFF');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales_v7 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER,
        invoice_number TEXT NOT NULL UNIQUE,
        status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending', 'completed', 'partial', 'cancelled')),
        total_amount REAL NOT NULL,
        notes TEXT,
        created_by_user_id INTEGER,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      INSERT INTO sales_v7 (
        id,
        account_id,
        invoice_number,
        status,
        total_amount,
        notes,
        created_by_user_id,
        created_at
      )
      SELECT
        id,
        account_id,
        invoice_number,
        status,
        total_amount,
        notes,
        created_by_user_id,
        created_at
      FROM sales
    ''');

    await db.execute('DROP TABLE sales');
    await db.execute('ALTER TABLE sales_v7 RENAME TO sales');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_created_by_date ON sales(created_by_user_id, created_at)',
    );

    await db.execute('PRAGMA foreign_keys = ON');
  }
}
