import 'package:sqflite/sqflite.dart';

/// Tracks products added during invoice amendment for revenue reporting.
class MigrationV14 {
  Future<void> up(Database db) async {
    await AmendmentAddedReporting.ensureColumns(db);
  }
}

/// Shared ensure/backfill for amendment-added reporting columns.
class AmendmentAddedReporting {
  AmendmentAddedReporting._();

  static Future<void> ensureColumns(Database db) async {
    final salesInfo = await db.rawQuery('PRAGMA table_info(sales)');
    final salesColumns = salesInfo
        .map((row) => (row['name'] as String?) ?? '')
        .toSet();
    if (!salesColumns.contains('added_total')) {
      await db.execute(
        'ALTER TABLE sales ADD COLUMN added_total REAL NOT NULL DEFAULT 0',
      );
    }

    final itemsInfo = await db.rawQuery('PRAGMA table_info(sale_items)');
    final itemsColumns = itemsInfo
        .map((row) => (row['name'] as String?) ?? '')
        .toSet();
    if (!itemsColumns.contains('added_after_amendment')) {
      await db.execute(
        'ALTER TABLE sale_items ADD COLUMN added_after_amendment INTEGER NOT NULL DEFAULT 0',
      );
    }

    await db.execute('''
      UPDATE sales
      SET added_total = COALESCE((
        SELECT SUM(si.line_total)
        FROM sale_items si
        WHERE si.sale_id = sales.id
          AND si.added_after_amendment = 1
      ), 0)
      WHERE added_total = 0
        AND EXISTS (
          SELECT 1
          FROM sale_items si
          WHERE si.sale_id = sales.id
            AND si.added_after_amendment = 1
        )
    ''');
  }
}
