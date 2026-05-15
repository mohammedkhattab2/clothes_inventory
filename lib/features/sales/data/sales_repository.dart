import 'package:clothes_inventory/core/utils/number_utils.dart';
import 'package:clothes_inventory/core/utils/return_rules.dart';
import 'package:clothes_inventory/core/utils/sql_like_escape.dart';
import 'package:clothes_inventory/features/invoices/domain/invoice_suggestion.dart';
import 'package:clothes_inventory/features/sales/domain/sale_models.dart';
import 'package:clothes_inventory/services/auth/session_service.dart';
import 'package:clothes_inventory/services/database/app_database.dart';
import 'package:sqflite/sqlite_api.dart';
import 'package:clothes_inventory/services/database/db_transaction_runner.dart';
import 'package:clothes_inventory/services/database/invoice_sequence_allocator.dart';

class SalesInvoiceSummary {
  const SalesInvoiceSummary({
    required this.id,
    required this.invoiceNumber,
    required this.productsSummary,
    required this.accountName,
    required this.status,
    required this.totalAmount,
    required this.paidAmount,
    required this.outstandingAmount,
    required this.createdAt,
  });

  final int id;
  final String invoiceNumber;
  final String productsSummary;
  final String accountName;
  final String status;
  final double totalAmount;
  final double paidAmount;
  final double outstandingAmount;
  final DateTime createdAt;
}

class SalesInvoiceLine {
  const SalesInvoiceLine({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.returnedQuantity,
    required this.remainingQuantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final int id;
  final String productName;
  final double quantity;
  final double returnedQuantity;
  final double remainingQuantity;
  final double unitPrice;
  final double lineTotal;
}

class AmendmentPaymentSnapshot {
  const AmendmentPaymentSnapshot({
    required this.paidCash,
    required this.paidWallet,
    required this.method,
  });

  final double paidCash;
  final double paidWallet;
  final PaymentMethod method;
}

class PendingSaleDraft {
  const PendingSaleDraft({
    required this.saleId,
    required this.customerId,
    required this.customerName,
    required this.headerDiscountKind,
    required this.headerDiscountValue,
    required this.items,
    this.amendmentPayments,
    this.amendmentStockCreditByProduct = const <int, double>{},
  });

  final int saleId;
  final int? customerId;
  final String? customerName;
  final InvoiceHeaderDiscountKind headerDiscountKind;
  final double headerDiscountValue;
  final List<SaleDraftItem> items;

  /// When set, cart was loaded for editing an existing completed/partial invoice.
  final AmendmentPaymentSnapshot? amendmentPayments;

  /// Per-product quantities that were on the invoice at load time; used to
  /// compute effective available stock during checkout while original `out`
  /// movements still exist in the DB.
  final Map<int, double> amendmentStockCreditByProduct;
}

class SalesRepository {
  const SalesRepository(
    this._appDatabase,
    this._transactionRunner,
    this._sessionService,
  );

  final AppDatabase _appDatabase;
  final DbTransactionRunner _transactionRunner;
  final SessionService _sessionService;

  ({List<String> where, List<Object?> args}) _buildInvoiceFilters({
    DateTime? fromDate,
    DateTime? toDate,
    int? accountId,
    int? categoryId,
    List<String>? statuses,
  }) {
    final where = <String>['s.status != ?'];
    final args = <Object?>['cancelled'];
    final currentUser = _sessionService.currentUser;

    if (currentUser != null && !_sessionService.canViewAllInvoices) {
      where.add('s.created_by_user_id = ?');
      args.add(currentUser.id);
    }

    if (fromDate != null) {
      where.add('datetime(s.created_at) >= datetime(?)');
      args.add(fromDate.toIso8601String());
    }
    if (toDate != null) {
      final endExclusive = DateTime(
        toDate.year,
        toDate.month,
        toDate.day,
      ).add(const Duration(days: 1));
      where.add('datetime(s.created_at) < datetime(?)');
      args.add(endExclusive.toIso8601String());
    }
    if (accountId != null) {
      where.add('s.account_id = ?');
      args.add(accountId);
    }
    if (categoryId != null) {
      where.add(
        'EXISTS (SELECT 1 FROM sale_items si JOIN products p ON p.id = si.product_id WHERE si.sale_id = s.id AND p.category_id = ?)',
      );
      args.add(categoryId);
    }

    if (statuses != null && statuses.isNotEmpty) {
      final normalized = statuses
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty && e != 'cancelled')
          .toSet()
          .toList(growable: false);
      if (normalized.isNotEmpty) {
        final placeholders = List.filled(normalized.length, '?').join(',');
        where.add('s.status IN ($placeholders)');
        args.addAll(normalized);
      }
    }

    return (where: where, args: args);
  }

  Future<List<SalesInvoiceSummary>> listInvoices({
    DateTime? fromDate,
    DateTime? toDate,
    int? accountId,
    int? categoryId,
    List<String>? statuses,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await _appDatabase.database;
    final filters = _buildInvoiceFilters(
      fromDate: fromDate,
      toDate: toDate,
      accountId: accountId,
      categoryId: categoryId,
      statuses: statuses,
    );
    final where = filters.where;
    final args = <Object?>[...filters.args];

    args.add(limit);
    args.add(offset);

    final rows = await db.rawQuery('''
      SELECT
        s.id,
        s.invoice_number,
        COALESCE((
          SELECT GROUP_CONCAT(p.name, ', ')
          FROM sale_items si
          JOIN products p ON p.id = si.product_id
          WHERE si.sale_id = s.id
        ), '-') AS products_summary,
        COALESCE(a.name, 'Walk-in') AS account_name,
        s.status,
        s.total_amount,
        COALESCE((
          SELECT SUM(CASE WHEN pay.reversal_for_id IS NULL THEN pay.amount ELSE 0 END)
          FROM payments pay
          WHERE pay.invoice_type = 'sale' AND pay.invoice_id = s.id
        ), 0) AS paid_amount,
        s.created_at
      FROM sales s
      LEFT JOIN accounts a ON a.id = s.account_id
      WHERE ${where.join(' AND ')}
      ORDER BY datetime(s.created_at) DESC, s.id DESC
      LIMIT ? OFFSET ?
      ''', args);

    return rows
        .map(
          (row) => SalesInvoiceSummary(
            id: (row['id'] as num).toInt(),
            invoiceNumber: (row['invoice_number'] as String?) ?? '-',
            productsSummary: (row['products_summary'] as String?) ?? '-',
            accountName: (row['account_name'] as String?) ?? 'Walk-in',
            status: (row['status'] as String?) ?? 'completed',
            totalAmount: ((row['total_amount'] ?? 0) as num).toDouble(),
            paidAmount: ((row['paid_amount'] ?? 0) as num).toDouble(),
            outstandingAmount:
                ((((row['total_amount'] ?? 0) as num).toDouble() -
                            ((row['paid_amount'] ?? 0) as num).toDouble())
                        .clamp(0, double.infinity))
                    .toDouble(),
            createdAt: DateTime.parse(row['created_at'] as String),
          ),
        )
        .toList();
  }

  Future<InvoiceSuggestion?> lookupSaleInvoiceSuggestionForReturn(int saleId) async {
    final db = await _appDatabase.database;
    final filters = _buildInvoiceFilters(
      fromDate: null,
      toDate: null,
      accountId: null,
      categoryId: null,
      statuses: null,
    );
    final where = [...filters.where, 's.id = ?'];
    final args = [...filters.args, saleId];

    final rows = await db.rawQuery('''
      SELECT s.id, s.invoice_number, COALESCE(a.name, 'Walk-in') AS account_name
      FROM sales s
      LEFT JOIN accounts a ON a.id = s.account_id
      WHERE ${where.join(' AND ')}
      LIMIT 1
      ''', args);

    if (rows.isEmpty) return null;
    final row = rows.first;
    return InvoiceSuggestion(
      id: (row['id'] as num).toInt(),
      invoiceNumber: (row['invoice_number'] as String?) ?? '-',
      accountLabel: (row['account_name'] as String?) ?? 'Walk-in',
    );
  }

  Future<List<InvoiceSuggestion>> suggestSaleInvoicesForReturn(
    String prefixRaw, {
    int limit = 40,
  }) async {
    final prefix = prefixRaw.trim();
    if (prefix.isEmpty) return const [];

    final db = await _appDatabase.database;
    final filters = _buildInvoiceFilters(
      fromDate: null,
      toDate: null,
      accountId: null,
      categoryId: null,
      statuses: null,
    );
    final where = [...filters.where];
    final args = <Object?>[...filters.args];

    final pattern = '${escapeSqlLikeLiteral(prefix)}%';
    where.add(
      r"(s.invoice_number LIKE ? ESCAPE '\' OR CAST(s.id AS TEXT) LIKE ? ESCAPE '\')",
    );
    args.add(pattern);
    args.add(pattern);
    args.add(limit);

    final rows = await db.rawQuery(
      '''
      SELECT s.id, s.invoice_number, COALESCE(a.name, 'Walk-in') AS account_name
      FROM sales s
      LEFT JOIN accounts a ON a.id = s.account_id
      WHERE ${where.join(' AND ')}
      ORDER BY datetime(s.created_at) DESC, s.id DESC
      LIMIT ?
      ''',
      args,
    );

    return rows
        .map(
          (row) => InvoiceSuggestion(
            id: (row['id'] as num).toInt(),
            invoiceNumber: (row['invoice_number'] as String?) ?? '-',
            accountLabel: (row['account_name'] as String?) ?? 'Walk-in',
          ),
        )
        .toList();
  }

  Future<Map<String, int>> countInvoicesByStatus({
    DateTime? fromDate,
    DateTime? toDate,
    int? accountId,
    int? categoryId,
  }) async {
    final db = await _appDatabase.database;
    final filters = _buildInvoiceFilters(
      fromDate: fromDate,
      toDate: toDate,
      accountId: accountId,
      categoryId: categoryId,
    );

    final rows = await db.rawQuery('''
      SELECT s.status, COUNT(*) AS cnt
      FROM sales s
      WHERE ${filters.where.join(' AND ')}
      GROUP BY s.status
      ''', filters.args);

    final result = <String, int>{};
    for (final row in rows) {
      final key = ((row['status'] as String?) ?? '').trim().toLowerCase();
      if (key.isEmpty) {
        continue;
      }
      result[key] = ((row['cnt'] ?? 0) as num).toInt();
    }
    return result;
  }

  Future<List<SalesInvoiceLine>> listInvoiceLines(int saleId) async {
    final db = await _appDatabase.database;
    final rows = await db.rawQuery(
      '''
      SELECT
        si.id,
        p.name AS product_name,
        si.quantity,
        COALESCE(r.returned_qty, 0) AS returned_qty,
        CASE
          WHEN (si.quantity - COALESCE(r.returned_qty, 0)) > 0
            THEN (si.quantity - COALESCE(r.returned_qty, 0))
          ELSE 0
        END AS remaining_qty,
        si.unit_price,
        si.line_total
      FROM sale_items si
      JOIN products p ON p.id = si.product_id
      LEFT JOIN (
        SELECT original_line_id, COALESCE(SUM(quantity), 0) AS returned_qty
        FROM returns
        WHERE invoice_type = 'sale'
        GROUP BY original_line_id
      ) r ON r.original_line_id = si.id
      WHERE si.sale_id = ?
      ORDER BY si.id ASC
      ''',
      [saleId],
    );

    return rows
        .map(
          (row) => SalesInvoiceLine(
            id: (row['id'] as num).toInt(),
            productName: (row['product_name'] as String?) ?? 'Unknown',
            quantity: ((row['quantity'] ?? 0) as num).toDouble(),
            returnedQuantity: ((row['returned_qty'] ?? 0) as num).toDouble(),
            remainingQuantity: ((row['remaining_qty'] ?? 0) as num).toDouble(),
            unitPrice: ((row['unit_price'] ?? 0) as num).toDouble(),
            lineTotal: ((row['line_total'] ?? 0) as num).toDouble(),
          ),
        )
        .toList();
  }

  Future<String?> getSaleStatus(int saleId) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      'sales',
      columns: ['status'],
      where: 'id = ?',
      whereArgs: [saleId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['status'] as String?;
  }

  Future<PendingSaleDraft> loadPendingSaleDraft(int saleId) async {
    final db = await _appDatabase.database;

    final saleRows = await db.rawQuery(
      '''
      SELECT s.id, s.account_id, s.status, s.total_amount, a.name AS account_name
      FROM sales s
      LEFT JOIN accounts a ON a.id = s.account_id
      WHERE s.id = ?
      LIMIT 1
      ''',
      [saleId],
    );
    if (saleRows.isEmpty) {
      throw StateError('Sale not found.');
    }

    final sale = saleRows.first;
    final status = (sale['status'] as String?) ?? 'completed';
    if (status != SaleStatus.pending.dbValue) {
      throw StateError('Select a pending invoice first.');
    }

    final itemRows = await db.rawQuery(
      '''
      SELECT
        si.product_id,
        p.name AS product_name,
        p.unit_type,
        p.purchase_price,
        si.quantity,
        si.unit_price,
        si.discount_amount,
        si.line_total
      FROM sale_items si
      JOIN products p ON p.id = si.product_id
      WHERE si.sale_id = ?
      ORDER BY si.id ASC
      ''',
      [saleId],
    );
    if (itemRows.isEmpty) {
      throw StateError('Pending invoice has no items.');
    }

    final productIds = itemRows
        .map((row) => (row['product_id'] as num).toInt())
        .toSet()
        .toList(growable: false);
    final stockByProduct = await getCurrentStocksForProducts(productIds);

    final items = itemRows
        .map((row) {
          final productId = (row['product_id'] as num).toInt();
          return SaleDraftItem(
            productId: productId,
            productName: (row['product_name'] as String?) ?? 'Product',
            unitType: (row['unit_type'] as String?) ?? 'piece',
            availableStock: stockByProduct[productId] ?? 0,
            minUnitPrice: ((row['purchase_price'] ?? 0) as num).toDouble(),
            quantity: ((row['quantity'] ?? 0) as num).toDouble(),
            unitPrice: ((row['unit_price'] ?? 0) as num).toDouble(),
            discount: ((row['discount_amount'] ?? 0) as num).toDouble(),
          );
        })
        .toList(growable: false);

    final subtotal = roundCurrency(
      items.fold<double>(0, (sum, item) => sum + item.lineTotal),
    );
    final total = ((sale['total_amount'] ?? 0) as num).toDouble();
    final InvoiceHeaderDiscountKind headerKind;
    final double headerValue;
    if (total <= subtotal + 0.000001) {
      headerKind = InvoiceHeaderDiscountKind.fixed;
      headerValue = roundCurrency((subtotal - total).clamp(0, double.infinity));
    } else {
      headerKind = InvoiceHeaderDiscountKind.percent;
      headerValue = 0;
    }

    return PendingSaleDraft(
      saleId: (sale['id'] as num).toInt(),
      customerId: (sale['account_id'] as num?)?.toInt(),
      customerName: sale['account_name'] as String?,
      headerDiscountKind: headerKind,
      headerDiscountValue: headerValue,
      items: items,
    );
  }

  Future<bool> saleInvoiceHasReturns(int saleId) async {
    final db = await _appDatabase.database;
    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS c
      FROM returns
      WHERE invoice_type = ? AND invoice_id = ?
      ''',
      ['sale', saleId],
    );
    return (((rows.first['c'] ?? 0) as num).toInt() > 0);
  }

  Future<bool> canAmendSaleInvoice(int saleId) async {
    final db = await _appDatabase.database;
    final rows = await db.rawQuery(
      '''
      SELECT s.status FROM sales s WHERE s.id = ? LIMIT 1
      ''',
      [saleId],
    );
    if (rows.isEmpty) return false;
    final status =
        ((rows.first['status'] as String?) ?? '').trim().toLowerCase();
    if (status == SaleStatus.cancelled.dbValue ||
        status == SaleStatus.pending.dbValue) {
      return false;
    }
    if (status != SaleStatus.completed.dbValue &&
        status != SaleStatus.partial.dbValue) {
      return false;
    }
    return !(await saleInvoiceHasReturns(saleId));
  }

  Future<AmendmentPaymentSnapshot> _loadAmendmentPaymentSnapshot(
    DatabaseExecutor executor,
    int saleId,
  ) async {
    final rows = await executor.rawQuery(
      '''
      SELECT payment_method AS m,
             SUM(amount) AS net_amount
      FROM payments
      WHERE invoice_type = 'sale'
        AND invoice_id = ?
        AND reversal_for_id IS NULL
      GROUP BY payment_method
      ''',
      [saleId],
    );

    var cashNet = 0.0;
    var walletNet = 0.0;
    for (final row in rows) {
      final method = (row['m'] as String?) ?? '';
      final amt = ((row['net_amount'] ?? 0) as num).toDouble();
      if (method == 'cash') {
        cashNet += amt;
      } else if (method == 'vodafone_cash') {
        walletNet += amt;
      }
    }
    final cash = roundCurrency(cashNet.clamp(0, double.infinity));
    final wallet = roundCurrency(walletNet.clamp(0, double.infinity));

    final PaymentMethod method;
    if (cash > 0.000001 && wallet > 0.000001) {
      method = PaymentMethod.cashAndWallet;
      return AmendmentPaymentSnapshot(
        paidCash: cash,
        paidWallet: wallet,
        method: method,
      );
    }
    if (wallet > 0.000001) {
      method = PaymentMethod.vodafoneCash;
      return AmendmentPaymentSnapshot(
        paidCash: wallet,
        paidWallet: 0,
        method: method,
      );
    }

    method = PaymentMethod.cash;
    return AmendmentPaymentSnapshot(
      paidCash: cash,
      paidWallet: 0,
      method: method,
    );
  }

  void _rejectIfSaleNotEligibleForAmend({
    required String? status,
  }) {
    final normalized = (status ?? '').trim().toLowerCase();
    if (normalized == SaleStatus.cancelled.dbValue ||
        normalized == SaleStatus.pending.dbValue) {
      throw StateError('This invoice cannot be amended.');
    }
    if (normalized != SaleStatus.completed.dbValue &&
        normalized != SaleStatus.partial.dbValue) {
      throw StateError('This invoice cannot be amended.');
    }
  }

  Future<void> _assertNoReturns(DatabaseExecutor executor, int saleId) async {
    final rows = await executor.rawQuery(
      '''
      SELECT COUNT(*) AS c
      FROM returns
      WHERE invoice_type = ? AND invoice_id = ?
      ''',
      ['sale', saleId],
    );
    if ((((rows.first['c'] ?? 0) as num).toInt() > 0)) {
      throw StateError('Cannot amend a sale that has returns.');
    }
  }

  Future<PendingSaleDraft> loadSaleDraftForAmendment(int saleId) async {
    final db = await _appDatabase.database;

    final saleRows = await db.rawQuery(
      '''
      SELECT s.id, s.account_id, s.status, s.total_amount, a.name AS account_name
      FROM sales s
      LEFT JOIN accounts a ON a.id = s.account_id
      WHERE s.id = ?
      LIMIT 1
      ''',
      [saleId],
    );
    if (saleRows.isEmpty) {
      throw StateError('Sale not found.');
    }

    final sale = saleRows.first;
    _rejectIfSaleNotEligibleForAmend(status: sale['status'] as String?);
    await _assertNoReturns(db, saleId);

    final itemRows = await db.rawQuery(
      '''
      SELECT
        si.product_id,
        p.name AS product_name,
        p.unit_type,
        p.purchase_price,
        si.quantity,
        si.unit_price,
        si.discount_amount,
        si.line_total
      FROM sale_items si
      JOIN products p ON p.id = si.product_id
      WHERE si.sale_id = ?
      ORDER BY si.id ASC
      ''',
      [saleId],
    );
    if (itemRows.isEmpty) {
      throw StateError('Invoice has no items to amend.');
    }

    final qtyOnInvoiceByProduct = <int, double>{};
    for (final row in itemRows) {
      final productId = (row['product_id'] as num).toInt();
      final q = ((row['quantity'] ?? 0) as num).toDouble();
      qtyOnInvoiceByProduct[productId] =
          roundQuantity((qtyOnInvoiceByProduct[productId] ?? 0) + q);
    }

    final productIds = itemRows
        .map((row) => (row['product_id'] as num).toInt())
        .toSet()
        .toList(growable: false);
    final stockByProduct = await getCurrentStocksForProducts(productIds);

    final items = itemRows
        .map((row) {
          final productId = (row['product_id'] as num).toInt();
          final current = stockByProduct[productId] ?? 0;
          final invoicedQty = qtyOnInvoiceByProduct[productId] ?? 0;
          return SaleDraftItem(
            productId: productId,
            productName: (row['product_name'] as String?) ?? 'Product',
            unitType: (row['unit_type'] as String?) ?? 'piece',
            availableStock: roundQuantity(current + invoicedQty),
            minUnitPrice:
                ((row['purchase_price'] ?? 0) as num).toDouble(),
            quantity: ((row['quantity'] ?? 0) as num).toDouble(),
            unitPrice: ((row['unit_price'] ?? 0) as num).toDouble(),
            discount: ((row['discount_amount'] ?? 0) as num).toDouble(),
          );
        })
        .toList(growable: false);

    final subtotal = roundCurrency(
      items.fold<double>(0, (sum, item) => sum + item.lineTotal),
    );
    final total = ((sale['total_amount'] ?? 0) as num).toDouble();
    final InvoiceHeaderDiscountKind headerKind;
    final double headerValue;
    if (total <= subtotal + 0.000001) {
      headerKind = InvoiceHeaderDiscountKind.fixed;
      headerValue = roundCurrency((subtotal - total).clamp(0, double.infinity));
    } else {
      headerKind = InvoiceHeaderDiscountKind.percent;
      headerValue = 0;
    }

    final amendmentPayments = await _loadAmendmentPaymentSnapshot(db, saleId);

    return PendingSaleDraft(
      saleId: (sale['id'] as num).toInt(),
      customerId: (sale['account_id'] as num?)?.toInt(),
      customerName: sale['account_name'] as String?,
      headerDiscountKind: headerKind,
      headerDiscountValue: headerValue,
      items: items,
      amendmentPayments: amendmentPayments,
      amendmentStockCreditByProduct: Map<int, double>.from(
        qtyOnInvoiceByProduct,
      ),
    );
  }

  Future<void> amendSale(SaleAmendRequest request) async {
    if (request.items.isEmpty) {
      throw StateError('Sale must have at least one item.');
    }
    await _appDatabase.database;

    await _transactionRunner.run((txn) async {
      _sessionService.requireUserId();

      final saleRows = await txn.rawQuery(
        '''
        SELECT s.id, s.account_id, s.status, s.invoice_number, s.total_amount
        FROM sales s
        WHERE s.id = ?
        LIMIT 1
        ''',
        [request.saleId],
      );
      if (saleRows.isEmpty) {
        throw StateError('Sale not found.');
      }
      final sale = saleRows.first;
      final saleId = request.saleId;
      _rejectIfSaleNotEligibleForAmend(status: sale['status'] as String?);
      await _assertNoReturns(txn, saleId);

      await txn.delete(
        'stock_movements',
        where:
            'invoice_type = ? AND invoice_id = ? AND movement_type = ?',
        whereArgs: ['sale', saleId, 'out'],
      );

      await txn.delete(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );

      final requestedByProduct = <int, double>{};
      for (final item in request.items) {
        final quantity = roundQuantity(item.quantity);
        if (quantity <= 0) {
          throw StateError('Quantity must be greater than zero.');
        }
        requestedByProduct[item.productId] =
            (requestedByProduct[item.productId] ?? 0) + quantity;
      }

      final productIds = requestedByProduct.keys.toList();
      if (productIds.isNotEmpty) {
        final placeholders = List.filled(productIds.length, '?').join(',');
        final stockRows = await txn.rawQuery(
          '''
          SELECT
            p.id,
            p.name,
            MAX(
              0,
              COALESCE(SUM(
                CASE
                  WHEN sm.movement_type = 'in' THEN sm.quantity
                  WHEN sm.movement_type = 'out' THEN -sm.quantity
                  ELSE 0
                END
              ), 0)
            ) AS current_stock
          FROM products p
          LEFT JOIN stock_movements sm ON sm.product_id = p.id
          WHERE p.id IN ($placeholders)
          GROUP BY p.id, p.name
          ''',
          productIds,
        );

        final pricingRows = await txn.rawQuery(
          '''
          SELECT id, purchase_price
          FROM products
          WHERE id IN ($placeholders)
          ''',
          productIds,
        );

        final minPriceByProduct = <int, double>{
          for (final row in pricingRows)
            (row['id'] as num).toInt():
                ((row['purchase_price'] ?? 0) as num).toDouble(),
        };

        final stockByProduct = <int, ({String name, double stock})>{
          for (final row in stockRows)
            (row['id'] as num).toInt(): (
              name: (row['name'] as String?) ?? 'Product',
              stock: ((row['current_stock'] ?? 0) as num).toDouble(),
            ),
        };

        for (final entry in requestedByProduct.entries) {
          final pid = entry.key;
          final requestedQty = roundQuantity(entry.value);
          final stockInfo = stockByProduct[pid];
          if (stockInfo == null) {
            throw StateError('Product not found (id: $pid).');
          }
          if (requestedQty > stockInfo.stock + 0.000001) {
            throw StateError(
              'Insufficient stock for ${stockInfo.name}. Available: '
              '${stockInfo.stock.toStringAsFixed(0)}, requested: '
              '${requestedQty.toStringAsFixed(0)}.',
            );
          }
        }

        for (final item in request.items) {
          final minAllowed = minPriceByProduct[item.productId];
          if (minAllowed == null) {
            throw StateError('Product not found (id: ${item.productId}).');
          }
          if (item.unitPrice < minAllowed - 0.000001) {
            throw StateError(
              'Sale price cannot be less than purchase price.',
            );
          }
        }
      }

      final invoiceNo =
          (sale['invoice_number'] as String?) ?? 'S-$saleId';
      final accountId = (sale['account_id'] as num?)?.toInt();

      final subtotalAmount = roundCurrency(
        request.items.fold<double>(0, (sum, item) => sum + item.lineTotal),
      );
      final discountAmount = computeInvoiceHeaderDiscountAmount(
        subtotal: subtotalAmount,
        kind: request.headerDiscountKind,
        value: request.headerDiscountValue,
      );
      final totalAmount = roundCurrency(subtotalAmount - discountAmount);

      final paidRows = await txn.rawQuery(
        '''
        SELECT COALESCE(SUM(amount), 0) AS paid_amount
        FROM payments
        WHERE invoice_type = 'sale'
          AND invoice_id = ?
          AND reversal_for_id IS NULL
        ''',
        [saleId],
      );
      final netPaidAmount =
          ((paidRows.first['paid_amount'] ?? 0) as num).toDouble();

      final nextStatus = netPaidAmount + 0.000001 >= totalAmount
          ? SaleStatus.completed.dbValue
          : SaleStatus.partial.dbValue;

      for (final item in request.items) {
        final quantity = roundQuantity(item.quantity);
        if (item.unitType == 'piece' && !isIntegerLike(quantity)) {
          throw StateError('Piece products require integer quantity.');
        }

        final lineTotal = roundCurrency(item.lineTotal);
        await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': item.productId,
          'quantity': quantity,
          'unit_price': roundCurrency(item.unitPrice),
          'discount_amount': roundCurrency(item.discount),
          'line_total': lineTotal,
          'created_at': DateTime.now().toIso8601String(),
        });

        await txn.insert('stock_movements', {
          'product_id': item.productId,
          'invoice_type': 'sale',
          'invoice_id': saleId,
          'movement_type': 'out',
          'quantity': quantity,
          'unit_type': item.unitType,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      await txn.update(
        'sales',
        {
          'total_amount': totalAmount,
          'status': nextStatus,
        },
        where: 'id = ?',
        whereArgs: [saleId],
      );

      if (accountId != null) {
        final ledgerRows = await txn.query(
          'ledger_transactions',
          columns: ['id'],
          where:
              'account_id = ? AND source_type = ? AND source_id = ? AND entry_kind = ?',
          whereArgs: [accountId, 'sale', saleId, 'debit'],
        );
        if (ledgerRows.isEmpty) {
          throw StateError(
            'Sale ledger debit entry missing for customer account.',
          );
        }
        for (final row in ledgerRows) {
          await txn.update(
            'ledger_transactions',
            {
              'amount': totalAmount,
              'description': 'Sale invoice $invoiceNo',
            },
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }
    });
  }

  Future<Map<int, double>> getCurrentStocksForProducts(
    List<int> productIds,
  ) async {
    if (productIds.isEmpty) return const <int, double>{};

    final db = await _appDatabase.database;
    final placeholders = List.filled(productIds.length, '?').join(',');
    final rows = await db.rawQuery('''
      SELECT
        p.id,
        MAX(
          0,
          COALESCE(
            SUM(
              CASE
                WHEN sm.movement_type = 'in' THEN sm.quantity
                WHEN sm.movement_type = 'out' THEN -sm.quantity
                ELSE 0
              END
            ),
            0
          )
        ) AS current_stock
      FROM products p
      LEFT JOIN stock_movements sm ON sm.product_id = p.id
      WHERE p.id IN ($placeholders)
      GROUP BY p.id
      ''', productIds);

    final map = <int, double>{};
    for (final row in rows) {
      map[(row['id'] as num).toInt()] = ((row['current_stock'] ?? 0) as num)
          .toDouble();
    }
    return map;
  }

  Future<int> createSale(SaleCreateRequest request) async {
    if (!request.isPending && request.pendingSaleId != null) {
      await settlePendingSale(
        saleId: request.pendingSaleId!,
        paidAmount: request.paidAmount,
        paidWalletAmount: request.paidWalletAmount,
        paymentMethod: request.paymentMethod,
      );
      return request.pendingSaleId!;
    }

    await _appDatabase.database;

    return _transactionRunner.run((txn) async {
      final actorUserId = _sessionService.requireUserId();

      if (request.items.isEmpty) {
        throw StateError('Sale must have at least one item.');
      }

      final requestedByProduct = <int, double>{};
      for (final item in request.items) {
        final quantity = roundQuantity(item.quantity);
        if (quantity <= 0) {
          throw StateError('Quantity must be greater than zero.');
        }
        requestedByProduct[item.productId] =
            (requestedByProduct[item.productId] ?? 0) + quantity;
      }

      final productIds = requestedByProduct.keys.toList();
      if (productIds.isNotEmpty) {
        final placeholders = List.filled(productIds.length, '?').join(',');
        final stockRows = await txn.rawQuery('''
          SELECT
            p.id,
            p.name,
            MAX(
              0,
              COALESCE(SUM(
                CASE
                  WHEN sm.movement_type = 'in' THEN sm.quantity
                  WHEN sm.movement_type = 'out' THEN -sm.quantity
                  ELSE 0
                END
              ), 0)
            ) AS current_stock
          FROM products p
          LEFT JOIN stock_movements sm ON sm.product_id = p.id
          WHERE p.id IN ($placeholders)
          GROUP BY p.id, p.name
          ''', productIds);

        final pricingRows = await txn.rawQuery('''
          SELECT id, purchase_price
          FROM products
          WHERE id IN ($placeholders)
          ''', productIds);

        final minPriceByProduct = <int, double>{
          for (final row in pricingRows)
            (row['id'] as num).toInt(): ((row['purchase_price'] ?? 0) as num)
                .toDouble(),
        };

        final stockByProduct = <int, ({String name, double stock})>{
          for (final row in stockRows)
            (row['id'] as num).toInt(): (
              name: (row['name'] as String?) ?? 'Product',
              stock: ((row['current_stock'] ?? 0) as num).toDouble(),
            ),
        };

        for (final entry in requestedByProduct.entries) {
          final pid = entry.key;
          final requestedQty = roundQuantity(entry.value);
          final stockInfo = stockByProduct[pid];
          if (stockInfo == null) {
            throw StateError('Product not found (id: $pid).');
          }
          if (requestedQty > stockInfo.stock + 0.000001) {
            throw StateError(
              'Insufficient stock for ${stockInfo.name}. Available: ${stockInfo.stock.toStringAsFixed(0)}, requested: ${requestedQty.toStringAsFixed(0)}.',
            );
          }
        }

        for (final item in request.items) {
          final minAllowed = minPriceByProduct[item.productId];
          if (minAllowed == null) {
            throw StateError('Product not found (id: ${item.productId}).');
          }
          if (item.unitPrice < minAllowed - 0.000001) {
            throw StateError('Sale price cannot be less than purchase price.');
          }
        }
      }

      int? accountId = request.customerId;
      final newName = request.newCustomerName?.trim() ?? '';
      if (accountId == null && newName.isNotEmpty) {
        accountId = await txn.insert('accounts', {
          'name': newName,
          'account_type': 'customer',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      final subtotalAmount = roundCurrency(
        request.items.fold<double>(0, (sum, item) => sum + item.lineTotal),
      );
      final discountAmount = computeInvoiceHeaderDiscountAmount(
        subtotal: subtotalAmount,
        kind: request.headerDiscountKind,
        value: request.headerDiscountValue,
      );
      final totalAmount = roundCurrency(subtotalAmount - discountAmount);
      final paymentParts = _salePaymentCashWalletParts(
        method: request.paymentMethod,
        totalAmount: totalAmount,
        paidCash: request.paidAmount,
        paidWallet: request.paidWalletAmount,
      );
      final paidTotalSum = paymentParts.totalPaid;
      final status = request.isPending
          ? SaleStatus.pending.dbValue
          : (paidTotalSum + 0.000001 >= totalAmount
                ? SaleStatus.completed.dbValue
                : SaleStatus.partial.dbValue);
      final invoiceNo = await allocateSaleInvoiceNumber(txn);

      final saleId = await txn.insert('sales', {
        'account_id': accountId,
        'invoice_number': invoiceNo,
        'status': status,
        'total_amount': totalAmount,
        'notes': request.notes,
        'created_by_user_id': actorUserId,
        'created_at': DateTime.now().toIso8601String(),
      });

      for (final item in request.items) {
        final quantity = roundQuantity(item.quantity);
        if (item.unitType == 'piece' && !isIntegerLike(quantity)) {
          throw StateError('Piece products require integer quantity.');
        }

        final lineTotal = roundCurrency(item.lineTotal);
        await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': item.productId,
          'quantity': quantity,
          'unit_price': roundCurrency(item.unitPrice),
          'discount_amount': roundCurrency(item.discount),
          'line_total': lineTotal,
          'created_at': DateTime.now().toIso8601String(),
        });

        if (!request.isPending) {
          await txn.insert('stock_movements', {
            'product_id': item.productId,
            'invoice_type': 'sale',
            'invoice_id': saleId,
            'movement_type': 'out',
            'quantity': quantity,
            'unit_type': item.unitType,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

      if (!request.isPending && accountId != null) {
        await txn.insert('ledger_transactions', {
          'account_id': accountId,
          'source_type': 'sale',
          'source_id': saleId,
          'amount': totalAmount,
          'entry_kind': 'debit',
          'description': 'Sale invoice $invoiceNo',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      if (!request.isPending && paidTotalSum > 0.000001) {
        Future<void> insertPart(double amt, String methodDb) async {
          if (amt <= 0.000001) return;
          final rounded = roundCurrency(amt);
          final paymentId = await txn.insert('payments', {
            'account_id': accountId,
            'invoice_type': 'sale',
            'invoice_id': saleId,
            'payment_method': methodDb,
            'amount': rounded,
            'is_refund': 0,
            'is_standalone': 0,
            'notes': 'Payment for $invoiceNo',
            'created_by_user_id': actorUserId,
            'created_at': DateTime.now().toIso8601String(),
          });

          if (accountId != null) {
            await txn.insert('ledger_transactions', {
              'account_id': accountId,
              'source_type': 'payment',
              'source_id': paymentId,
              'amount': rounded,
              'entry_kind': 'credit',
              'description': 'Payment for sale $invoiceNo',
              'created_at': DateTime.now().toIso8601String(),
            });
          }
        }

        await insertPart(paymentParts.cashAmount, 'cash');
        await insertPart(paymentParts.walletAmount, 'vodafone_cash');
      }

      return saleId;
    });
  }

  Future<void> settlePendingSale({
    required int saleId,
    required double paidAmount,
    double paidWalletAmount = 0,
    required PaymentMethod paymentMethod,
  }) async {
    await _appDatabase.database;

    await _transactionRunner.run((txn) async {
      final actorUserId = _sessionService.requireUserId();

      final saleRows = await txn.query(
        'sales',
        columns: [
          'id',
          'account_id',
          'invoice_number',
          'status',
          'total_amount',
        ],
        where: 'id = ?',
        whereArgs: [saleId],
        limit: 1,
      );
      if (saleRows.isEmpty) {
        throw StateError('Sale not found.');
      }

      final sale = saleRows.first;
      final status = saleStatusFromDb(
        (sale['status'] as String?) ?? 'completed',
      );
      if (status != SaleStatus.pending) {
        throw StateError('Only pending invoices can be completed.');
      }

      final itemRows = await txn.rawQuery(
        '''
        SELECT si.product_id, si.quantity, p.name AS product_name, p.unit_type
        FROM sale_items si
        JOIN products p ON p.id = si.product_id
        WHERE si.sale_id = ?
        ''',
        [saleId],
      );
      if (itemRows.isEmpty) {
        throw StateError('Pending invoice has no items.');
      }

      final requestedByProduct = <int, double>{};
      for (final row in itemRows) {
        final productId = (row['product_id'] as num).toInt();
        final quantity = ((row['quantity'] ?? 0) as num).toDouble();
        requestedByProduct[productId] =
            (requestedByProduct[productId] ?? 0) + quantity;
      }

      final productIds = requestedByProduct.keys.toList(growable: false);
      if (productIds.isNotEmpty) {
        final placeholders = List.filled(productIds.length, '?').join(',');
        final stockRows = await txn.rawQuery('''
          SELECT
            p.id,
            p.name,
            MAX(
              0,
              COALESCE(SUM(
                CASE
                  WHEN sm.movement_type = 'in' THEN sm.quantity
                  WHEN sm.movement_type = 'out' THEN -sm.quantity
                  ELSE 0
                END
              ), 0)
            ) AS current_stock
          FROM products p
          LEFT JOIN stock_movements sm ON sm.product_id = p.id
          WHERE p.id IN ($placeholders)
          GROUP BY p.id, p.name
          ''', productIds);

        final stockByProduct = <int, ({String name, double stock})>{
          for (final row in stockRows)
            (row['id'] as num).toInt(): (
              name: (row['name'] as String?) ?? 'Product',
              stock: ((row['current_stock'] ?? 0) as num).toDouble(),
            ),
        };

        for (final entry in requestedByProduct.entries) {
          final info = stockByProduct[entry.key];
          if (info == null) {
            throw StateError('Product not found (id: ${entry.key}).');
          }
          final requestedQty = roundQuantity(entry.value);
          if (requestedQty > info.stock + 0.000001) {
            throw StateError(
              'Insufficient stock for ${info.name}. Available: ${info.stock.toStringAsFixed(0)}, requested: ${requestedQty.toStringAsFixed(0)}.',
            );
          }
        }
      }

      for (final row in itemRows) {
        await txn.insert('stock_movements', {
          'product_id': row['product_id'],
          'invoice_type': 'sale',
          'invoice_id': saleId,
          'movement_type': 'out',
          'quantity': row['quantity'],
          'unit_type': row['unit_type'],
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      final totalAmount = ((sale['total_amount'] ?? 0) as num).toDouble();
      final parts = _salePaymentCashWalletParts(
        method: paymentMethod,
        totalAmount: totalAmount,
        paidCash: paidAmount,
        paidWallet: paidWalletAmount,
      );
      final paidTotalSum = parts.totalPaid;
      final invoiceNo = (sale['invoice_number'] as String?) ?? 'S-$saleId';
      final accountId = sale['account_id'] as int?;

      if (accountId != null) {
        await txn.insert('ledger_transactions', {
          'account_id': accountId,
          'source_type': 'sale',
          'source_id': saleId,
          'amount': totalAmount,
          'entry_kind': 'debit',
          'description': 'Sale invoice $invoiceNo',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      if (paidTotalSum > 0.000001) {
        Future<void> insertPart(double amt, String methodDb) async {
          if (amt <= 0.000001) return;
          final rounded = roundCurrency(amt);
          final paymentId = await txn.insert('payments', {
            'account_id': accountId,
            'invoice_type': 'sale',
            'invoice_id': saleId,
            'payment_method': methodDb,
            'amount': rounded,
            'is_refund': 0,
            'is_standalone': 0,
            'notes': 'Payment for $invoiceNo',
            'created_by_user_id': actorUserId,
            'created_at': DateTime.now().toIso8601String(),
          });

          if (accountId != null) {
            await txn.insert('ledger_transactions', {
              'account_id': accountId,
              'source_type': 'payment',
              'source_id': paymentId,
              'amount': rounded,
              'entry_kind': 'credit',
              'description': 'Payment for sale $invoiceNo',
              'created_at': DateTime.now().toIso8601String(),
            });
          }
        }

        await insertPart(parts.cashAmount, 'cash');
        await insertPart(parts.walletAmount, 'vodafone_cash');
      }

      final nextStatus = paidTotalSum + 0.000001 >= totalAmount
          ? SaleStatus.completed.dbValue
          : SaleStatus.partial.dbValue;

      await txn.update(
        'sales',
        {'status': nextStatus},
        where: 'id = ?',
        whereArgs: [saleId],
      );
    });
  }

  Future<void> returnSaleItem({
    required int saleId,
    required int saleItemId,
    required double quantity,
    required PaymentMethod paymentMethod,
    String? reason,
  }) async {
    await _appDatabase.database;

    await _transactionRunner.run((txn) async {
      final actorUserId = _sessionService.requireUserId();

      final saleRows = await txn.query(
        'sales',
        columns: [
          'id',
          'account_id',
          'invoice_number',
          'status',
          'total_amount',
        ],
        where: 'id = ?',
        whereArgs: [saleId],
        limit: 1,
      );
      if (saleRows.isEmpty) {
        throw StateError('Sale not found.');
      }
      if (saleRows.first['status'] == 'cancelled') {
        throw StateError('Cancelled sale cannot be returned.');
      }

      final itemRows = await txn.rawQuery(
        '''
        SELECT si.id, si.product_id, si.quantity, si.unit_price, si.discount_amount,
               p.unit_type
        FROM sale_items si
        JOIN products p ON p.id = si.product_id
        WHERE si.id = ? AND si.sale_id = ?
        LIMIT 1
        ''',
        [saleItemId, saleId],
      );
      if (itemRows.isEmpty) {
        throw StateError('Sale item not found.');
      }
      final row = itemRows.first;
      final soldQty = (row['quantity'] as num).toDouble();
      final requestedQty = roundQuantity(quantity);

      final returnedRows = await txn.rawQuery(
        '''
        SELECT COALESCE(SUM(quantity), 0) AS returned_qty
        FROM returns
        WHERE invoice_type = 'sale' AND invoice_id = ? AND original_line_id = ?
        ''',
        [saleId, saleItemId],
      );
      final alreadyReturned = ((returnedRows.first['returned_qty'] ?? 0) as num)
          .toDouble();
      final validation = ReturnRules.validate(
        originalQuantity: soldQty,
        alreadyReturned: alreadyReturned,
        requestedQuantity: requestedQty,
        unitType: row['unit_type'] as String,
      );
      if (!validation.isValid) {
        throw StateError(validation.error!);
      }

      final returnId = await txn.insert('returns', {
        'invoice_type': 'sale',
        'invoice_id': saleId,
        'original_line_id': saleItemId,
        'quantity': requestedQty,
        'reason': reason,
        'created_by_user_id': actorUserId,
        'created_at': DateTime.now().toIso8601String(),
      });

      await txn.insert('stock_movements', {
        'product_id': row['product_id'] as int,
        'invoice_type': 'return',
        'invoice_id': returnId,
        'movement_type': 'in',
        'quantity': requestedQty,
        'unit_type': row['unit_type'] as String,
        'created_at': DateTime.now().toIso8601String(),
      });

      final unitPrice = (row['unit_price'] as num).toDouble();
      final lineDiscount = (row['discount_amount'] as num).toDouble();
      final unitDiscount = soldQty == 0 ? 0 : (lineDiscount / soldQty);
      final returnAmount = roundCurrency(
        requestedQty * (unitPrice - unitDiscount),
      );

      final oldTotalAmount = ((saleRows.first['total_amount'] ?? 0) as num)
          .toDouble();
      final newTotalAmount = roundCurrency(
        (oldTotalAmount - returnAmount).clamp(0, double.infinity).toDouble(),
      );
      final paidRows = await txn.rawQuery(
        '''
        SELECT COALESCE(SUM(amount), 0) AS paid_amount
        FROM payments
        WHERE invoice_type = 'sale'
          AND invoice_id = ?
          AND reversal_for_id IS NULL
        ''',
        [saleId],
      );
      final netPaidAmount = ((paidRows.first['paid_amount'] ?? 0) as num)
          .toDouble();
      final nextStatus = netPaidAmount + 0.000001 >= newTotalAmount
          ? 'completed'
          : 'partial';

      await txn.update(
        'sales',
        {'total_amount': newTotalAmount, 'status': nextStatus},
        where: 'id = ?',
        whereArgs: [saleId],
      );

      final accountId = saleRows.first['account_id'] as int?;
      if (accountId == null) {
        return;
      }

      await txn.insert('ledger_transactions', {
        'account_id': accountId,
        'source_type': 'return',
        'source_id': returnId,
        'amount': returnAmount,
        'entry_kind': 'credit',
        'description': 'Sale return #$returnId',
        'created_at': DateTime.now().toIso8601String(),
      });

      final overpaidAfterReturn = (netPaidAmount - newTotalAmount).clamp(
        0,
        double.infinity,
      );
      final refundable = roundCurrency(
        overpaidAfterReturn.clamp(0, returnAmount).toDouble(),
      );
      if (refundable > 0) {
        final paymentId = await txn.insert('payments', {
          'account_id': accountId,
          'invoice_type': 'sale',
          'invoice_id': saleId,
          'payment_method': _toDbMethod(paymentMethod),
          'amount': -refundable,
          'is_refund': 1,
          'is_standalone': 0,
          'notes': 'Refund for sale return #$returnId',
          'created_by_user_id': actorUserId,
          'created_at': DateTime.now().toIso8601String(),
        });

        await txn.insert('ledger_transactions', {
          'account_id': accountId,
          'source_type': 'payment',
          'source_id': paymentId,
          'amount': refundable,
          'entry_kind': 'debit',
          'description': 'Refund payment for return #$returnId',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  Future<void> cancelSale(int saleId) async {
    await _appDatabase.database;

    await _transactionRunner.run((txn) async {
      final actorUserId = _sessionService.requireUserId();

      final saleRows = await txn.query(
        'sales',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [saleId],
        limit: 1,
      );
      if (saleRows.isEmpty) {
        throw StateError('Sale not found.');
      }
      if (saleRows.first['status'] == 'cancelled') {
        return;
      }

      final returnRows = await txn.rawQuery(
        '''
        SELECT COUNT(*) AS count_returns
        FROM returns
        WHERE invoice_type = 'sale' AND invoice_id = ?
        ''',
        [saleId],
      );
      final hasReturns = ((returnRows.first['count_returns'] ?? 0) as num) > 0;
      if (hasReturns) {
        throw StateError(
          'Cannot cancel sale with returns. Reverse all returns first.',
        );
      }

      final stockRows = await txn.query(
        'stock_movements',
        where:
            'invoice_type = ? AND invoice_id = ? AND reversal_for_id IS NULL',
        whereArgs: ['sale', saleId],
      );
      for (final movement in stockRows) {
        final originalType = movement['movement_type'] as String;
        final opposite = originalType == 'out' ? 'in' : 'out';
        await txn.insert('stock_movements', {
          'product_id': movement['product_id'],
          'invoice_type': 'cancellation',
          'invoice_id': saleId,
          'movement_type': opposite,
          'quantity': movement['quantity'],
          'unit_type': movement['unit_type'],
          'reversal_for_id': movement['id'],
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      final ledgerRows = await txn.query(
        'ledger_transactions',
        where:
            '(source_type = ? AND source_id = ?) OR '
            '(source_type = ? AND source_id IN (SELECT id FROM payments WHERE invoice_type = ? AND invoice_id = ?))',
        whereArgs: ['sale', saleId, 'payment', 'sale', saleId],
      );
      for (final entry in ledgerRows) {
        final kind = entry['entry_kind'] as String;
        final oppositeKind = kind == 'debit' ? 'credit' : 'debit';
        await txn.insert('ledger_transactions', {
          'account_id': entry['account_id'],
          'source_type': 'cancellation',
          'source_id': saleId,
          'amount': entry['amount'],
          'entry_kind': oppositeKind,
          'description': 'Reversal for sale #$saleId',
          'reversal_for_id': entry['id'],
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      final payments = await txn.query(
        'payments',
        where:
            'invoice_type = ? AND invoice_id = ? AND reversal_for_id IS NULL',
        whereArgs: ['sale', saleId],
      );
      for (final payment in payments) {
        await txn.insert('payments', {
          'account_id': payment['account_id'],
          'invoice_type': 'sale',
          'invoice_id': saleId,
          'payment_method': payment['payment_method'],
          'amount': -((payment['amount'] as num).toDouble()),
          'is_refund': payment['is_refund'],
          'is_standalone': payment['is_standalone'],
          'reversal_for_id': payment['id'],
          'notes': 'Reversal for sale #$saleId',
          'created_by_user_id': actorUserId,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      await txn.update(
        'sales',
        {'status': 'cancelled'},
        where: 'id = ?',
        whereArgs: [saleId],
      );
    });
  }

  String _toDbMethod(PaymentMethod method) {
    return switch (method) {
      PaymentMethod.cash => 'cash',
      PaymentMethod.vodafoneCash => 'vodafone_cash',
      PaymentMethod.cashAndWallet => throw StateError(
        'Refunds/settlement must target a single channel.',
      ),
    };
  }

  ({double cashAmount, double walletAmount, double totalPaid})
  _salePaymentCashWalletParts({
    required PaymentMethod method,
    required double totalAmount,
    required double paidCash,
    required double paidWallet,
  }) {
    switch (method) {
      case PaymentMethod.cash:
        final c = roundCurrency(paidCash.clamp(0, totalAmount));
        return (cashAmount: c, walletAmount: 0.0, totalPaid: c);
      case PaymentMethod.vodafoneCash:
        final w = roundCurrency(paidCash.clamp(0, totalAmount));
        return (cashAmount: 0.0, walletAmount: w, totalPaid: w);
      case PaymentMethod.cashAndWallet:
        var c = roundCurrency(paidCash.clamp(0, totalAmount));
        final maxWallet = roundCurrency(
          (totalAmount - c).clamp(0, double.infinity),
        );
        final w = roundCurrency(paidWallet.clamp(0, maxWallet));
        return (
          cashAmount: c,
          walletAmount: w,
          totalPaid: roundCurrency(c + w),
        );
    }
  }
}
