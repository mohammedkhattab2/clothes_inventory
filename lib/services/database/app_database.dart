import 'dart:io';
import 'dart:developer' as dev;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:clothes_inventory/core/utils/app_paths.dart';
import 'package:clothes_inventory/services/database/migrations/migration_v1.dart';
import 'package:clothes_inventory/services/database/migrations/migration_v2.dart';
import 'package:clothes_inventory/services/database/migrations/migration_v3.dart';
import 'package:clothes_inventory/services/database/migrations/migration_v4.dart';
import 'package:clothes_inventory/services/database/migrations/migration_v5.dart';
import 'package:clothes_inventory/services/database/migrations/migration_v6.dart';
import 'package:clothes_inventory/services/database/migrations/migration_v7.dart';
import 'package:clothes_inventory/services/database/migrations/migration_v8.dart';
import 'package:clothes_inventory/services/database/migrations/migration_v9.dart';
import 'package:clothes_inventory/services/database/migrations/migration_v10.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const _legacyDbName = 'inventory_pos.db';
  static const _dbVersion = 10;

  Database? _db;

  int get dbVersion => _dbVersion;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<void> closeDatabaseForMaintenance() async {
    final db = _db;
    if (db == null) {
      return;
    }
    await db.close();
    _db = null;
  }

  Future<Database> reopenDatabaseAfterMaintenance() async {
    await closeDatabaseForMaintenance();
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await _resolveDatabasePath();
    await _migrateLegacyDatabaseIfNeeded(dbPath);

    return openDatabase(
      dbPath,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await MigrationV1().up(db);
        await MigrationV3().up(db);
        await MigrationV4().up(db);
        await MigrationV5().up(db);
        await MigrationV6().up(db);
        await MigrationV7().up(db);
        await MigrationV8().up(db);
        await MigrationV9().up(db);
        await MigrationV10().up(db);
        await _ensureProductSalePriceColumns(db);
        await _ensureStockGuards(db);
        await _normalizeStandaloneSettlementPayments(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await MigrationV2().up(db);
        }
        if (oldVersion < 3) {
          await MigrationV3().up(db);
        }
        if (oldVersion < 4) {
          await MigrationV4().up(db);
        }
        if (oldVersion < 5) {
          await MigrationV5().up(db);
        }
        if (oldVersion < 6) {
          await MigrationV6().up(db);
        }
        if (oldVersion < 7) {
          await MigrationV7().up(db);
        }
        if (oldVersion < 8) {
          await MigrationV8().up(db);
        }
        if (oldVersion < 9) {
          await MigrationV9().up(db);
        }
        if (oldVersion < 10) {
          await MigrationV10().up(db);
        }
      },
      onOpen: (db) async {
        await _ensureProductSalePriceColumns(db);
        await _ensureStockGuards(db);
        await _normalizeStandaloneSettlementPayments(db);
      },
    );
  }

  Future<void> _normalizeStandaloneSettlementPayments(Database db) async {
    await db.execute('''
      UPDATE payments
      SET is_standalone = 0
      WHERE is_standalone = 1
        AND account_id IS NOT NULL
        AND invoice_type IS NULL
        AND invoice_id IS NULL
    ''');
  }

  Future<String> _resolveDatabasePath() async {
    try {
      return await AppPaths.getDatabasePath();
    } catch (error) {
      final message = 'Unable to access app data storage for database.';
      dev.log('$message Error: $error', name: 'AppDatabase');
      throw StateError('$message Please verify write access to Local AppData.');
    }
  }

  Future<void> _migrateLegacyDatabaseIfNeeded(String newDbPath) async {
    try {
      final newDbFile = File(newDbPath);
      if (await newDbFile.exists()) {
        return;
      }

      final candidates = await _legacyDatabaseCandidates();
      for (final legacyFile in candidates) {
        if (!await legacyFile.exists()) {
          continue;
        }

        final parentDir = newDbFile.parent;
        if (!await parentDir.exists()) {
          await parentDir.create(recursive: true);
        }

        await legacyFile.copy(newDbPath);
        dev.log(
          'Migrated database from ${legacyFile.path} to $newDbPath',
          name: 'AppDatabase',
        );
        return;
      }
    } catch (error) {
      dev.log(
        'Database migration skipped due to error: $error',
        name: 'AppDatabase',
      );
    }
  }

  Future<List<File>> _legacyDatabaseCandidates() async {
    final candidates = <File>[];

    final exeDir = File(Platform.resolvedExecutable).parent.path;
    candidates.add(File(p.join(exeDir, _legacyDbName)));
    candidates.add(File(p.join(exeDir, 'app.db')));

    try {
      final supportDir = await getApplicationSupportDirectory();
      candidates.add(File(p.join(supportDir.path, _legacyDbName)));
      candidates.add(File(p.join(supportDir.path, 'app.db')));
    } catch (_) {
      // Ignore support directory lookup failures and continue.
    }

    final uniqueByPath = <String, File>{};
    for (final candidate in candidates) {
      uniqueByPath[candidate.path] = candidate;
    }
    return uniqueByPath.values.toList(growable: false);
  }

  Future<void> _ensureProductSalePriceColumns(Database db) async {
    final tableInfo = await db.rawQuery('PRAGMA table_info(products)');
    final columns = tableInfo
        .map((row) => (row['name'] as String?) ?? '')
        .toSet();

    if (!columns.contains('sale_price_half_wholesale')) {
      await db.execute(
        'ALTER TABLE products ADD COLUMN sale_price_half_wholesale REAL NOT NULL DEFAULT 0',
      );
    }

    if (!columns.contains('sale_price_wholesale')) {
      await db.execute(
        'ALTER TABLE products ADD COLUMN sale_price_wholesale REAL NOT NULL DEFAULT 0',
      );
    }

    await db.execute('''
      UPDATE products
      SET sale_price_half_wholesale = sale_price
      WHERE sale_price_half_wholesale IS NULL OR sale_price_half_wholesale = 0
    ''');

    await db.execute('''
      UPDATE products
      SET sale_price_wholesale = sale_price
      WHERE sale_price_wholesale IS NULL OR sale_price_wholesale = 0
    ''');
  }

  Future<void> _ensureStockGuards(Database db) async {
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_stock_movements_positive_quantity
      BEFORE INSERT ON stock_movements
      WHEN NEW.quantity <= 0
      BEGIN
        SELECT RAISE(ABORT, 'Stock movement quantity must be greater than zero.');
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_stock_movements_positive_quantity_update
      BEFORE UPDATE ON stock_movements
      WHEN NEW.quantity <= 0
      BEGIN
        SELECT RAISE(ABORT, 'Stock movement quantity must be greater than zero.');
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_stock_movements_no_negative_out
      BEFORE INSERT ON stock_movements
      WHEN NEW.movement_type = 'out'
      BEGIN
        SELECT
          CASE
            WHEN (
              COALESCE((
                SELECT SUM(
                  CASE
                    WHEN movement_type = 'in' THEN quantity
                    WHEN movement_type = 'out' THEN -quantity
                    ELSE 0
                  END
                )
                FROM stock_movements
                WHERE product_id = NEW.product_id
              ), 0) - NEW.quantity
            ) < 0
            THEN RAISE(ABORT, 'Insufficient stock for this product.')
          END;
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_stock_movements_no_negative_out_update
      BEFORE UPDATE ON stock_movements
      WHEN NEW.movement_type = 'out'
      BEGIN
        SELECT
          CASE
            WHEN (
              COALESCE((
                SELECT SUM(
                  CASE
                    WHEN movement_type = 'in' THEN quantity
                    WHEN movement_type = 'out' THEN -quantity
                    ELSE 0
                  END
                )
                FROM stock_movements
                WHERE product_id = NEW.product_id
                  AND id != OLD.id
              ), 0) - NEW.quantity
            ) < 0
            THEN RAISE(ABORT, 'Insufficient stock for this product.')
          END;
      END;
    ''');
  }
}
