import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:delta_erp/services/database/migrations/migration_v2.dart';

Future<void> _createLegacyV1Schema(Database db) async {
  await db.execute('''
    CREATE TABLE accounts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      account_type TEXT NOT NULL CHECK(account_type IN ('customer', 'supplier')),
      phone TEXT,
      address TEXT,
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
  ''');

  await db.execute('''
    CREATE TABLE sales (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      account_id INTEGER,
      invoice_number TEXT NOT NULL UNIQUE,
      status TEXT NOT NULL DEFAULT 'completed' CHECK(status IN ('completed', 'partial', 'cancelled')),
      total_amount REAL NOT NULL,
      notes TEXT,
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE SET NULL
    );
  ''');

  await db.execute('''
    CREATE TABLE purchases (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      account_id INTEGER NOT NULL,
      invoice_number TEXT NOT NULL UNIQUE,
      status TEXT NOT NULL DEFAULT 'completed' CHECK(status IN ('completed', 'partial', 'cancelled')),
      total_amount REAL NOT NULL,
      notes TEXT,
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY(account_id) REFERENCES accounts(id)
    );
  ''');

  await db.execute('''
    CREATE TABLE payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      account_id INTEGER,
      invoice_type TEXT CHECK(invoice_type IN ('sale', 'purchase')),
      invoice_id INTEGER,
      payment_method TEXT NOT NULL CHECK(payment_method IN ('cash', 'vodafone_cash')),
      amount REAL NOT NULL,
      is_refund INTEGER NOT NULL DEFAULT 0,
      is_standalone INTEGER NOT NULL DEFAULT 0,
      reversal_for_id INTEGER,
      notes TEXT,
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY(account_id) REFERENCES accounts(id),
      FOREIGN KEY(reversal_for_id) REFERENCES payments(id)
    );
  ''');

  await db.execute('''
    CREATE TABLE ledger_transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      account_id INTEGER NOT NULL,
      source_type TEXT NOT NULL CHECK(source_type IN ('sale', 'purchase', 'payment', 'return', 'cancellation')),
      source_id INTEGER,
      amount REAL NOT NULL,
      entry_kind TEXT NOT NULL CHECK(entry_kind IN ('debit', 'credit', 'reversal')),
      description TEXT,
      reversal_for_id INTEGER,
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY(account_id) REFERENCES accounts(id),
      FOREIGN KEY(reversal_for_id) REFERENCES ledger_transactions(id)
    );
  ''');

  await db.execute('''
    INSERT INTO accounts (id, name, account_type, phone, address)
    VALUES
      (1, 'Legacy Customer', 'customer', NULL, NULL),
      (2, 'Legacy Supplier', 'supplier', NULL, NULL);
  ''');

  await db.execute('''
    INSERT INTO sales (id, account_id, invoice_number, status, total_amount)
    VALUES (1, 1, 'S-1', 'completed', 100.0);
  ''');

  await db.execute('''
    INSERT INTO purchases (id, account_id, invoice_number, status, total_amount)
    VALUES (1, 2, 'P-1', 'completed', 80.0);
  ''');

  await db.execute('''
    INSERT INTO payments (id, account_id, invoice_type, invoice_id, payment_method, amount)
    VALUES
      (1, 1, 'sale', 1, 'cash', 100.0),
      (2, 2, 'purchase', 1, 'cash', 80.0);
  ''');

  await db.execute('''
    INSERT INTO ledger_transactions (
      id, account_id, source_type, source_id, amount, entry_kind, description
    )
    VALUES
      (1, 1, 'sale', 1, 100.0, 'debit', 'legacy sale'),
      (2, 2, 'purchase', 1, 80.0, 'credit', 'legacy purchase');
  ''');
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('migration v2 upgrades legacy schema with FK references safely', () async {
    final tempDir = await Directory.systemTemp.createTemp('migration_v2_test_');
    final dbPath = p.join(tempDir.path, 'legacy.db');

    final legacyDb = await openDatabase(
      dbPath,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createLegacyV1Schema(db);
      },
    );
    await legacyDb.close();

    final upgradedDb = await openDatabase(
      dbPath,
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await MigrationV2().up(db);
        }
      },
    );

    final tableInfo = await upgradedDb.rawQuery('PRAGMA table_info(accounts)');
    final accountTypeRow = tableInfo.firstWhere(
      (row) => row['name'] == 'account_type',
    );
    expect((accountTypeRow['type'] as String).toUpperCase(), 'TEXT');

    final accountId = await upgradedDb.insert('accounts', {
      'name': 'Utilities',
      'account_type': 'expense',
    });

    await upgradedDb.insert('expenses', {
      'account_id': accountId,
      'amount': 50.0,
      'payment_method': 'cash',
      'notes': 'electricity bill',
    });

    await upgradedDb.insert('payments', {
      'account_id': accountId,
      'invoice_type': 'expense',
      'invoice_id': 1,
      'payment_method': 'cash',
      'amount': 50.0,
      'is_refund': 0,
      'is_standalone': 0,
      'notes': 'expense payment',
    });

    await upgradedDb.insert('ledger_transactions', {
      'account_id': accountId,
      'source_type': 'expense',
      'source_id': 1,
      'amount': 50.0,
      'entry_kind': 'debit',
      'description': 'expense entry',
    });

    final fkViolations = await upgradedDb.rawQuery('PRAGMA foreign_key_check');
    expect(fkViolations, isEmpty);

    final oldAccountsTable = await upgradedDb.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'accounts_old'",
    );
    expect(oldAccountsTable, isEmpty);

    await upgradedDb.close();
    await tempDir.delete(recursive: true);
  });

  test(
    'migration v2 preserves reversal chains and creates expected indexes',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'migration_v2_reversal_test_',
      );
      final dbPath = p.join(tempDir.path, 'legacy_reversal.db');

      final legacyDb = await openDatabase(
        dbPath,
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await _createLegacyV1Schema(db);
        },
      );

      await legacyDb.insert('payments', {
        'id': 3,
        'account_id': 1,
        'invoice_type': 'sale',
        'invoice_id': 1,
        'payment_method': 'cash',
        'amount': 20.0,
        'is_refund': 1,
        'is_standalone': 0,
        'reversal_for_id': 1,
        'notes': 'legacy payment reversal',
      });

      await legacyDb.insert('ledger_transactions', {
        'id': 3,
        'account_id': 1,
        'source_type': 'payment',
        'source_id': 3,
        'amount': 20.0,
        'entry_kind': 'reversal',
        'description': 'legacy ledger reversal',
        'reversal_for_id': 1,
      });

      await legacyDb.close();

      final upgradedDb = await openDatabase(
        dbPath,
        version: 2,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await MigrationV2().up(db);
          }
        },
      );

      final migratedReversalPayment = await upgradedDb.query(
        'payments',
        columns: ['id', 'reversal_for_id'],
        where: 'id = ?',
        whereArgs: [3],
        limit: 1,
      );
      expect(migratedReversalPayment, isNotEmpty);
      expect(migratedReversalPayment.first['reversal_for_id'], 1);

      final migratedReversalLedger = await upgradedDb.query(
        'ledger_transactions',
        columns: ['id', 'reversal_for_id'],
        where: 'id = ?',
        whereArgs: [3],
        limit: 1,
      );
      expect(migratedReversalLedger, isNotEmpty);
      expect(migratedReversalLedger.first['reversal_for_id'], 1);

      final indexes = await upgradedDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index'",
      );
      final indexNames = indexes.map((row) => row['name'] as String).toSet();

      expect(indexNames.contains('idx_accounts_type'), isTrue);
      expect(indexNames.contains('idx_expenses_account_created'), isTrue);
      expect(indexNames.contains('idx_ledger_transactions_account_id'), isTrue);
      expect(indexNames.contains('idx_payments_invoice'), isTrue);

      final fkViolations = await upgradedDb.rawQuery(
        'PRAGMA foreign_key_check',
      );
      expect(fkViolations, isEmpty);

      await upgradedDb.close();
      await tempDir.delete(recursive: true);
    },
  );
}
