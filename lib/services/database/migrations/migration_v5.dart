import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

class MigrationV5 {
  Future<void> up(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        full_name TEXT NOT NULL,
        pin_hash TEXT,
        password_hash TEXT,
        role TEXT NOT NULL DEFAULT 'cashier' CHECK(role IN ('owner', 'manager', 'cashier', 'purchaser')),
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      );
    ''');

    final ownerId = await _ensureOwnerUser(db);

    await _ensureColumn(db, 'sales', 'created_by_user_id', 'INTEGER');
    await _ensureColumn(db, 'purchases', 'created_by_user_id', 'INTEGER');
    await _ensureColumn(db, 'payments', 'created_by_user_id', 'INTEGER');
    await _ensureColumn(db, 'returns', 'created_by_user_id', 'INTEGER');

    await db.rawUpdate(
      'UPDATE sales SET created_by_user_id = ? WHERE created_by_user_id IS NULL OR created_by_user_id = 0',
      [ownerId],
    );
    await db.rawUpdate(
      'UPDATE purchases SET created_by_user_id = ? WHERE created_by_user_id IS NULL OR created_by_user_id = 0',
      [ownerId],
    );
    await db.rawUpdate(
      'UPDATE payments SET created_by_user_id = ? WHERE created_by_user_id IS NULL OR created_by_user_id = 0',
      [ownerId],
    );
    await db.rawUpdate(
      'UPDATE returns SET created_by_user_id = ? WHERE created_by_user_id IS NULL OR created_by_user_id = 0',
      [ownerId],
    );

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_created_by_date ON sales(created_by_user_id, created_at);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchases_created_by_date ON purchases(created_by_user_id, created_at);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payments_created_by ON payments(created_by_user_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_returns_created_by ON returns(created_by_user_id);',
    );
  }

  Future<int> _ensureOwnerUser(Database db) async {
    final rows = await db.query(
      'users',
      columns: ['id'],
      where: 'LOWER(username) = LOWER(?)',
      whereArgs: ['owner'],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return (rows.first['id'] as num).toInt();
    }

    final now = DateTime.now().toIso8601String();
    return db.insert('users', {
      'username': 'owner',
      'full_name': 'Owner',
      'pin_hash': sha256.convert(utf8.encode('0000')).toString(),
      'password_hash': sha256.convert(utf8.encode('123456')).toString(),
      'role': 'owner',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> _ensureColumn(
    Database db,
    String table,
    String column,
    String type,
  ) async {
    final tableInfo = await db.rawQuery('PRAGMA table_info($table)');
    final exists = tableInfo.any((row) => row['name'] == column);
    if (exists) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
  }
}
