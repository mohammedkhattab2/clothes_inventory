import 'dart:collection';

import 'package:delta_erp/services/auth/session_service.dart';
import 'package:delta_erp/services/database/app_database.dart';

class DashboardFilterOption {
  const DashboardFilterOption({required this.id, required this.name});

  final int id;
  final String name;
}

class TopSellingProduct {
  const TopSellingProduct({
    required this.productName,
    required this.quantity,
    required this.revenue,
  });

  final String productName;
  final double quantity;
  final double revenue;
}

class TopSupplier {
  const TopSupplier({required this.supplierName, required this.volume});

  final String supplierName;
  final double volume;
}

class TrendPoint {
  const TrendPoint({
    required this.label,
    required this.sales,
    required this.purchases,
  });

  final String label;
  final double sales;
  final double purchases;
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.totalSales,
    required this.totalPurchases,
    required this.cogs,
    required this.expenses,
    required this.outstandingCustomerDebt,
    required this.outstandingSupplierDebt,
    required this.salesInvoiceCount,
    required this.purchaseInvoiceCount,
    required this.topProducts,
    required this.topSuppliers,
    required this.trend,
  });

  final double totalSales;
  final double totalPurchases;
  final double cogs;
  final double expenses;
  final double outstandingCustomerDebt;
  final double outstandingSupplierDebt;
  final int salesInvoiceCount;
  final int purchaseInvoiceCount;
  final List<TopSellingProduct> topProducts;
  final List<TopSupplier> topSuppliers;
  final List<TrendPoint> trend;

  double get grossProfit => totalSales - cogs;
  double get netProfit => grossProfit - expenses;
  int get totalInvoices => salesInvoiceCount + purchaseInvoiceCount;
}

class DashboardInvoiceRecord {
  const DashboardInvoiceRecord({
    required this.id,
    required this.invoiceNumber,
    required this.accountName,
    required this.status,
    required this.totalAmount,
    required this.paidAmount,
    required this.outstandingAmount,
    required this.createdAt,
    required this.type,
    this.paymentMethodRaw,
    this.paidCash = 0,
    this.paidVodafone = 0,
    this.paidVisa = 0,
  });

  final int id;
  final String invoiceNumber;
  final String accountName;
  final String status;
  final double totalAmount;
  final double paidAmount;
  final double outstandingAmount;

  /// Sale invoice totals by payment channel (excluding reversals/refunds).
  final double paidCash;
  final double paidVodafone;
  final double paidVisa;
  final DateTime createdAt;
  final String type;

  /// Distinct payment methods from DB; sale drilldown only.
  final String? paymentMethodRaw;
}

class DashboardProfitRecord {
  const DashboardProfitRecord({
    required this.saleId,
    required this.invoiceNumber,
    required this.accountName,
    required this.revenue,
    required this.cogs,
    required this.grossProfit,
    required this.createdAt,
  });

  final int saleId;
  final String invoiceNumber;
  final String accountName;
  final double revenue;
  final double cogs;
  final double grossProfit;
  final DateTime createdAt;
}

class DashboardRepository {
  DashboardRepository(this._dbProvider, this._sessionService);

  final AppDatabase _dbProvider;
  final SessionService _sessionService;
  bool _indexesReady = false;
  static const Duration _snapshotCacheTtl = Duration(seconds: 30);
  final Map<String, _SnapshotCacheEntry> _snapshotCache =
      <String, _SnapshotCacheEntry>{};

  void invalidateSnapshotCache() {
    _snapshotCache.clear();
  }

  Future<void> _ensureIndexes() async {
    if (_indexesReady) return;
    final db = await _dbProvider.database;
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_created_at ON sales(created_at);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchases_created_at ON purchases(created_at);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id ON sale_items(sale_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchase_items_purchase_id ON purchase_items(purchase_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_returns_line ON returns(invoice_type, original_line_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_returns_invoice ON returns(invoice_type, invoice_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payments_invoice_lookup ON payments(invoice_type, invoice_id, reversal_for_id);',
    );
    _indexesReady = true;
  }

  Future<List<DashboardFilterOption>> getCategories() async {
    await _ensureIndexes();
    final db = await _dbProvider.database;
    final rows = await db.query('categories', orderBy: 'name ASC');
    return rows
        .map(
          (e) => DashboardFilterOption(
            id: (e['id'] as num).toInt(),
            name: (e['name'] as String?) ?? 'Unknown',
          ),
        )
        .toList();
  }

  Future<List<DashboardFilterOption>> getAccounts() async {
    await _ensureIndexes();
    final db = await _dbProvider.database;
    final rows = await db.query(
      'accounts',
      where: "account_type IN ('customer', 'supplier')",
      orderBy: 'name ASC',
    );
    return rows
        .map(
          (e) => DashboardFilterOption(
            id: (e['id'] as num).toInt(),
            name: (e['name'] as String?) ?? 'Unknown',
          ),
        )
        .toList();
  }

  Future<DashboardSnapshot> getDashboardSnapshot({
    required DateTime from,
    required DateTime to,
    required String granularity,
    int? categoryId,
    int? accountId,
  }) async {
    final cacheKey = _snapshotKey(
      from: from,
      to: to,
      granularity: granularity,
      categoryId: categoryId,
      accountId: accountId,
    );
    _snapshotCache.removeWhere(
      (_, entry) =>
          DateTime.now().difference(entry.cachedAt) > _snapshotCacheTtl,
    );
    final cached = _snapshotCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.cachedAt) <= _snapshotCacheTtl) {
      return cached.snapshot;
    }

    await _ensureIndexes();
    final db = await _dbProvider.database;

    final salesFilter = _dateFilter(
      tableAlias: 's',
      from: from,
      to: to,
      accountId: accountId,
      includeCancelled: false,
    );
    final purchaseFilter = _dateFilter(
      tableAlias: 'p',
      from: from,
      to: to,
      accountId: accountId,
      includeCancelled: false,
    );
    _appendInvoiceScope(
      where: salesFilter.where,
      args: salesFilter.args,
      tableAlias: 's',
    );
    _appendInvoiceScope(
      where: purchaseFilter.where,
      args: purchaseFilter.args,
      tableAlias: 'p',
    );

    final salesInvoiceWhere = <String>[...salesFilter.where];
    final salesInvoiceArgs = <Object?>[...salesFilter.args];
    if (categoryId != null) {
      salesInvoiceWhere.add('''
        EXISTS (
          SELECT 1
          FROM stock_movements sm
          JOIN products pr ON pr.id = sm.product_id
          WHERE sm.invoice_type = 'sale'
            AND sm.invoice_id = s.id
            AND sm.movement_type = 'out'
            AND pr.category_id = ?
        )
      ''');
      salesInvoiceArgs.add(categoryId);
    }

    final purchaseInvoiceWhere = <String>[...purchaseFilter.where];
    final purchaseInvoiceArgs = <Object?>[...purchaseFilter.args];
    if (categoryId != null) {
      purchaseInvoiceWhere.add('''
        EXISTS (
          SELECT 1
          FROM stock_movements sm
          JOIN products pr ON pr.id = sm.product_id
          WHERE sm.invoice_type = 'purchase'
            AND sm.invoice_id = p.id
            AND sm.movement_type = 'in'
            AND pr.category_id = ?
        )
      ''');
      purchaseInvoiceArgs.add(categoryId);
    }

    final totalSalesRow = await db.rawQuery('''
      SELECT COALESCE(SUM(s.total_amount), 0) AS value
      FROM sales s
      WHERE ${salesInvoiceWhere.join(' AND ')}
      ''', salesInvoiceArgs);

    final totalPurchasesRow = await db.rawQuery('''
      SELECT COALESCE(SUM(p.total_amount), 0) AS value
      FROM purchases p
      WHERE ${purchaseInvoiceWhere.join(' AND ')}
      ''', purchaseInvoiceArgs);

    final cogsWhere = <String>[
      "sm.invoice_type = 'sale'",
      "sm.movement_type = 'out'",
      ...salesFilter.where,
    ];
    final cogsArgs = <Object?>[...salesFilter.args];
    if (categoryId != null) {
      cogsWhere.add('pr.category_id = ?');
      cogsArgs.add(categoryId);
    }

    final cogsRow = await db.rawQuery('''
      SELECT COALESCE(SUM(sm.quantity * pr.purchase_price), 0) AS value
      FROM stock_movements sm
      JOIN sales s ON s.id = sm.invoice_id
      JOIN products pr ON pr.id = sm.product_id
      WHERE ${cogsWhere.join(' AND ')}
      ''', cogsArgs);

    final salesCountRow = await db.rawQuery('''
      SELECT COUNT(*) AS value
      FROM sales s
      WHERE ${salesFilter.where.join(' AND ')}
      ''', salesFilter.args);

    final purchaseCountRow = await db.rawQuery('''
      SELECT COUNT(*) AS value
      FROM purchases p
      WHERE ${purchaseFilter.where.join(' AND ')}
      ''', purchaseFilter.args);

    final expenseWhere = <String>[
      "lt.source_type = 'expense'",
      'datetime(lt.created_at) >= datetime(?)',
      'datetime(lt.created_at) < datetime(?)',
    ];
    final expenseArgs = <Object?>[
      from.toIso8601String(),
      DateTime(
        to.year,
        to.month,
        to.day,
      ).add(const Duration(days: 1)).toIso8601String(),
    ];
    if (accountId != null) {
      expenseWhere.add('lt.account_id = ?');
      expenseArgs.add(accountId);
    }

    final operatingExpenseRow = await db.rawQuery('''
      SELECT COALESCE(SUM(
        CASE
          WHEN a.account_type = 'expense' AND lt.entry_kind = 'debit' THEN lt.amount
          WHEN a.account_type = 'expense' AND lt.entry_kind = 'credit' THEN -lt.amount
          ELSE 0
        END
      ), 0) AS value
      FROM ledger_transactions lt
      JOIN accounts a ON a.id = lt.account_id
      WHERE ${expenseWhere.join(' AND ')}
      ''', expenseArgs);

    final customerDebtArgs = <Object?>[
      from.toIso8601String(),
      DateTime(
        to.year,
        to.month,
        to.day,
      ).add(const Duration(days: 1)).toIso8601String(),
    ];
    if (accountId != null) {
      customerDebtArgs.add(accountId);
    }

    final customerDebtRow = await db.rawQuery('''
      SELECT COALESCE(SUM(
        CASE
          WHEN lt.entry_kind IN ('debit', 'reversal') THEN lt.amount
          WHEN lt.entry_kind = 'credit' THEN -lt.amount
          ELSE 0
        END
      ), 0) AS value
      FROM ledger_transactions lt
      JOIN accounts a ON a.id = lt.account_id
      WHERE a.account_type = 'customer'
        AND datetime(lt.created_at) >= datetime(?)
        AND datetime(lt.created_at) < datetime(?)
        AND lt.reversal_for_id IS NULL
        ${accountId == null ? '' : 'AND a.id = ?'}
      ''', customerDebtArgs);

    final supplierDebtArgs = <Object?>[
      from.toIso8601String(),
      DateTime(
        to.year,
        to.month,
        to.day,
      ).add(const Duration(days: 1)).toIso8601String(),
    ];
    if (accountId != null) {
      supplierDebtArgs.add(accountId);
    }

    final supplierDebtRow = await db.rawQuery('''
      SELECT COALESCE(SUM(
        CASE
          WHEN lt.entry_kind IN ('debit', 'reversal') THEN -lt.amount
          WHEN lt.entry_kind = 'credit' THEN lt.amount
          ELSE 0
        END
      ), 0) AS value
      FROM ledger_transactions lt
      JOIN accounts a ON a.id = lt.account_id
      WHERE a.account_type = 'supplier'
        AND datetime(lt.created_at) >= datetime(?)
        AND datetime(lt.created_at) < datetime(?)
        AND lt.reversal_for_id IS NULL
        ${accountId == null ? '' : 'AND a.id = ?'}
      ''', supplierDebtArgs);

    final topProductsWhere = <String>[
      "sm.invoice_type = 'sale'",
      "sm.movement_type = 'out'",
      ...salesFilter.where,
    ];
    final topProductsArgs = <Object?>[...salesFilter.args];
    if (categoryId != null) {
      topProductsWhere.add('pr.category_id = ?');
      topProductsArgs.add(categoryId);
    }

    final topProductsRows = await db.rawQuery('''
      SELECT
        pr.name AS product_name,
        COALESCE(SUM(sm.quantity), 0) AS qty,
        COALESCE(SUM(sm.quantity * pr.sale_price), 0) AS revenue
      FROM stock_movements sm
      JOIN sales s ON s.id = sm.invoice_id
      JOIN products pr ON pr.id = sm.product_id
      WHERE ${topProductsWhere.join(' AND ')}
      GROUP BY pr.id, pr.name
      ORDER BY qty DESC, revenue DESC
      LIMIT 8
      ''', topProductsArgs);

    final topSuppliersRows = await db.rawQuery('''
      SELECT
        a.name AS supplier_name,
        COALESCE(SUM(p.total_amount), 0) AS volume
      FROM purchases p
      JOIN accounts a ON a.id = p.account_id
      WHERE ${purchaseInvoiceWhere.join(' AND ')}
      GROUP BY a.id, a.name
      ORDER BY volume DESC
      LIMIT 8
      ''', purchaseInvoiceArgs);

    final salesDailyRows = await db.rawQuery('''
      SELECT
        date(s.created_at) AS d,
        COALESCE(SUM(s.total_amount), 0) AS value
      FROM sales s
      WHERE ${salesInvoiceWhere.join(' AND ')}
      GROUP BY date(s.created_at)
      ORDER BY date(s.created_at) ASC
      ''', salesInvoiceArgs);

    final purchasesDailyRows = await db.rawQuery('''
      SELECT
        date(p.created_at) AS d,
        COALESCE(SUM(p.total_amount), 0) AS value
      FROM purchases p
      WHERE ${purchaseInvoiceWhere.join(' AND ')}
      GROUP BY date(p.created_at)
      ORDER BY date(p.created_at) ASC
      ''', purchaseInvoiceArgs);

    final totalSales = ((totalSalesRow.first['value'] ?? 0) as num).toDouble();
    final totalPurchases = ((totalPurchasesRow.first['value'] ?? 0) as num)
        .toDouble();
    final cogs = ((cogsRow.first['value'] ?? 0) as num).toDouble();
    final salesInvoiceCount = ((salesCountRow.first['value'] ?? 0) as num)
        .toInt();
    final purchaseInvoiceCount = ((purchaseCountRow.first['value'] ?? 0) as num)
        .toInt();
    final operatingExpenses = ((operatingExpenseRow.first['value'] ?? 0) as num)
        .toDouble();
    final customerDebt = ((customerDebtRow.first['value'] ?? 0) as num)
        .toDouble();
    final supplierDebt = ((supplierDebtRow.first['value'] ?? 0) as num)
        .toDouble();

    final topProducts = topProductsRows
        .map(
          (e) => TopSellingProduct(
            productName: (e['product_name'] as String?) ?? 'Unknown',
            quantity: ((e['qty'] ?? 0) as num).toDouble(),
            revenue: ((e['revenue'] ?? 0) as num).toDouble(),
          ),
        )
        .toList();

    final topSuppliers = topSuppliersRows
        .map(
          (e) => TopSupplier(
            supplierName: (e['supplier_name'] as String?) ?? 'Unknown',
            volume: ((e['volume'] ?? 0) as num).toDouble(),
          ),
        )
        .toList();

    final trend = _buildTrend(
      salesDailyRows: salesDailyRows,
      purchasesDailyRows: purchasesDailyRows,
      granularity: granularity,
    );

    final snapshot = DashboardSnapshot(
      totalSales: totalSales,
      totalPurchases: totalPurchases,
      cogs: cogs,
      expenses: operatingExpenses,
      outstandingCustomerDebt: customerDebt < 0 ? 0 : customerDebt,
      outstandingSupplierDebt: supplierDebt < 0 ? 0 : supplierDebt,
      salesInvoiceCount: salesInvoiceCount,
      purchaseInvoiceCount: purchaseInvoiceCount,
      topProducts: topProducts,
      topSuppliers: topSuppliers,
      trend: trend,
    );
    _snapshotCache[cacheKey] = _SnapshotCacheEntry(
      snapshot: snapshot,
      cachedAt: DateTime.now(),
    );
    return snapshot;
  }

  String _snapshotKey({
    required DateTime from,
    required DateTime to,
    required String granularity,
    int? categoryId,
    int? accountId,
  }) {
    final scope = _invoiceScopeSql('x');
    final scopeKey = scope == null ? 'all-users' : 'user-${scope.$2}';
    return '${from.toIso8601String()}|${to.toIso8601String()}|$granularity|${categoryId ?? 'all'}|${accountId ?? 'all'}|$scopeKey';
  }

  void _appendInvoiceScope({
    required List<String> where,
    required List<Object?> args,
    required String tableAlias,
  }) {
    final scope = _invoiceScopeSql(tableAlias);
    if (scope == null) return;
    where.add(scope.$1);
    args.add(scope.$2);
  }

  (String, int)? _invoiceScopeSql(String alias) {
    final user = _sessionService.currentUser;
    if (user == null || _sessionService.canViewAllInvoices) {
      return null;
    }
    return ('$alias.created_by_user_id = ?', user.id);
  }

  Future<List<DashboardInvoiceRecord>> getSalesInvoices({
    required DateTime from,
    required DateTime to,
    int? categoryId,
    int? accountId,
    bool onlyUnpaid = false,
    int? limit,
    int offset = 0,
  }) async {
    await _ensureIndexes();
    final db = await _dbProvider.database;

    final filter = _dateFilter(
      tableAlias: 's',
      from: from,
      to: to,
      accountId: accountId,
      includeCancelled: false,
    );

    final where = <String>[...filter.where];
    final args = <Object?>[...filter.args];
    _appendInvoiceScope(where: where, args: args, tableAlias: 's');

    if (categoryId != null) {
      where.add(
        'EXISTS (SELECT 1 FROM sale_items si JOIN products pr ON pr.id = si.product_id WHERE si.sale_id = s.id AND pr.category_id = ?)',
      );
      args.add(categoryId);
    }

    if (onlyUnpaid) {
      where.add('''(
        s.total_amount - COALESCE((
          SELECT SUM(pp.amount)
          FROM payments pp
          WHERE pp.invoice_type = 'sale'
            AND pp.invoice_id = s.id
            AND pp.reversal_for_id IS NULL
            AND pp.is_refund = 0
            AND pp.amount > 0
        ), 0)
      ) > 0.00001''');

      final endExclusive = DateTime(
        to.year,
        to.month,
        to.day,
      ).add(const Duration(days: 1));
      where.add('''
        (
          s.account_id IS NULL
          OR EXISTS (
            SELECT 1
            FROM ledger_transactions lt_account
            WHERE lt_account.account_id = a.id
              AND lt_account.reversal_for_id IS NULL
              AND datetime(lt_account.created_at) >= datetime(?)
              AND datetime(lt_account.created_at) < datetime(?)
            GROUP BY lt_account.account_id
            HAVING COALESCE(SUM(
              CASE
                WHEN lt_account.entry_kind IN ('debit', 'reversal') THEN lt_account.amount
                WHEN lt_account.entry_kind = 'credit' THEN -lt_account.amount
                ELSE 0
              END
            ), 0) > 0.00001
          )
        )
      ''');
      args.add(from.toIso8601String());
      args.add(endExclusive.toIso8601String());
    }

    final limitClause = limit == null ? '' : ' LIMIT ? OFFSET ? ';
    if (limit != null) {
      args.add(limit);
      args.add(offset);
    }

    final rows = await db.rawQuery('''
      SELECT
        s.id,
        s.invoice_number,
        s.status,
        s.total_amount,
        COALESCE((
          SELECT SUM(pp.amount)
          FROM payments pp
          WHERE pp.invoice_type = 'sale'
            AND pp.invoice_id = s.id
            AND pp.reversal_for_id IS NULL
            AND pp.is_refund = 0
            AND pp.amount > 0
        ), 0) AS paid_amount,
        (
          s.total_amount - COALESCE((
            SELECT SUM(pp.amount)
            FROM payments pp
            WHERE pp.invoice_type = 'sale'
              AND pp.invoice_id = s.id
              AND pp.reversal_for_id IS NULL
              AND pp.is_refund = 0
              AND pp.amount > 0
          ), 0)
        ) AS outstanding_amount,
        COALESCE((
          SELECT SUM(pp.amount)
          FROM payments pp
          WHERE pp.invoice_type = 'sale'
            AND pp.invoice_id = s.id
            AND pp.reversal_for_id IS NULL
            AND pp.is_refund = 0
            AND pp.amount > 0
            AND pp.payment_method = 'cash'
        ), 0) AS paid_cash,
        COALESCE((
          SELECT SUM(pp.amount)
          FROM payments pp
          WHERE pp.invoice_type = 'sale'
            AND pp.invoice_id = s.id
            AND pp.reversal_for_id IS NULL
            AND pp.is_refund = 0
            AND pp.amount > 0
            AND pp.payment_method = 'vodafone_cash'
        ), 0) AS paid_vodafone,
        COALESCE((
          SELECT SUM(pp.amount)
          FROM payments pp
          WHERE pp.invoice_type = 'sale'
            AND pp.invoice_id = s.id
            AND pp.reversal_for_id IS NULL
            AND pp.is_refund = 0
            AND pp.amount > 0
            AND pp.payment_method = 'visa'
        ), 0) AS paid_visa,
        s.created_at,
        COALESCE(a.name, 'Walk-in') AS account_name,
        COALESCE(
          NULLIF(TRIM(COALESCE((
            SELECT GROUP_CONCAT(DISTINCT payment_method)
            FROM payments
            WHERE invoice_type = 'sale'
              AND invoice_id = s.id
              AND reversal_for_id IS NULL
              AND is_refund = 0
              AND amount > 0
          ), '')), ''),
          NULLIF(TRIM(s.primary_payment_method), '')
        ) AS payment_method_raw
      FROM sales s
      LEFT JOIN accounts a ON a.id = s.account_id
      WHERE ${where.join(' AND ')}
      ORDER BY datetime(s.created_at) DESC, s.id DESC
      $limitClause
      ''', args);

    return rows
        .map(
          (e) => DashboardInvoiceRecord(
            id: (e['id'] as num).toInt(),
            invoiceNumber: (e['invoice_number'] as String?) ?? '-',
            accountName: (e['account_name'] as String?) ?? 'Walk-in',
            status: (e['status'] as String?) ?? 'completed',
            totalAmount: ((e['total_amount'] ?? 0) as num).toDouble(),
            paidAmount: ((e['paid_amount'] ?? 0) as num).toDouble(),
            outstandingAmount: ((e['outstanding_amount'] ?? 0) as num)
                .toDouble(),
            paidCash: ((e['paid_cash'] ?? 0) as num).toDouble(),
            paidVodafone: ((e['paid_vodafone'] ?? 0) as num).toDouble(),
            paidVisa: ((e['paid_visa'] ?? 0) as num).toDouble(),
            createdAt: DateTime.parse(e['created_at'] as String),
            type: 'sale',
            paymentMethodRaw: () {
              final raw = e['payment_method_raw'] as String?;
              if (raw == null || raw.trim().isEmpty) return null;
              return raw.trim();
            }(),
          ),
        )
        .toList();
  }

  Future<List<DashboardInvoiceRecord>> getPurchaseInvoices({
    required DateTime from,
    required DateTime to,
    int? categoryId,
    int? accountId,
    bool onlyUnpaid = false,
    int? limit,
    int offset = 0,
  }) async {
    await _ensureIndexes();
    final db = await _dbProvider.database;

    final filter = _dateFilter(
      tableAlias: 'p',
      from: from,
      to: to,
      accountId: accountId,
      includeCancelled: false,
    );

    final where = <String>[...filter.where];
    final args = <Object?>[...filter.args];
    _appendInvoiceScope(where: where, args: args, tableAlias: 'p');

    if (categoryId != null) {
      where.add(
        'EXISTS (SELECT 1 FROM purchase_items pi JOIN products pr ON pr.id = pi.product_id WHERE pi.purchase_id = p.id AND pr.category_id = ?)',
      );
      args.add(categoryId);
    }

    if (onlyUnpaid) {
      where.add('''(
        MAX(
          0,
          (
            COALESCE((
              SELECT SUM(ltp.amount)
              FROM ledger_transactions ltp
              WHERE ltp.source_type = 'purchase'
                AND ltp.source_id = p.id
                AND ltp.entry_kind = 'credit'
                AND ltp.reversal_for_id IS NULL
            ), p.total_amount)
            -
            COALESCE((
              SELECT SUM(ltr.amount)
              FROM returns r
              JOIN ledger_transactions ltr ON ltr.source_type = 'return' AND ltr.source_id = r.id
              WHERE r.invoice_type = 'purchase'
                AND r.invoice_id = p.id
                AND ltr.entry_kind = 'debit'
                AND ltr.reversal_for_id IS NULL
            ), 0)
            -
            COALESCE((
              SELECT SUM(pp.amount)
              FROM payments pp
              WHERE pp.invoice_type = 'purchase'
                AND pp.invoice_id = p.id
                AND pp.reversal_for_id IS NULL
            ), 0)
          )
        )
      ) > 0.00001''');

      final endExclusive = DateTime(
        to.year,
        to.month,
        to.day,
      ).add(const Duration(days: 1));
      where.add('''
        EXISTS (
          SELECT 1
          FROM ledger_transactions lt_account
          WHERE lt_account.account_id = a.id
            AND lt_account.reversal_for_id IS NULL
            AND datetime(lt_account.created_at) >= datetime(?)
            AND datetime(lt_account.created_at) < datetime(?)
          GROUP BY lt_account.account_id
          HAVING COALESCE(SUM(
            CASE
              WHEN lt_account.entry_kind IN ('debit', 'reversal') THEN -lt_account.amount
              WHEN lt_account.entry_kind = 'credit' THEN lt_account.amount
              ELSE 0
            END
          ), 0) > 0.00001
        )
      ''');
      args.add(from.toIso8601String());
      args.add(endExclusive.toIso8601String());
    }

    final limitClause = limit == null ? '' : ' LIMIT ? OFFSET ? ';
    if (limit != null) {
      args.add(limit);
      args.add(offset);
    }

    final rows = await db.rawQuery('''
      SELECT
        p.id,
        p.invoice_number,
        p.status,
        MAX(
          0,
          (
            COALESCE((
              SELECT SUM(ltp.amount)
              FROM ledger_transactions ltp
              WHERE ltp.source_type = 'purchase'
                AND ltp.source_id = p.id
                AND ltp.entry_kind = 'credit'
                AND ltp.reversal_for_id IS NULL
            ), p.total_amount)
            -
            COALESCE((
              SELECT SUM(ltr.amount)
              FROM returns r
              JOIN ledger_transactions ltr ON ltr.source_type = 'return' AND ltr.source_id = r.id
              WHERE r.invoice_type = 'purchase'
                AND r.invoice_id = p.id
                AND ltr.entry_kind = 'debit'
                AND ltr.reversal_for_id IS NULL
            ), 0)
          )
        ) AS total_amount,
        COALESCE((
          SELECT SUM(pp.amount)
          FROM payments pp
          WHERE pp.invoice_type = 'purchase'
            AND pp.invoice_id = p.id
            AND pp.reversal_for_id IS NULL
        ), 0) AS paid_amount,
        (
          MAX(
            0,
            (
              COALESCE((
                SELECT SUM(ltp.amount)
                FROM ledger_transactions ltp
                WHERE ltp.source_type = 'purchase'
                  AND ltp.source_id = p.id
                  AND ltp.entry_kind = 'credit'
                  AND ltp.reversal_for_id IS NULL
              ), p.total_amount)
              -
              COALESCE((
                SELECT SUM(ltr.amount)
                FROM returns r
                JOIN ledger_transactions ltr ON ltr.source_type = 'return' AND ltr.source_id = r.id
                WHERE r.invoice_type = 'purchase'
                  AND r.invoice_id = p.id
                  AND ltr.entry_kind = 'debit'
                  AND ltr.reversal_for_id IS NULL
              ), 0)
            )
          ) - COALESCE((
            SELECT SUM(pp.amount)
            FROM payments pp
            WHERE pp.invoice_type = 'purchase'
              AND pp.invoice_id = p.id
              AND pp.reversal_for_id IS NULL
          ), 0)
        ) AS outstanding_amount,
        p.created_at,
        a.name AS account_name
      FROM purchases p
      JOIN accounts a ON a.id = p.account_id
      WHERE ${where.join(' AND ')}
      ORDER BY datetime(p.created_at) DESC, p.id DESC
      $limitClause
      ''', args);

    return rows
        .map(
          (e) => DashboardInvoiceRecord(
            id: (e['id'] as num).toInt(),
            invoiceNumber: (e['invoice_number'] as String?) ?? '-',
            accountName: (e['account_name'] as String?) ?? 'Unknown',
            status: (e['status'] as String?) ?? 'completed',
            totalAmount: ((e['total_amount'] ?? 0) as num).toDouble(),
            paidAmount: ((e['paid_amount'] ?? 0) as num).toDouble(),
            outstandingAmount: ((e['outstanding_amount'] ?? 0) as num)
                .toDouble(),
            createdAt: DateTime.parse(e['created_at'] as String),
            type: 'purchase',
          ),
        )
        .toList();
  }

  Future<List<DashboardInvoiceRecord>> getExpenseEntries({
    required DateTime from,
    required DateTime to,
    int? accountId,
    int? limit,
    int offset = 0,
  }) async {
    await _ensureIndexes();
    final db = await _dbProvider.database;

    final endExclusive = DateTime(
      to.year,
      to.month,
      to.day,
    ).add(const Duration(days: 1));

    final where = <String>[
      'datetime(e.created_at) >= datetime(?)',
      'datetime(e.created_at) < datetime(?)',
      "a.account_type = 'expense'",
    ];
    final args = <Object?>[
      from.toIso8601String(),
      endExclusive.toIso8601String(),
    ];

    if (accountId != null) {
      where.add('e.account_id = ?');
      args.add(accountId);
    }

    final limitClause = limit == null ? '' : ' LIMIT ? OFFSET ? ';
    if (limit != null) {
      args.add(limit);
      args.add(offset);
    }

    final rows = await db.rawQuery('''
      SELECT
        e.id,
        'EXP-' || e.id AS invoice_number,
        'posted' AS status,
        e.amount AS total_amount,
        e.amount AS paid_amount,
        0.0 AS outstanding_amount,
        e.created_at,
        a.name AS account_name
      FROM expenses e
      JOIN accounts a ON a.id = e.account_id
      WHERE ${where.join(' AND ')}
      ORDER BY datetime(e.created_at) DESC, e.id DESC
      $limitClause
      ''', args);

    return rows
        .map(
          (e) => DashboardInvoiceRecord(
            id: (e['id'] as num).toInt(),
            invoiceNumber: (e['invoice_number'] as String?) ?? '-',
            accountName: (e['account_name'] as String?) ?? 'Expense',
            status: (e['status'] as String?) ?? 'posted',
            totalAmount: ((e['total_amount'] ?? 0) as num).toDouble(),
            paidAmount: ((e['paid_amount'] ?? 0) as num).toDouble(),
            outstandingAmount: ((e['outstanding_amount'] ?? 0) as num)
                .toDouble(),
            createdAt: DateTime.parse(e['created_at'] as String),
            type: 'expense',
          ),
        )
        .toList();
  }

  Future<List<DashboardInvoiceRecord>> getExpenseBreakdownEntries({
    required DateTime from,
    required DateTime to,
    int? categoryId,
    int? accountId,
    int? limit,
    int offset = 0,
  }) async {
    final expenseRows = await getExpenseEntries(
      from: from,
      to: to,
      accountId: accountId,
      limit: null,
    );

    final merged = <DashboardInvoiceRecord>[...expenseRows]
      ..sort((a, b) {
        final byDate = b.createdAt.compareTo(a.createdAt);
        if (byDate != 0) return byDate;
        return b.id.compareTo(a.id);
      });

    if (limit == null) {
      return merged;
    }

    final safeOffset = offset < 0 ? 0 : offset;
    if (safeOffset >= merged.length) {
      return const <DashboardInvoiceRecord>[];
    }
    final end = (safeOffset + limit).clamp(0, merged.length);
    return merged.sublist(safeOffset, end);
  }

  Future<List<DashboardProfitRecord>> getProfitBreakdown({
    required DateTime from,
    required DateTime to,
    int? categoryId,
    int? accountId,
    int? limit,
    int offset = 0,
  }) async {
    await _ensureIndexes();
    final db = await _dbProvider.database;

    final filter = _dateFilter(
      tableAlias: 's',
      from: from,
      to: to,
      accountId: accountId,
      includeCancelled: false,
    );
    final where = <String>[...filter.where];
    final args = <Object?>[...filter.args];
    _appendInvoiceScope(where: where, args: args, tableAlias: 's');

    String cogsCategoryClause = '';
    if (categoryId != null) {
      // Match dashboard snapshot semantics: include whole sale invoice if it contains the category.
      where.add('''
        EXISTS (
          SELECT 1
          FROM stock_movements smf
          JOIN products prf ON prf.id = smf.product_id
          WHERE smf.invoice_type = 'sale'
            AND smf.invoice_id = s.id
            AND smf.movement_type = 'out'
            AND prf.category_id = ?
        )
      ''');
      args.add(categoryId);
      cogsCategoryClause = ' AND prc.category_id = ?';
    }

    final limitClause = limit == null ? '' : ' LIMIT ? OFFSET ? ';
    final queryArgs = <Object?>[...args];
    if (categoryId != null) {
      queryArgs.add(categoryId);
    }
    if (limit != null) {
      queryArgs.add(limit);
      queryArgs.add(offset);
    }

    final rows = await db.rawQuery('''
      SELECT
        s.id,
        s.invoice_number,
        COALESCE(a.name, 'Walk-in') AS account_name,
        s.created_at,
        COALESCE(s.total_amount, 0) AS revenue,
        COALESCE((
          SELECT SUM(smc.quantity * prc.purchase_price)
          FROM stock_movements smc
          JOIN products prc ON prc.id = smc.product_id
          WHERE smc.invoice_type = 'sale'
            AND smc.invoice_id = s.id
            AND smc.movement_type = 'out'
            $cogsCategoryClause
        ), 0) AS cogs
      FROM sales s
      LEFT JOIN accounts a ON a.id = s.account_id
      WHERE ${where.join(' AND ')}
      ORDER BY datetime(s.created_at) DESC, s.id DESC
      $limitClause
      ''', queryArgs);

    return rows.map((e) {
      final revenue = ((e['revenue'] ?? 0) as num).toDouble();
      final cogs = ((e['cogs'] ?? 0) as num).toDouble();
      return DashboardProfitRecord(
        saleId: (e['id'] as num).toInt(),
        invoiceNumber: (e['invoice_number'] as String?) ?? '-',
        accountName: (e['account_name'] as String?) ?? 'Walk-in',
        revenue: revenue,
        cogs: cogs,
        grossProfit: revenue - cogs,
        createdAt: DateTime.parse(e['created_at'] as String),
      );
    }).toList();
  }

  _SqlFilter _dateFilter({
    required String tableAlias,
    required DateTime from,
    required DateTime to,
    int? accountId,
    bool includeCancelled = true,
  }) {
    final endExclusive = DateTime(
      to.year,
      to.month,
      to.day,
    ).add(const Duration(days: 1));

    final where = <String>[
      'datetime($tableAlias.created_at) >= datetime(?)',
      'datetime($tableAlias.created_at) < datetime(?)',
    ];
    final args = <Object?>[
      from.toIso8601String(),
      endExclusive.toIso8601String(),
    ];

    if (!includeCancelled) {
      where.add('($tableAlias.status IS NULL OR $tableAlias.status != ?)');
      args.add('cancelled');
    }

    if (accountId != null) {
      where.add('$tableAlias.account_id = ?');
      args.add(accountId);
    }

    return _SqlFilter(where: where, args: args);
  }

  List<TrendPoint> _buildTrend({
    required List<Map<String, Object?>> salesDailyRows,
    required List<Map<String, Object?>> purchasesDailyRows,
    required String granularity,
  }) {
    final rawSales = <DateTime, double>{};
    final rawPurchases = <DateTime, double>{};

    for (final row in salesDailyRows) {
      final d = DateTime.parse(
        (row['d'] as String?) ?? DateTime.now().toString(),
      );
      rawSales[d] = ((row['value'] ?? 0) as num).toDouble();
    }
    for (final row in purchasesDailyRows) {
      final d = DateTime.parse(
        (row['d'] as String?) ?? DateTime.now().toString(),
      );
      rawPurchases[d] = ((row['value'] ?? 0) as num).toDouble();
    }

    final buckets = SplayTreeMap<String, _TrendAccumulator>();

    void addPoint(DateTime date, double sales, double purchases) {
      final key = _bucketKey(date, granularity);
      final entry = buckets.putIfAbsent(key, _TrendAccumulator.new);
      entry.sales += sales;
      entry.purchases += purchases;
    }

    for (final e in rawSales.entries) {
      addPoint(e.key, e.value, 0);
    }
    for (final e in rawPurchases.entries) {
      addPoint(e.key, 0, e.value);
    }

    return buckets.entries
        .map(
          (e) => TrendPoint(
            label: e.key,
            sales: e.value.sales,
            purchases: e.value.purchases,
          ),
        )
        .toList();
  }

  String _bucketKey(DateTime date, String granularity) {
    if (granularity == 'week') {
      final weekStart = date.subtract(Duration(days: date.weekday - 1));
      return '${weekStart.year.toString().padLeft(4, '0')}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
    }
    if (granularity == 'month') {
      return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
    }
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _SqlFilter {
  const _SqlFilter({required this.where, required this.args});

  final List<String> where;
  final List<Object?> args;
}

class _TrendAccumulator {
  double sales = 0;
  double purchases = 0;
}

class _SnapshotCacheEntry {
  const _SnapshotCacheEntry({required this.snapshot, required this.cachedAt});

  final DashboardSnapshot snapshot;
  final DateTime cachedAt;
}
