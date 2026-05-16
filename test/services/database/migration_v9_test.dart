import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:clothes_inventory/services/database/migrations/migration_v9.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('MigrationV9 allows visa payment_method on payments', () async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE accounts (id INTEGER PRIMARY KEY)');
        await db.insert('accounts', {'id': 1});
        await db.execute('''
          CREATE TABLE payments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            account_id INTEGER,
            invoice_type TEXT CHECK(invoice_type IN ('sale', 'purchase', 'expense')),
            invoice_id INTEGER,
            payment_method TEXT NOT NULL CHECK(payment_method IN ('cash', 'vodafone_cash')),
            amount REAL NOT NULL,
            is_refund INTEGER NOT NULL DEFAULT 0,
            is_standalone INTEGER NOT NULL DEFAULT 0,
            reversal_for_id INTEGER,
            notes TEXT,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            created_by_user_id INTEGER
          );
        ''');
        await db.insert('payments', {
          'account_id': 1,
          'invoice_type': 'sale',
          'invoice_id': 1,
          'payment_method': 'cash',
          'amount': 10.0,
          'is_refund': 0,
          'is_standalone': 0,
        });
      },
    );

    await MigrationV9().up(db);

    final id = await db.insert('payments', {
      'account_id': 1,
      'invoice_type': 'sale',
      'invoice_id': 1,
      'payment_method': 'visa',
      'amount': 15.0,
      'is_refund': 0,
      'is_standalone': 0,
      'notes': 'test',
      'created_at': DateTime.now().toIso8601String(),
    });
    expect(id, greaterThan(0));

    final rows = await db.query(
      'payments',
      where: 'payment_method = ?',
      whereArgs: ['visa'],
    );
    expect(rows, hasLength(1));
    expect((rows.first['amount'] as num).toDouble(), 15.0);

    await db.close();
  });
}
