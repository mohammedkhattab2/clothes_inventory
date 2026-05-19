import 'package:delta_erp/core/utils/invoice_number_display.dart';
import 'package:delta_erp/core/utils/number_utils.dart';
import 'package:delta_erp/core/utils/return_rules.dart';
import 'package:delta_erp/core/utils/sql_like_escape.dart';
import 'package:delta_erp/features/invoices/domain/invoice_suggestion.dart';
import 'package:delta_erp/features/sales/domain/sale_models.dart';
import 'package:delta_erp/services/auth/session_service.dart';
import 'package:delta_erp/services/database/app_database.dart';
import 'package:sqflite/sqlite_api.dart';
import 'package:delta_erp/services/database/db_transaction_runner.dart';
import 'package:delta_erp/services/database/invoice_sequence_allocator.dart';

String _invoiceActorLabel(String? fullName, String? username) {
  final n = (fullName ?? '').trim();
  if (n.isNotEmpty) return n;
  final u = (username ?? '').trim();
  if (u.isNotEmpty) return u;
  return '-';
}

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
    required this.createdByDisplay,
    this.lastModifiedByDisplay,
    this.paymentMethod,
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
  /// Full name, else username, else "—" when unknown.
  final String createdByDisplay;
  /// Set when the invoice was changed after issue (returns, amendment, settlement, cancel).
  final String? lastModifiedByDisplay;
  /// Distinct payment methods from SQL `GROUP_CONCAT`, or one method. Display via `invoicePaymentMethodsDisplayLabel`.
  final String? paymentMethod;
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
    this.isAddedAfterAmendment = false,
  });

  final int id;
  final String productName;
  final double quantity;
  final double returnedQuantity;
  final double remainingQuantity;
  final double unitPrice;
  final double lineTotal;
  final bool isAddedAfterAmendment;
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
    this.customerPhone,
    required this.headerDiscountKind,
    required this.headerDiscountValue,
    required this.items,
    this.amendmentPayments,
    this.amendmentStockCreditByProduct = const <int, double>{},
  });

  final int saleId;
  final int? customerId;
  final String? customerName;
  final String? customerPhone;
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
        s.last_modified_by_user_id AS last_mod_uid,
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
        ) AS last_payment_method,
        s.created_at,
        uc.full_name AS creator_full_name,
        uc.username AS creator_username,
        um.full_name AS modifier_full_name,
        um.username AS modifier_username
      FROM sales s
      LEFT JOIN accounts a ON a.id = s.account_id
      LEFT JOIN users uc ON uc.id = s.created_by_user_id
      LEFT JOIN users um ON um.id = s.last_modified_by_user_id
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
            createdByDisplay: _invoiceActorLabel(
              row['creator_full_name'] as String?,
              row['creator_username'] as String?,
            ),
            lastModifiedByDisplay: row['last_mod_uid'] == null
                ? null
                : _invoiceActorLabel(
                    row['modifier_full_name'] as String?,
                    row['modifier_username'] as String?,
                  ),
            paymentMethod: () {
              final raw = row['last_payment_method'] as String?;
              if (raw == null || raw.trim().isEmpty) {
                return null;
              }
              return raw.trim();
            }(),
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
    final id = (row['id'] as num).toInt();
    final rawNo = (row['invoice_number'] as String?) ?? '-';
    return InvoiceSuggestion(
      id: id,
      invoiceNumber: displaySaleInvoiceNumber(id: id, rawInvoiceNumber: rawNo),
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
          (row) {
            final id = (row['id'] as num).toInt();
            final rawNo = (row['invoice_number'] as String?) ?? '-';
            return InvoiceSuggestion(
              id: id,
              invoiceNumber:
                  displaySaleInvoiceNumber(id: id, rawInvoiceNumber: rawNo),
              accountLabel: (row['account_name'] as String?) ?? 'Walk-in',
            );
          },
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
        si.line_total,
        si.added_after_amendment
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
            isAddedAfterAmendment:
                ((row['added_after_amendment'] ?? 0) as num).toInt() == 1,
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
      SELECT s.id, s.account_id, s.status, s.total_amount, a.name AS account_name,
             a.phone AS account_phone
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

    final accountPhoneRaw = sale['account_phone'] as String?;
    final accountPhone = (accountPhoneRaw != null &&
            accountPhoneRaw.trim().isNotEmpty)
        ? accountPhoneRaw.trim()
        : null;

    return PendingSaleDraft(
      saleId: (sale['id'] as num).toInt(),
      customerId: (sale['account_id'] as num?)?.toInt(),
      customerName: sale['account_name'] as String?,
      customerPhone: accountPhone,
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
    return true;
  }

  Future<AmendmentPaymentSnapshot> loadSalePaymentSnapshot(int saleId) async {
    final db = await _appDatabase.database;
    return _loadAmendmentPaymentSnapshot(db, saleId);
  }

  /// Maximum refund that could be issued for returning [quantity] of [saleItemId].
  Future<double> previewMaxRefundForReturnLine({
    required int saleId,
    required int saleItemId,
    required double quantity,
  }) async {
    final db = await _appDatabase.database;
    final saleRows = await db.query(
      'sales',
      columns: ['total_amount'],
      where: 'id = ?',
      whereArgs: [saleId],
      limit: 1,
    );
    if (saleRows.isEmpty) return 0;

    final itemRows = await db.rawQuery(
      '''
      SELECT si.quantity, si.unit_price, si.discount_amount
      FROM sale_items si
      WHERE si.id = ? AND si.sale_id = ?
      LIMIT 1
      ''',
      [saleItemId, saleId],
    );
    if (itemRows.isEmpty) return 0;

    final row = itemRows.first;
    final soldQty = (row['quantity'] as num).toDouble();
    final unitPrice = (row['unit_price'] as num).toDouble();
    final lineDiscount = (row['discount_amount'] as num).toDouble();
    final unitDiscount = soldQty == 0 ? 0 : (lineDiscount / soldQty);
    final lineGross = roundCurrency(
      roundQuantity(quantity) * (unitPrice - unitDiscount),
    );

    final subtotalRows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(line_total), 0) AS subtotal
      FROM sale_items
      WHERE sale_id = ?
      ''',
      [saleId],
    );
    final subtotal = ((subtotalRows.first['subtotal'] ?? 0) as num).toDouble();
    final oldTotalAmount = ((saleRows.first['total_amount'] ?? 0) as num)
        .toDouble();
    final returnAmount = subtotal > 0.000001
        ? roundCurrency(oldTotalAmount * lineGross / subtotal)
        : lineGross;
    final newTotalAmount = roundCurrency(
      (oldTotalAmount - returnAmount).clamp(0, double.infinity).toDouble(),
    );

    final paidRows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(pp.amount), 0) AS paid_amount
      FROM payments pp
      WHERE pp.invoice_type = 'sale'
        AND pp.invoice_id = ?
        AND pp.reversal_for_id IS NULL
      ''',
      [saleId],
    );
    final netPaidAmount = ((paidRows.first['paid_amount'] ?? 0) as num)
        .toDouble();
    final overpaidAfterReturn = (netPaidAmount - newTotalAmount).clamp(
      0,
      double.infinity,
    );
    return roundCurrency(overpaidAfterReturn.clamp(0, returnAmount).toDouble());
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
    var visaNet = 0.0;
    for (final row in rows) {
      final method = (row['m'] as String?) ?? '';
      final amt = ((row['net_amount'] ?? 0) as num).toDouble();
      if (method == 'cash') {
        cashNet += amt;
      } else if (method == 'vodafone_cash') {
        walletNet += amt;
      } else if (method == 'visa') {
        visaNet += amt;
      }
    }
    final cash = roundCurrency(cashNet.clamp(0, double.infinity));
    final wallet = roundCurrency(walletNet.clamp(0, double.infinity));
    final visa = roundCurrency(visaNet.clamp(0, double.infinity));

    final PaymentMethod method;
    if (cash > 0.000001 && wallet > 0.000001 && visa < 0.000001) {
      method = PaymentMethod.cashAndWallet;
      return AmendmentPaymentSnapshot(
        paidCash: cash,
        paidWallet: wallet,
        method: method,
      );
    }
    if (visa > 0.000001 &&
        cash < 0.000001 &&
        wallet < 0.000001) {
      method = PaymentMethod.visa;
      return AmendmentPaymentSnapshot(
        paidCash: visa,
        paidWallet: 0,
        method: method,
      );
    }
    if (wallet > 0.000001 && cash < 0.000001 && visa < 0.000001) {
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

  Future<PendingSaleDraft> loadSaleDraftForAmendment(int saleId) async {
    final db = await _appDatabase.database;

    final saleRows = await db.rawQuery(
      '''
      SELECT s.id, s.account_id, s.status, s.total_amount, a.name AS account_name,
             a.phone AS account_phone
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

    final itemRows = await db.rawQuery(
      '''
      SELECT
        si.id AS sale_item_id,
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
            amendSourceSaleItemId: (row['sale_item_id'] as num).toInt(),
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

    final accountPhoneRawAmend = sale['account_phone'] as String?;
    final accountPhoneAmend =
        (accountPhoneRawAmend != null && accountPhoneRawAmend.trim().isNotEmpty)
        ? accountPhoneRawAmend.trim()
        : null;

    return PendingSaleDraft(
      saleId: (sale['id'] as num).toInt(),
      customerId: (sale['account_id'] as num?)?.toInt(),
      customerName: sale['account_name'] as String?,
      customerPhone: accountPhoneAmend,
      headerDiscountKind: headerKind,
      headerDiscountValue: headerValue,
      items: items,
      amendmentPayments: amendmentPayments,
      amendmentStockCreditByProduct: Map<int, double>.from(
        qtyOnInvoiceByProduct,
      ),
    );
  }

  Future<AmendRefundPreview> previewAmendRefund(SaleAmendRequest request) async {
    final db = await _appDatabase.database;
    final saleRows = await db.rawQuery(
      '''
      SELECT s.total_amount
      FROM sales s
      WHERE s.id = ?
      LIMIT 1
      ''',
      [request.saleId],
    );
    if (saleRows.isEmpty) {
      throw StateError('Sale not found.');
    }
    final oldTotalAmount = ((saleRows.first['total_amount'] ?? 0) as num)
        .toDouble();

    final originalItemRows = await db.rawQuery(
      '''
      SELECT
        si.id,
        si.product_id,
        si.quantity,
        si.unit_price,
        si.discount_amount,
        p.unit_type
      FROM sale_items si
      JOIN products p ON p.id = si.product_id
      WHERE si.sale_id = ?
      ORDER BY si.id ASC
      ''',
      [request.saleId],
    );

    final subtotalRows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(line_total), 0) AS subtotal
      FROM sale_items
      WHERE sale_id = ?
      ''',
      [request.saleId],
    );
    final oldSubtotal =
        ((subtotalRows.first['subtotal'] ?? 0) as num).toDouble();

    final cartQtyBySourceId = <int, double>{};
    for (final item in request.items) {
      final sourceId = item.amendSourceSaleItemId;
      if (sourceId == null) continue;
      cartQtyBySourceId[sourceId] = roundQuantity(
        (cartQtyBySourceId[sourceId] ?? 0) + item.quantity,
      );
    }

    var returnAmountTotal = 0.0;
    for (final row in originalItemRows) {
      final sourceId = (row['id'] as num).toInt();
      final originalQty = ((row['quantity'] ?? 0) as num).toDouble();
      final cartQty = cartQtyBySourceId[sourceId] ?? 0;
      if (cartQty >= originalQty - 0.000001) continue;

      final returnedQty = roundQuantity(originalQty - cartQty);
      final unitPrice = (row['unit_price'] as num).toDouble();
      final lineDiscount = (row['discount_amount'] as num).toDouble();
      final unitDiscount = originalQty == 0 ? 0 : (lineDiscount / originalQty);
      final lineGross = roundCurrency(
        returnedQty * (unitPrice - unitDiscount),
      );
      final returnAmount = oldSubtotal > 0.000001
          ? roundCurrency(oldTotalAmount * lineGross / oldSubtotal)
          : lineGross;
      returnAmountTotal = roundCurrency(returnAmountTotal + returnAmount);
    }

    final subtotalAmount = roundCurrency(
      request.items.fold<double>(0, (sum, item) => sum + item.lineTotal),
    );
    final discountAmount = computeInvoiceHeaderDiscountAmount(
      subtotal: subtotalAmount,
      kind: request.headerDiscountKind,
      value: request.headerDiscountValue,
    );
    final newTotalAmount = roundCurrency(subtotalAmount - discountAmount);

    final paidRows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS paid_amount
      FROM payments
      WHERE invoice_type = 'sale'
        AND invoice_id = ?
        AND reversal_for_id IS NULL
      ''',
      [request.saleId],
    );
    final netPaidAmount = ((paidRows.first['paid_amount'] ?? 0) as num)
        .toDouble();
    final overpaid = (netPaidAmount - newTotalAmount).clamp(
      0,
      double.infinity,
    );
    final maxRefundable = roundCurrency(
      overpaid.clamp(0, returnAmountTotal).toDouble(),
    );
    final paymentSnapshot =
        await _loadAmendmentPaymentSnapshot(db, request.saleId);

    return AmendRefundPreview(
      returnAmountTotal: returnAmountTotal,
      newTotalAmount: newTotalAmount,
      netPaidAmount: netPaidAmount,
      maxRefundable: maxRefundable,
      paymentMethod: paymentSnapshot.method,
      paidCash: paymentSnapshot.paidCash,
      paidWallet: paymentSnapshot.paidWallet,
    );
  }

  Future<void> amendSale(SaleAmendRequest request) async {
    await _appDatabase.database;

    await _transactionRunner.run((txn) async {
      final actorUserId = _sessionService.requireUserId();

      final saleRows = await txn.rawQuery(
        '''
        SELECT s.id, s.account_id, s.status, s.invoice_number, s.total_amount,
               s.returned_total, s.added_total
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

      final originalItemRows = await txn.rawQuery(
        '''
        SELECT
          si.id,
          si.product_id,
          si.quantity,
          si.unit_price,
          si.discount_amount,
          p.unit_type
        FROM sale_items si
        JOIN products p ON p.id = si.product_id
        WHERE si.sale_id = ?
        ORDER BY si.id ASC
        ''',
        [saleId],
      );
      if (originalItemRows.isEmpty && request.items.isEmpty) {
        throw StateError('Invoice has no items to amend.');
      }

      final oldTotalAmount = ((sale['total_amount'] ?? 0) as num).toDouble();
      final previousReturnedTotal =
          ((sale['returned_total'] ?? 0) as num).toDouble();
      final previousAddedTotal =
          ((sale['added_total'] ?? 0) as num).toDouble();
      final oldSubtotalRows = await txn.rawQuery(
        '''
        SELECT COALESCE(SUM(line_total), 0) AS subtotal
        FROM sale_items
        WHERE sale_id = ?
        ''',
        [saleId],
      );
      final oldSubtotal =
          ((oldSubtotalRows.first['subtotal'] ?? 0) as num).toDouble();

      final cartQtyBySourceId = <int, double>{};
      for (final item in request.items) {
        final sourceId = item.amendSourceSaleItemId;
        if (sourceId == null) continue;
        cartQtyBySourceId[sourceId] = roundQuantity(
          (cartQtyBySourceId[sourceId] ?? 0) + item.quantity,
        );
      }

      var amendReturnTotal = 0.0;
      int? refundReferenceReturnId;

      for (final row in originalItemRows) {
        final sourceId = (row['id'] as num).toInt();
        final originalQty = ((row['quantity'] ?? 0) as num).toDouble();
        final cartQty = cartQtyBySourceId[sourceId] ?? 0;
        if (cartQty >= originalQty - 0.000001) continue;

        final returnedQty = roundQuantity(originalQty - cartQty);
        final unitType = row['unit_type'] as String;
        if (unitType == 'piece' && !isIntegerLike(returnedQty)) {
          throw StateError('Piece products require integer return quantity.');
        }

        final unitPrice = (row['unit_price'] as num).toDouble();
        final lineDiscount = (row['discount_amount'] as num).toDouble();
        final unitDiscount =
            originalQty == 0 ? 0 : (lineDiscount / originalQty);
        final lineGross = roundCurrency(
          returnedQty * (unitPrice - unitDiscount),
        );
        final returnAmount = oldSubtotal > 0.000001
            ? roundCurrency(oldTotalAmount * lineGross / oldSubtotal)
            : lineGross;

        final returnId = await txn.insert('returns', {
          'invoice_type': 'sale',
          'invoice_id': saleId,
          'original_line_id': sourceId,
          'quantity': returnedQty,
          'amount': returnAmount,
          'reason': 'Invoice amendment (cart)',
          'created_by_user_id': actorUserId,
          'created_at': DateTime.now().toIso8601String(),
        });
        refundReferenceReturnId ??= returnId;

        await txn.insert('stock_movements', {
          'product_id': row['product_id'] as int,
          'invoice_type': 'return',
          'invoice_id': returnId,
          'movement_type': 'in',
          'quantity': returnedQty,
          'unit_type': unitType,
          'created_at': DateTime.now().toIso8601String(),
        });

        amendReturnTotal = roundCurrency(amendReturnTotal + returnAmount);

        final accountId = sale['account_id'] as int?;
        if (accountId != null) {
          await txn.insert('ledger_transactions', {
            'account_id': accountId,
            'source_type': 'return',
            'source_id': returnId,
            'amount': returnAmount,
            'entry_kind': 'credit',
            'description': 'Sale return #$returnId (amendment)',
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

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

      var amendAddedTotal = 0.0;
      for (final item in request.items) {
        final quantity = roundQuantity(item.quantity);
        if (item.unitType == 'piece' && !isIntegerLike(quantity)) {
          throw StateError('Piece products require integer quantity.');
        }

        final lineTotal = roundCurrency(item.lineTotal);
        final isNewLine = item.amendSourceSaleItemId == null;
        if (isNewLine) {
          amendAddedTotal = roundCurrency(amendAddedTotal + lineTotal);
        }
        await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': item.productId,
          'quantity': quantity,
          'unit_price': roundCurrency(item.unitPrice),
          'discount_amount': roundCurrency(item.discount),
          'line_total': lineTotal,
          'added_after_amendment': isNewLine ? 1 : 0,
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

      final newReturnedTotal = roundCurrency(
        previousReturnedTotal + amendReturnTotal,
      );
      final newAddedTotal = roundCurrency(previousAddedTotal + amendAddedTotal);

      await txn.update(
        'sales',
        {
          'total_amount': totalAmount,
          'returned_total': newReturnedTotal,
          'added_total': newAddedTotal,
          'status': nextStatus,
          'last_modified_by_user_id': actorUserId,
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

      final overpaidAfterAmend = (netPaidAmount - totalAmount).clamp(
        0,
        double.infinity,
      );
      final maxRefundable = roundCurrency(
        overpaidAfterAmend.clamp(0, amendReturnTotal).toDouble(),
      );
      if (maxRefundable > 0.000001 && refundReferenceReturnId != null) {
        await _applySaleRefunds(
          txn: txn,
          accountId: accountId,
          saleId: saleId,
          returnId: refundReferenceReturnId,
          actorUserId: actorUserId,
          maxRefundable: maxRefundable,
          paymentMethod: request.paymentMethod,
          refundAmountOverride: request.refundAmountOverride,
          refundCashOverride: request.refundCashOverride,
          refundWalletOverride: request.refundWalletOverride,
        );
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
        customerPhone: request.customerPhone,
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
      final phoneTrimmed = request.customerPhone?.trim() ?? '';
      final phoneForDb = phoneTrimmed.isEmpty ? null : phoneTrimmed;
      if (accountId == null && newName.isNotEmpty) {
        accountId = await txn.insert('accounts', {
          'name': newName,
          'account_type': 'customer',
          'phone': phoneForDb,
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
        'primary_payment_method':
            _salePrimaryPaymentMethodForStorage(request.paymentMethod),
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
        await insertPart(paymentParts.visaAmount, 'visa');
      }

      if (!request.isPending && accountId != null && phoneForDb != null) {
        await txn.update(
          'accounts',
          {'phone': phoneForDb},
          where: 'id = ?',
          whereArgs: [accountId],
        );
      }

      return saleId;
    });
  }

  Future<void> settlePendingSale({
    required int saleId,
    required double paidAmount,
    double paidWalletAmount = 0,
    required PaymentMethod paymentMethod,
    String? customerPhone,
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
        await insertPart(parts.visaAmount, 'visa');
      }

      final nextStatus = paidTotalSum + 0.000001 >= totalAmount
          ? SaleStatus.completed.dbValue
          : SaleStatus.partial.dbValue;

      final phoneTrim = customerPhone?.trim() ?? '';
      if (accountId != null && phoneTrim.isNotEmpty) {
        await txn.update(
          'accounts',
          {'phone': phoneTrim},
          where: 'id = ?',
          whereArgs: [accountId],
        );
      }

      await txn.update(
        'sales',
        {
          'status': nextStatus,
          'primary_payment_method':
              _salePrimaryPaymentMethodForStorage(paymentMethod),
          'last_modified_by_user_id': actorUserId,
        },
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
    double? refundAmountOverride,
    double? refundCashOverride,
    double? refundWalletOverride,
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
          'returned_total',
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

      final unitPrice = (row['unit_price'] as num).toDouble();
      final lineDiscount = (row['discount_amount'] as num).toDouble();
      final unitDiscount = soldQty == 0 ? 0 : (lineDiscount / soldQty);
      final lineGross = roundCurrency(
        requestedQty * (unitPrice - unitDiscount),
      );

      final subtotalRows = await txn.rawQuery(
        '''
        SELECT COALESCE(SUM(line_total), 0) AS subtotal
        FROM sale_items
        WHERE sale_id = ?
        ''',
        [saleId],
      );
      final subtotal =
          ((subtotalRows.first['subtotal'] ?? 0) as num).toDouble();
      final oldTotalAmount = ((saleRows.first['total_amount'] ?? 0) as num)
          .toDouble();
      final returnAmount = subtotal > 0.000001
          ? roundCurrency(oldTotalAmount * lineGross / subtotal)
          : lineGross;

      final returnId = await txn.insert('returns', {
        'invoice_type': 'sale',
        'invoice_id': saleId,
        'original_line_id': saleItemId,
        'quantity': requestedQty,
        'amount': returnAmount,
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
      final newTotalAmount = roundCurrency(
        (oldTotalAmount - returnAmount).clamp(0, double.infinity).toDouble(),
      );
      final paidRows = await txn.rawQuery(
        '''
        SELECT COALESCE(SUM(pp.amount), 0) AS paid_amount
        FROM payments pp
        WHERE pp.invoice_type = 'sale'
          AND pp.invoice_id = ?
          AND pp.reversal_for_id IS NULL
        ''',
        [saleId],
      );
      final netPaidAmount = ((paidRows.first['paid_amount'] ?? 0) as num)
          .toDouble();
      final nextStatus = netPaidAmount + 0.000001 >= newTotalAmount
          ? 'completed'
          : 'partial';
      final currentReturnedTotal =
          ((saleRows.first['returned_total'] ?? 0) as num).toDouble();

      await txn.update(
        'sales',
        {
          'total_amount': newTotalAmount,
          'returned_total': roundCurrency(currentReturnedTotal + returnAmount),
          'status': nextStatus,
          'last_modified_by_user_id': actorUserId,
        },
        where: 'id = ?',
        whereArgs: [saleId],
      );

      final accountId = saleRows.first['account_id'] as int?;
      if (accountId != null) {
        await txn.insert('ledger_transactions', {
          'account_id': accountId,
          'source_type': 'return',
          'source_id': returnId,
          'amount': returnAmount,
          'entry_kind': 'credit',
          'description': 'Sale return #$returnId',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      final overpaidAfterReturn = (netPaidAmount - newTotalAmount).clamp(
        0,
        double.infinity,
      );
      final maxRefundable = roundCurrency(
        overpaidAfterReturn.clamp(0, returnAmount).toDouble(),
      );
      if (maxRefundable > 0.000001) {
        await _applySaleRefunds(
          txn: txn,
          accountId: accountId,
          saleId: saleId,
          returnId: returnId,
          actorUserId: actorUserId,
          maxRefundable: maxRefundable,
          paymentMethod: paymentMethod,
          refundAmountOverride: refundAmountOverride,
          refundCashOverride: refundCashOverride,
          refundWalletOverride: refundWalletOverride,
        );
      }
    });
  }

  Future<void> _applySaleRefunds({
    required Transaction txn,
    required int? accountId,
    required int saleId,
    required int returnId,
    required int actorUserId,
    required double maxRefundable,
    required PaymentMethod paymentMethod,
    double? refundAmountOverride,
    double? refundCashOverride,
    double? refundWalletOverride,
  }) async {
    var refundableToPay = maxRefundable;
    if (refundAmountOverride != null) {
      refundableToPay = roundCurrency(
        refundAmountOverride.clamp(0, maxRefundable).toDouble(),
      );
    }
    if (refundableToPay <= 0.000001) return;

    final useSplitRefund =
        refundCashOverride != null || refundWalletOverride != null;
    if (useSplitRefund) {
      var cashRefund = roundCurrency(
        (refundCashOverride ?? 0).clamp(0, refundableToPay),
      );
      var walletRefund = roundCurrency(
        (refundWalletOverride ?? 0).clamp(0, refundableToPay),
      );
      final splitTotal = roundCurrency(cashRefund + walletRefund);
      if (splitTotal > refundableToPay + 0.000001) {
        throw StateError('Refund split exceeds allowed refund amount.');
      }
      if (splitTotal < refundableToPay - 0.000001 &&
          refundAmountOverride == null) {
        walletRefund = roundCurrency(refundableToPay - cashRefund);
      }

      if (cashRefund > 0.000001) {
        await _insertSaleRefundPayment(
          txn: txn,
          accountId: accountId,
          saleId: saleId,
          returnId: returnId,
          actorUserId: actorUserId,
          amount: cashRefund,
          method: PaymentMethod.cash,
        );
      }
      if (walletRefund > 0.000001) {
        await _insertSaleRefundPayment(
          txn: txn,
          accountId: accountId,
          saleId: saleId,
          returnId: returnId,
          actorUserId: actorUserId,
          amount: walletRefund,
          method: PaymentMethod.vodafoneCash,
        );
      }
      return;
    }

    await _insertSaleRefundPayment(
      txn: txn,
      accountId: accountId,
      saleId: saleId,
      returnId: returnId,
      actorUserId: actorUserId,
      amount: refundableToPay,
      method: paymentMethod,
    );
  }

  Future<void> _insertSaleRefundPayment({
    required Transaction txn,
    required int? accountId,
    required int saleId,
    required int returnId,
    required int actorUserId,
    required double amount,
    required PaymentMethod method,
  }) async {
    final paymentId = await txn.insert('payments', {
      'account_id': accountId,
      'invoice_type': 'sale',
      'invoice_id': saleId,
      'payment_method': _toDbMethod(method),
      'amount': -amount,
      'is_refund': 1,
      'is_standalone': 0,
      'notes': 'Refund for sale return #$returnId',
      'created_by_user_id': actorUserId,
      'created_at': DateTime.now().toIso8601String(),
    });

    if (accountId == null) return;

    await txn.insert('ledger_transactions', {
      'account_id': accountId,
      'source_type': 'payment',
      'source_id': paymentId,
      'amount': amount,
      'entry_kind': 'debit',
      'description': 'Refund payment for return #$returnId',
      'created_at': DateTime.now().toIso8601String(),
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
        {
          'status': 'cancelled',
          'last_modified_by_user_id': actorUserId,
        },
        where: 'id = ?',
        whereArgs: [saleId],
      );
    });
  }

  String _salePrimaryPaymentMethodForStorage(PaymentMethod method) {
    return switch (method) {
      PaymentMethod.cash => 'cash',
      PaymentMethod.vodafoneCash => 'vodafone_cash',
      PaymentMethod.visa => 'visa',
      PaymentMethod.cashAndWallet => 'cash_and_wallet',
    };
  }

  String _toDbMethod(PaymentMethod method) {
    return switch (method) {
      PaymentMethod.cash => 'cash',
      PaymentMethod.vodafoneCash => 'vodafone_cash',
      PaymentMethod.visa => 'visa',
      PaymentMethod.cashAndWallet => throw StateError(
        'Refunds/settlement must target a single channel.',
      ),
    };
  }

  ({
    double cashAmount,
    double walletAmount,
    double visaAmount,
    double totalPaid,
  })
  _salePaymentCashWalletParts({
    required PaymentMethod method,
    required double totalAmount,
    required double paidCash,
    required double paidWallet,
  }) {
    switch (method) {
      case PaymentMethod.cash:
        final c = roundCurrency(paidCash.clamp(0, totalAmount));
        return (
          cashAmount: c,
          walletAmount: 0.0,
          visaAmount: 0.0,
          totalPaid: c,
        );
      case PaymentMethod.vodafoneCash:
        final w = roundCurrency(paidCash.clamp(0, totalAmount));
        return (
          cashAmount: 0.0,
          walletAmount: w,
          visaAmount: 0.0,
          totalPaid: w,
        );
      case PaymentMethod.visa:
        final v = roundCurrency(paidCash.clamp(0, totalAmount));
        return (
          cashAmount: 0.0,
          walletAmount: 0.0,
          visaAmount: v,
          totalPaid: v,
        );
      case PaymentMethod.cashAndWallet:
        var c = roundCurrency(paidCash.clamp(0, totalAmount));
        final maxWallet = roundCurrency(
          (totalAmount - c).clamp(0, double.infinity),
        );
        final w = roundCurrency(paidWallet.clamp(0, maxWallet));
        return (
          cashAmount: c,
          walletAmount: w,
          visaAmount: 0.0,
          totalPaid: roundCurrency(c + w),
        );
    }
  }
}
