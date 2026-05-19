import 'package:sqflite/sqflite.dart';

import 'package:delta_erp/services/database/migrations/migration_v12.dart';

/// Cumulative return value per sale invoice for revenue drilldown reporting.
class MigrationV13 {
  Future<void> up(Database db) async {
    await db.execute(
      'ALTER TABLE sales ADD COLUMN returned_total REAL NOT NULL DEFAULT 0',
    );
    await ReturnReportingBackfill.backfillReturnsAmount(db);
    await ReturnReportingBackfill.backfillSalesReturnedTotal(db);
  }
}

/// Shared backfill helpers for migrations and onOpen ensure.
class ReturnReportingBackfill {
  ReturnReportingBackfill._();

  static Future<void> ensureColumns(Database db) async {
    final returnsInfo = await db.rawQuery('PRAGMA table_info(returns)');
    final returnsColumns = returnsInfo
        .map((row) => (row['name'] as String?) ?? '')
        .toSet();
    if (!returnsColumns.contains('amount')) {
      await MigrationV12().up(db);
    } else {
      await backfillReturnsAmount(db);
    }

    final salesInfo = await db.rawQuery('PRAGMA table_info(sales)');
    final salesColumns = salesInfo
        .map((row) => (row['name'] as String?) ?? '')
        .toSet();
    if (!salesColumns.contains('returned_total')) {
      await db.execute(
        'ALTER TABLE sales ADD COLUMN returned_total REAL NOT NULL DEFAULT 0',
      );
    }

    await backfillSalesReturnedTotal(db);
  }

  static Future<void> backfillReturnsAmount(Database db) async {
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

  static Future<void> backfillSalesReturnedTotal(Database db) async {
    await db.execute('''
      UPDATE sales
      SET returned_total = COALESCE((
        SELECT SUM(ret.amount)
        FROM returns ret
        WHERE ret.invoice_type = 'sale'
          AND ret.invoice_id = sales.id
          AND ret.amount > 0
      ), 0)
      WHERE returned_total = 0
        AND EXISTS (
          SELECT 1
          FROM returns ret
          WHERE ret.invoice_type = 'sale'
            AND ret.invoice_id = sales.id
            AND ret.amount > 0
        )
    ''');
    await db.execute('''
      UPDATE sales
      SET returned_total = COALESCE((
        SELECT SUM(lt.amount)
        FROM returns ret
        INNER JOIN ledger_transactions lt
          ON lt.source_type = 'return'
          AND lt.source_id = ret.id
        WHERE ret.invoice_type = 'sale'
          AND ret.invoice_id = sales.id
          AND lt.reversal_for_id IS NULL
      ), 0)
      WHERE returned_total = 0
        AND EXISTS (
          SELECT 1
          FROM returns ret
          INNER JOIN ledger_transactions lt
            ON lt.source_type = 'return'
            AND lt.source_id = ret.id
          WHERE ret.invoice_type = 'sale'
            AND ret.invoice_id = sales.id
            AND lt.reversal_for_id IS NULL
        )
    ''');
    await db.execute('''
      UPDATE sales
      SET returned_total = COALESCE((
        SELECT SUM(
          ret.quantity * (
            si.unit_price
            - CASE
                WHEN ABS(si.quantity) > 0.000001
                THEN si.discount_amount / si.quantity
                ELSE 0
              END
          )
        )
        FROM returns ret
        INNER JOIN sale_items si ON si.id = ret.original_line_id
        WHERE ret.invoice_type = 'sale'
          AND ret.invoice_id = sales.id
      ), 0)
      WHERE returned_total = 0
        AND EXISTS (
          SELECT 1
          FROM returns ret
          WHERE ret.invoice_type = 'sale'
            AND ret.invoice_id = sales.id
        )
    ''');
  }
}
