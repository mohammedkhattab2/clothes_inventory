import 'package:delta_erp/core/utils/number_utils.dart';
import 'package:delta_erp/core/utils/invoice_number_display.dart';
import 'package:delta_erp/core/utils/return_rules.dart';
import 'package:delta_erp/core/utils/sql_like_escape.dart';
import 'package:delta_erp/features/invoices/domain/invoice_suggestion.dart';
import 'package:delta_erp/features/purchases/domain/purchase_models.dart';
import 'package:delta_erp/features/sales/domain/sale_models.dart';
import 'package:delta_erp/services/auth/session_service.dart';
import 'package:delta_erp/services/database/app_database.dart';
import 'package:delta_erp/services/database/db_transaction_runner.dart';
import 'package:delta_erp/services/database/invoice_sequence_allocator.dart';
import 'package:sqflite/sqlite_api.dart';

String _purchaseInvoiceActorLabel(String? fullName, String? username) {
  final n = (fullName ?? '').trim();
  if (n.isNotEmpty) return n;
  final u = (username ?? '').trim();
  if (u.isNotEmpty) return u;
  return '-';
}

class PurchaseInvoiceSummary {
  const PurchaseInvoiceSummary({
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
  final String createdByDisplay;
  final String? lastModifiedByDisplay;

  /// Distinct payment methods from SQL `GROUP_CONCAT`, or one method. Display via `invoicePaymentMethodsDisplayLabel`.
  final String? paymentMethod;
}

class PurchaseInvoiceLine {
  const PurchaseInvoiceLine({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.returnedQuantity,
    required this.remainingQuantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final int id;
  final int productId;
  final String productName;
  final double quantity;
  final double returnedQuantity;
  final double remainingQuantity;
  final double unitPrice;
  final double lineTotal;
}

class PurchasesRepository {
  const PurchasesRepository(
    this._appDatabase,
    this._transactionRunner,
    this._sessionService,
  );

  final AppDatabase _appDatabase;
  final DbTransactionRunner _transactionRunner;
  final SessionService _sessionService;

  Future<List<PurchaseInvoiceSummary>> listInvoices({
    DateTime? fromDate,
    DateTime? toDate,
    int? accountId,
    int? categoryId,
    List<String>? statuses,
    String? searchQuery,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await _appDatabase.database;
    final where = <String>['p.status != ?'];
    final args = <Object?>['cancelled'];
    final currentUser = _sessionService.currentUser;

    if (currentUser != null && !_sessionService.canViewAllInvoices) {
      where.add('p.created_by_user_id = ?');
      args.add(currentUser.id);
    }

    if (fromDate != null) {
      where.add('datetime(p.created_at) >= datetime(?)');
      args.add(fromDate.toIso8601String());
    }
    if (toDate != null) {
      final endExclusive = DateTime(
        toDate.year,
        toDate.month,
        toDate.day,
      ).add(const Duration(days: 1));
      where.add('datetime(p.created_at) < datetime(?)');
      args.add(endExclusive.toIso8601String());
    }
    if (accountId != null) {
      where.add('p.account_id = ?');
      args.add(accountId);
    }
    if (categoryId != null) {
      where.add(
        'EXISTS (SELECT 1 FROM purchase_items pi JOIN products pr ON pr.id = pi.product_id WHERE pi.purchase_id = p.id AND pr.category_id = ?)',
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
        where.add('p.status IN ($placeholders)');
        args.addAll(normalized);
      }
    }

    final normalizedSearch = searchQuery?.trim() ?? '';
    if (normalizedSearch.isNotEmpty) {
      final pattern = '%${escapeSqlLikeLiteral(normalizedSearch)}%';
      where.add(
        r"(p.invoice_number LIKE ? ESCAPE '\' OR CAST(p.id AS TEXT) LIKE ? ESCAPE '\' OR COALESCE(a.name, '-') LIKE ? ESCAPE '\')",
      );
      args.add(pattern);
      args.add(pattern);
      args.add(pattern);
    }

    args.add(limit);
    args.add(offset);

    final rows = await db.rawQuery('''
      SELECT
        p.id,
        p.invoice_number,
        p.last_modified_by_user_id AS last_mod_uid,
        COALESCE((
          SELECT GROUP_CONCAT(pr.name, ', ')
          FROM purchase_items pi
          JOIN products pr ON pr.id = pi.product_id
          WHERE pi.purchase_id = p.id
        ), '-') AS products_summary,
        a.name AS account_name,
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
          SELECT SUM(CASE WHEN pay.reversal_for_id IS NULL THEN pay.amount ELSE 0 END)
          FROM payments pay
          WHERE pay.invoice_type = 'purchase' AND pay.invoice_id = p.id
        ), 0) AS paid_amount,
        (
          SELECT GROUP_CONCAT(DISTINCT payment_method)
          FROM payments
          WHERE invoice_type = 'purchase'
            AND invoice_id = p.id
            AND reversal_for_id IS NULL
            AND is_refund = 0
        ) AS last_payment_method,
        p.created_at,
        uc.full_name AS creator_full_name,
        uc.username AS creator_username,
        um.full_name AS modifier_full_name,
        um.username AS modifier_username
      FROM purchases p
      JOIN accounts a ON a.id = p.account_id
      LEFT JOIN users uc ON uc.id = p.created_by_user_id
      LEFT JOIN users um ON um.id = p.last_modified_by_user_id
      WHERE ${where.join(' AND ')}
      ORDER BY datetime(p.created_at) DESC, p.id DESC
      LIMIT ? OFFSET ?
      ''', args);

    return rows
        .map(
          (row) => PurchaseInvoiceSummary(
            id: (row['id'] as num).toInt(),
            invoiceNumber: (row['invoice_number'] as String?) ?? '-',
            productsSummary: (row['products_summary'] as String?) ?? '-',
            accountName: (row['account_name'] as String?) ?? 'Unknown',
            status: (row['status'] as String?) ?? 'completed',
            totalAmount: ((row['total_amount'] ?? 0) as num).toDouble(),
            paidAmount: ((row['paid_amount'] ?? 0) as num).toDouble(),
            outstandingAmount:
                ((((row['total_amount'] ?? 0) as num).toDouble() -
                            ((row['paid_amount'] ?? 0) as num).toDouble())
                        .clamp(0, double.infinity))
                    .toDouble(),
            createdAt: DateTime.parse(row['created_at'] as String),
            createdByDisplay: _purchaseInvoiceActorLabel(
              row['creator_full_name'] as String?,
              row['creator_username'] as String?,
            ),
            lastModifiedByDisplay: row['last_mod_uid'] == null
                ? null
                : _purchaseInvoiceActorLabel(
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

  Future<Map<String, int>> countInvoicesByStatus({
    DateTime? fromDate,
    DateTime? toDate,
    int? accountId,
    int? categoryId,
    String? searchQuery,
  }) async {
    final db = await _appDatabase.database;

    final where = <String>['p.status != ?'];
    final args = <Object?>['cancelled'];
    final currentUser = _sessionService.currentUser;

    if (currentUser != null && !_sessionService.canViewAllInvoices) {
      where.add('p.created_by_user_id = ?');
      args.add(currentUser.id);
    }

    if (fromDate != null) {
      where.add('datetime(p.created_at) >= datetime(?)');
      args.add(fromDate.toIso8601String());
    }
    if (toDate != null) {
      final endExclusive = DateTime(
        toDate.year,
        toDate.month,
        toDate.day,
      ).add(const Duration(days: 1));
      where.add('datetime(p.created_at) < datetime(?)');
      args.add(endExclusive.toIso8601String());
    }
    if (accountId != null) {
      where.add('p.account_id = ?');
      args.add(accountId);
    }
    if (categoryId != null) {
      where.add(
        'EXISTS (SELECT 1 FROM purchase_items pi JOIN products pr ON pr.id = pi.product_id WHERE pi.purchase_id = p.id AND pr.category_id = ?)',
      );
      args.add(categoryId);
    }

    final normalizedSearch = searchQuery?.trim() ?? '';
    if (normalizedSearch.isNotEmpty) {
      final pattern = '%${escapeSqlLikeLiteral(normalizedSearch)}%';
      where.add(
        r"(p.invoice_number LIKE ? ESCAPE '\' OR CAST(p.id AS TEXT) LIKE ? ESCAPE '\' OR COALESCE(a.name, '-') LIKE ? ESCAPE '\')",
      );
      args.add(pattern);
      args.add(pattern);
      args.add(pattern);
    }

    final rows = await db.rawQuery('''
      SELECT p.status, COUNT(*) AS cnt
      FROM purchases p
      JOIN accounts a ON a.id = p.account_id
      WHERE ${where.join(' AND ')}
      GROUP BY p.status
      ''', args);

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

  Future<InvoiceSuggestion?> lookupPurchaseInvoiceSuggestionForReturn(
    int purchaseId,
  ) async {
    final db = await _appDatabase.database;

    final where = <String>['p.status != ?', 'p.id = ?'];
    final args = <Object?>['cancelled', purchaseId];
    final currentUser = _sessionService.currentUser;

    if (currentUser != null && !_sessionService.canViewAllInvoices) {
      where.add('p.created_by_user_id = ?');
      args.add(currentUser.id);
    }

    final rows = await db.rawQuery('''
      SELECT p.id, p.invoice_number, a.name AS account_name
      FROM purchases p
      JOIN accounts a ON a.id = p.account_id
      WHERE ${where.join(' AND ')}
      LIMIT 1
      ''', args);

    if (rows.isEmpty) return null;
    final row = rows.first;
    final id = (row['id'] as num).toInt();
    final rawNo = (row['invoice_number'] as String?) ?? '-';
    return InvoiceSuggestion(
      id: id,
      invoiceNumber: displayPurchaseInvoiceNumber(
        id: id,
        rawInvoiceNumber: rawNo,
      ),
      accountLabel: (row['account_name'] as String?) ?? '-',
    );
  }

  Future<List<InvoiceSuggestion>> suggestPurchaseInvoicesForReturn(
    String prefixRaw, {
    int limit = 40,
  }) async {
    final prefix = prefixRaw.trim();
    if (prefix.isEmpty) return const [];

    final db = await _appDatabase.database;

    final where = <String>['p.status != ?'];
    final args = <Object?>['cancelled'];
    final currentUser = _sessionService.currentUser;

    if (currentUser != null && !_sessionService.canViewAllInvoices) {
      where.add('p.created_by_user_id = ?');
      args.add(currentUser.id);
    }

    final pattern = '${escapeSqlLikeLiteral(prefix)}%';
    where.add(
      r"(p.invoice_number LIKE ? ESCAPE '\' OR CAST(p.id AS TEXT) LIKE ? ESCAPE '\')",
    );
    args.add(pattern);
    args.add(pattern);
    args.add(limit);

    final rows = await db.rawQuery('''
      SELECT p.id, p.invoice_number, a.name AS account_name
      FROM purchases p
      JOIN accounts a ON a.id = p.account_id
      WHERE ${where.join(' AND ')}
      ORDER BY datetime(p.created_at) DESC, p.id DESC
      LIMIT ?
      ''', args);

    return rows.map((row) {
      final id = (row['id'] as num).toInt();
      final rawNo = (row['invoice_number'] as String?) ?? '-';
      return InvoiceSuggestion(
        id: id,
        invoiceNumber: displayPurchaseInvoiceNumber(
          id: id,
          rawInvoiceNumber: rawNo,
        ),
        accountLabel: (row['account_name'] as String?) ?? '-',
      );
    }).toList();
  }

  Future<double?> averagePurchasedUnitPrice(int productId) async {
    final db = await _appDatabase.database;
    final rows = await db.rawQuery(
      '''
      SELECT AVG(pi.unit_price) AS avg_price
      FROM purchase_items pi
      JOIN purchases p ON p.id = pi.purchase_id
      WHERE pi.product_id = ? AND p.status != 'cancelled'
      ''',
      [productId],
    );

    if (rows.isEmpty) return null;
    final value = rows.first['avg_price'];
    if (value == null) return null;
    return (value as num).toDouble();
  }

  Future<int> supplierInvoiceCount(int supplierId) async {
    final db = await _appDatabase.database;
    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS c
      FROM purchases
      WHERE account_id = ? AND status != 'cancelled'
      ''',
      [supplierId],
    );

    if (rows.isEmpty) return 0;
    return ((rows.first['c'] ?? 0) as num).toInt();
  }

  Future<double?> supplierAverageItemsPerInvoice(int supplierId) async {
    final db = await _appDatabase.database;
    final rows = await db.rawQuery(
      '''
      SELECT AVG(item_count) AS avg_items
      FROM (
        SELECT p.id, COUNT(pi.id) AS item_count
        FROM purchases p
        LEFT JOIN purchase_items pi ON pi.purchase_id = p.id
        WHERE p.account_id = ? AND p.status != 'cancelled'
        GROUP BY p.id
      ) s
      ''',
      [supplierId],
    );

    if (rows.isEmpty) return null;
    final value = rows.first['avg_items'];
    if (value == null) return null;
    return (value as num).toDouble();
  }

  Future<List<PurchaseInvoiceLine>> listInvoiceLines(int purchaseId) async {
    final db = await _appDatabase.database;
    final rows = await db.rawQuery(
      '''
      SELECT
        pi.id,
        pi.product_id,
        p.name AS product_name,
        pi.quantity,
        COALESCE(r.returned_qty, 0) AS returned_qty,
        CASE
          WHEN (pi.quantity - COALESCE(r.returned_qty, 0)) > 0
            THEN (pi.quantity - COALESCE(r.returned_qty, 0))
          ELSE 0
        END AS remaining_qty,
        pi.unit_price,
        pi.line_total
      FROM purchase_items pi
      JOIN products p ON p.id = pi.product_id
      LEFT JOIN (
        SELECT original_line_id, COALESCE(SUM(quantity), 0) AS returned_qty
        FROM returns
        WHERE invoice_type = 'purchase'
        GROUP BY original_line_id
      ) r ON r.original_line_id = pi.id
      WHERE pi.purchase_id = ?
      ORDER BY pi.id ASC
      ''',
      [purchaseId],
    );

    return rows
        .map(
          (row) => PurchaseInvoiceLine(
            id: (row['id'] as num).toInt(),
            productId: (row['product_id'] as num).toInt(),
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

  Future<int> createPurchase(PurchaseCreateRequest request) async {
    await _appDatabase.database;

    return _transactionRunner.run((txn) async {
      final actorUserId = _sessionService.requireUserId();

      if (request.items.isEmpty) {
        throw StateError('Purchase must have at least one item.');
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
      final paidAmount = roundCurrency(
        request.paidAmount.clamp(0, totalAmount),
      );
      final status = paidAmount >= totalAmount ? 'completed' : 'partial';
      final invoiceNo = await allocatePurchaseInvoiceNumber(txn);
      final createdAt = (request.createdAt ?? DateTime.now()).toIso8601String();

      final purchaseId = await txn.insert('purchases', {
        'account_id': request.supplierId,
        'invoice_number': invoiceNo,
        'status': status,
        'total_amount': totalAmount,
        'notes': request.notes,
        'created_by_user_id': actorUserId,
        'created_at': createdAt,
      });

      for (final item in request.items) {
        final quantity = roundQuantity(item.quantity);
        if (item.unitType == 'piece' && !isIntegerLike(quantity)) {
          throw StateError('Piece products require integer quantity.');
        }

        final lineTotal = roundCurrency(item.lineTotal);
        await txn.insert('purchase_items', {
          'purchase_id': purchaseId,
          'product_id': item.productId,
          'quantity': quantity,
          'unit_price': roundCurrency(item.unitPrice),
          'discount_amount': roundCurrency(item.discount),
          'line_total': lineTotal,
          'created_at': createdAt,
        });

        await txn.insert('stock_movements', {
          'product_id': item.productId,
          'invoice_type': 'purchase',
          'invoice_id': purchaseId,
          'movement_type': 'in',
          'quantity': quantity,
          'unit_type': item.unitType,
          'created_at': createdAt,
        });
      }

      await txn.insert('ledger_transactions', {
        'account_id': request.supplierId,
        'source_type': 'purchase',
        'source_id': purchaseId,
        'amount': totalAmount,
        'entry_kind': 'credit',
        'description': 'Purchase invoice $invoiceNo',
        'created_at': createdAt,
      });

      if (paidAmount > 0) {
        final paymentId = await txn.insert('payments', {
          'account_id': request.supplierId,
          'invoice_type': 'purchase',
          'invoice_id': purchaseId,
          'payment_method': _toDbMethod(request.paymentMethod),
          'amount': paidAmount,
          'is_refund': 0,
          'is_standalone': 0,
          'notes': 'Payment for $invoiceNo',
          'created_by_user_id': actorUserId,
          'created_at': createdAt,
        });

        await txn.insert('ledger_transactions', {
          'account_id': request.supplierId,
          'source_type': 'payment',
          'source_id': paymentId,
          'amount': paidAmount,
          'entry_kind': 'debit',
          'description': 'Payment for purchase $invoiceNo',
          'created_at': createdAt,
        });
      }

      return purchaseId;
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

  Future<bool> purchaseInvoiceHasReturns(int purchaseId) async {
    final db = await _appDatabase.database;
    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS c
      FROM returns
      WHERE invoice_type = ? AND invoice_id = ?
      ''',
      ['purchase', purchaseId],
    );
    return (((rows.first['c'] ?? 0) as num).toInt() > 0);
  }

  Future<bool> canAmendPurchaseInvoice(int purchaseId) async {
    final db = await _appDatabase.database;
    final rows = await db.rawQuery(
      '''
      SELECT p.status FROM purchases p WHERE p.id = ? LIMIT 1
      ''',
      [purchaseId],
    );
    if (rows.isEmpty) return false;
    final status = ((rows.first['status'] as String?) ?? '')
        .trim()
        .toLowerCase();
    if (status == 'cancelled') return false;
    if (status != 'completed' && status != 'partial') return false;
    return !(await purchaseInvoiceHasReturns(purchaseId));
  }

  void _rejectIfPurchaseNotEligibleForAmend({required String? status}) {
    final normalized = (status ?? '').trim().toLowerCase();
    if (normalized == 'cancelled') {
      throw StateError('This invoice cannot be amended.');
    }
    if (normalized != 'completed' && normalized != 'partial') {
      throw StateError('This invoice cannot be amended.');
    }
  }

  Future<void> _assertNoPurchaseReturns(
    DatabaseExecutor executor,
    int purchaseId,
  ) async {
    final rows = await executor.rawQuery(
      '''
      SELECT COUNT(*) AS c
      FROM returns
      WHERE invoice_type = ? AND invoice_id = ?
      ''',
      ['purchase', purchaseId],
    );
    if ((((rows.first['c'] ?? 0) as num).toInt() > 0)) {
      throw StateError('Cannot amend a purchase that has returns.');
    }
  }

  Future<PurchaseAmendmentPaymentSnapshot>
  _loadPurchaseAmendmentPaymentSnapshot(
    DatabaseExecutor executor,
    int purchaseId,
  ) async {
    final rows = await executor.rawQuery(
      '''
      SELECT payment_method AS m,
             SUM(amount) AS net_amount
      FROM payments
      WHERE invoice_type = 'purchase'
        AND invoice_id = ?
        AND reversal_for_id IS NULL
      GROUP BY payment_method
      ''',
      [purchaseId],
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
      return PurchaseAmendmentPaymentSnapshot(
        paidCash: cash,
        paidWallet: wallet,
        method: method,
      );
    }
    if (visa > 0.000001 && cash < 0.000001 && wallet < 0.000001) {
      method = PaymentMethod.visa;
      return PurchaseAmendmentPaymentSnapshot(
        paidCash: visa,
        paidWallet: 0,
        method: method,
      );
    }
    if (wallet > 0.000001 && cash < 0.000001 && visa < 0.000001) {
      method = PaymentMethod.vodafoneCash;
      return PurchaseAmendmentPaymentSnapshot(
        paidCash: wallet,
        paidWallet: 0,
        method: method,
      );
    }

    method = PaymentMethod.cash;
    return PurchaseAmendmentPaymentSnapshot(
      paidCash: cash,
      paidWallet: 0,
      method: method,
    );
  }

  Future<PendingPurchaseDraft> loadPurchaseDraftForAmendment(
    int purchaseId,
  ) async {
    final db = await _appDatabase.database;

    final purchaseRows = await db.rawQuery(
      '''
      SELECT p.id, p.account_id, p.status, p.total_amount
      FROM purchases p
      WHERE p.id = ?
      LIMIT 1
      ''',
      [purchaseId],
    );
    if (purchaseRows.isEmpty) {
      throw StateError('Purchase not found.');
    }
    final purchase = purchaseRows.first;
    _rejectIfPurchaseNotEligibleForAmend(status: purchase['status'] as String?);
    await _assertNoPurchaseReturns(db, purchaseId);

    final supplierId = (purchase['account_id'] as num?)?.toInt();
    if (supplierId == null) {
      throw StateError('Purchase has no supplier.');
    }

    final itemRows = await db.rawQuery(
      '''
      SELECT
        pi.product_id,
        p.name AS product_name,
        p.barcode AS barcode,
        p.unit_type,
        pi.quantity,
        pi.unit_price,
        pi.discount_amount,
        pi.line_total
      FROM purchase_items pi
      JOIN products p ON p.id = pi.product_id
      WHERE pi.purchase_id = ?
      ORDER BY pi.id ASC
      ''',
      [purchaseId],
    );
    if (itemRows.isEmpty) {
      throw StateError('Invoice has no items to amend.');
    }

    final qtyOnInvoiceByProduct = <int, double>{};
    for (final row in itemRows) {
      final productId = (row['product_id'] as num).toInt();
      final q = ((row['quantity'] ?? 0) as num).toDouble();
      qtyOnInvoiceByProduct[productId] = roundQuantity(
        (qtyOnInvoiceByProduct[productId] ?? 0) + q,
      );
    }

    final items = itemRows
        .map(
          (row) => PurchaseDraftItem(
            productId: (row['product_id'] as num).toInt(),
            productName: (row['product_name'] as String?) ?? 'Product',
            barcode: (row['barcode'] as String?)?.trim(),
            unitType: (row['unit_type'] as String?) ?? 'piece',
            quantity: ((row['quantity'] ?? 0) as num).toDouble(),
            unitPrice: ((row['unit_price'] ?? 0) as num).toDouble(),
            discount: ((row['discount_amount'] ?? 0) as num).toDouble(),
          ),
        )
        .toList(growable: false);

    final subtotal = roundCurrency(
      items.fold<double>(0, (sum, item) => sum + item.lineTotal),
    );
    final total = ((purchase['total_amount'] ?? 0) as num).toDouble();
    final InvoiceHeaderDiscountKind headerKind;
    final double headerValue;
    if (total <= subtotal + 0.000001) {
      headerKind = InvoiceHeaderDiscountKind.fixed;
      headerValue = roundCurrency((subtotal - total).clamp(0, double.infinity));
    } else {
      headerKind = InvoiceHeaderDiscountKind.percent;
      headerValue = 0;
    }

    final amendmentPayments = await _loadPurchaseAmendmentPaymentSnapshot(
      db,
      purchaseId,
    );

    return PendingPurchaseDraft(
      purchaseId: (purchase['id'] as num).toInt(),
      supplierId: supplierId,
      headerDiscountKind: headerKind,
      headerDiscountValue: headerValue,
      items: items,
      amendmentPayments: amendmentPayments,
      amendmentStockCreditByProduct: Map<int, double>.from(
        qtyOnInvoiceByProduct,
      ),
    );
  }

  Future<Map<int, double>> _rawStockBalanceByProduct(
    DatabaseExecutor executor,
    List<int> productIds,
  ) async {
    if (productIds.isEmpty) return const <int, double>{};
    final placeholders = List.filled(productIds.length, '?').join(',');
    final rows = await executor.rawQuery('''
      SELECT
        p.id,
        COALESCE(SUM(
          CASE
            WHEN sm.movement_type = 'in' THEN sm.quantity
            WHEN sm.movement_type = 'out' THEN -sm.quantity
            ELSE 0
          END
        ), 0) AS balance
      FROM products p
      LEFT JOIN stock_movements sm ON sm.product_id = p.id
      WHERE p.id IN ($placeholders)
      GROUP BY p.id
      ''', productIds);
    return {
      for (final r in rows)
        (r['id'] as num).toInt(): ((r['balance'] ?? 0) as num).toDouble(),
    };
  }

  Future<void> amendPurchase(PurchaseAmendRequest request) async {
    if (request.items.isEmpty) {
      throw StateError('Purchase must have at least one item.');
    }

    await _transactionRunner.run((txn) async {
      final actorUserId = _sessionService.requireUserId();

      final purchaseRows = await txn.rawQuery(
        '''
        SELECT p.id, p.account_id, p.status, p.invoice_number, p.total_amount
        FROM purchases p
        WHERE p.id = ?
        LIMIT 1
        ''',
        [request.purchaseId],
      );
      if (purchaseRows.isEmpty) {
        throw StateError('Purchase not found.');
      }
      final purchaseRow = purchaseRows.first;
      final purchaseId = request.purchaseId;
      _rejectIfPurchaseNotEligibleForAmend(
        status: purchaseRow['status'] as String?,
      );
      await _assertNoPurchaseReturns(txn, purchaseId);

      final oldItemRows = await txn.rawQuery(
        '''
        SELECT product_id, quantity
        FROM purchase_items
        WHERE purchase_id = ?
        ''',
        [purchaseId],
      );
      final oldQtyByProduct = <int, double>{};
      for (final row in oldItemRows) {
        final pid = (row['product_id'] as num).toInt();
        final q = ((row['quantity'] ?? 0) as num).toDouble();
        oldQtyByProduct[pid] = roundQuantity((oldQtyByProduct[pid] ?? 0) + q);
      }

      await txn.delete(
        'stock_movements',
        where: 'invoice_type = ? AND invoice_id = ? AND movement_type = ?',
        whereArgs: ['purchase', purchaseId, 'in'],
      );

      await txn.delete(
        'purchase_items',
        where: 'purchase_id = ?',
        whereArgs: [purchaseId],
      );

      final requestedByProduct = <int, double>{};
      for (final item in request.items) {
        final quantity = roundQuantity(item.quantity);
        if (quantity <= 0) {
          throw StateError('Quantity must be greater than zero.');
        }
        requestedByProduct[item.productId] = roundQuantity(
          (requestedByProduct[item.productId] ?? 0) + quantity,
        );
      }

      for (final entry in oldQtyByProduct.entries) {
        requestedByProduct.putIfAbsent(entry.key, () => 0);
      }

      final productIds = requestedByProduct.keys.toList(growable: false);
      final balances = await _rawStockBalanceByProduct(txn, productIds);

      for (final entry in requestedByProduct.entries) {
        final pid = entry.key;
        final newTotal = roundQuantity(entry.value);
        final bal = balances[pid] ?? 0;
        if (bal + newTotal < -0.000001) {
          final nameRows = await txn.rawQuery(
            'SELECT name FROM products WHERE id = ? LIMIT 1',
            [pid],
          );
          final name = nameRows.isEmpty
              ? 'Product'
              : ((nameRows.first['name'] as String?) ?? 'Product');
          throw StateError(
            'Insufficient stock for $name to reduce this purchase. Current balance '
            '${bal.toStringAsFixed(2)}; purchased quantity would be '
            '${newTotal.toStringAsFixed(2)}.',
          );
        }
      }

      final invoiceNo =
          (purchaseRow['invoice_number'] as String?) ?? 'P-$purchaseId';
      final supplierId = (purchaseRow['account_id'] as num).toInt();

      final subtotalAmount = roundCurrency(
        request.items.fold<double>(0, (sum, item) => sum + item.lineTotal),
      );
      final totalAmount = roundCurrency(
        subtotalAmount -
            computeInvoiceHeaderDiscountAmount(
              subtotal: subtotalAmount,
              kind: request.headerDiscountKind,
              value: request.headerDiscountValue,
            ),
      );

      final paidRows = await txn.rawQuery(
        '''
        SELECT COALESCE(SUM(amount), 0) AS paid_amount
        FROM payments
        WHERE invoice_type = 'purchase'
          AND invoice_id = ?
          AND reversal_for_id IS NULL
        ''',
        [purchaseId],
      );
      final netPaidAmount = ((paidRows.first['paid_amount'] ?? 0) as num)
          .toDouble();

      final nextStatus = netPaidAmount + 0.000001 >= totalAmount
          ? 'completed'
          : 'partial';

      final now = DateTime.now().toIso8601String();

      for (final item in request.items) {
        final quantity = roundQuantity(item.quantity);
        if (item.unitType == 'piece' && !isIntegerLike(quantity)) {
          throw StateError('Piece products require integer quantity.');
        }

        final lineTotal = roundCurrency(item.lineTotal);
        await txn.insert('purchase_items', {
          'purchase_id': purchaseId,
          'product_id': item.productId,
          'quantity': quantity,
          'unit_price': roundCurrency(item.unitPrice),
          'discount_amount': roundCurrency(item.discount),
          'line_total': lineTotal,
          'created_at': now,
        });

        await txn.insert('stock_movements', {
          'product_id': item.productId,
          'invoice_type': 'purchase',
          'invoice_id': purchaseId,
          'movement_type': 'in',
          'quantity': quantity,
          'unit_type': item.unitType,
          'created_at': now,
        });
      }

      await txn.update(
        'purchases',
        {
          'total_amount': totalAmount,
          'status': nextStatus,
          'last_modified_by_user_id': actorUserId,
        },
        where: 'id = ?',
        whereArgs: [purchaseId],
      );

      final ledgerRows = await txn.query(
        'ledger_transactions',
        columns: ['id'],
        where:
            'account_id = ? AND source_type = ? AND source_id = ? AND entry_kind = ?',
        whereArgs: [supplierId, 'purchase', purchaseId, 'credit'],
      );
      if (ledgerRows.isEmpty) {
        throw StateError(
          'Purchase ledger credit entry missing for supplier account.',
        );
      }
      for (final row in ledgerRows) {
        await txn.update(
          'ledger_transactions',
          {'amount': totalAmount, 'description': 'Purchase invoice $invoiceNo'},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    });
  }

  Future<void> returnPurchaseItem({
    required int purchaseId,
    required int purchaseItemId,
    required double quantity,
    String? reason,
  }) async {
    await _appDatabase.database;

    await _transactionRunner.run((txn) async {
      final actorUserId = _sessionService.requireUserId();

      final purchaseRows = await txn.query(
        'purchases',
        columns: ['id', 'account_id', 'status', 'total_amount'],
        where: 'id = ?',
        whereArgs: [purchaseId],
        limit: 1,
      );
      if (purchaseRows.isEmpty) {
        throw StateError('Purchase not found.');
      }
      if (purchaseRows.first['status'] == 'cancelled') {
        throw StateError('Cancelled purchase cannot be returned.');
      }

      final itemRows = await txn.rawQuery(
        '''
        SELECT pi.id, pi.product_id, pi.quantity, pi.unit_price, pi.discount_amount,
               p.unit_type
        FROM purchase_items pi
        JOIN products p ON p.id = pi.product_id
        WHERE pi.id = ? AND pi.purchase_id = ?
        LIMIT 1
        ''',
        [purchaseItemId, purchaseId],
      );
      if (itemRows.isEmpty) {
        throw StateError('Purchase item not found.');
      }
      final row = itemRows.first;
      final purchasedQty = (row['quantity'] as num).toDouble();
      final requestedQty = roundQuantity(quantity);

      final returnedRows = await txn.rawQuery(
        '''
        SELECT COALESCE(SUM(quantity), 0) AS returned_qty
        FROM returns
        WHERE invoice_type = 'purchase' AND invoice_id = ? AND original_line_id = ?
        ''',
        [purchaseId, purchaseItemId],
      );
      final alreadyReturned = ((returnedRows.first['returned_qty'] ?? 0) as num)
          .toDouble();
      final validation = ReturnRules.validate(
        originalQuantity: purchasedQty,
        alreadyReturned: alreadyReturned,
        requestedQuantity: requestedQty,
        unitType: row['unit_type'] as String,
      );
      if (!validation.isValid) {
        throw StateError(validation.error!);
      }

      final returnId = await txn.insert('returns', {
        'invoice_type': 'purchase',
        'invoice_id': purchaseId,
        'original_line_id': purchaseItemId,
        'quantity': requestedQty,
        'reason': reason,
        'created_by_user_id': actorUserId,
        'created_at': DateTime.now().toIso8601String(),
      });

      await txn.insert('stock_movements', {
        'product_id': row['product_id'] as int,
        'invoice_type': 'return',
        'invoice_id': returnId,
        'movement_type': 'out',
        'quantity': requestedQty,
        'unit_type': row['unit_type'] as String,
        'created_at': DateTime.now().toIso8601String(),
      });

      final unitPrice = (row['unit_price'] as num).toDouble();
      final lineDiscount = (row['discount_amount'] as num).toDouble();
      final unitDiscount = purchasedQty == 0
          ? 0
          : (lineDiscount / purchasedQty);
      final lineGross = roundCurrency(
        requestedQty * (unitPrice - unitDiscount),
      );

      final subtotalRows = await txn.rawQuery(
        '''
        SELECT COALESCE(SUM(line_total), 0) AS subtotal
        FROM purchase_items
        WHERE purchase_id = ?
        ''',
        [purchaseId],
      );
      final subtotal = ((subtotalRows.first['subtotal'] ?? 0) as num)
          .toDouble();
      final oldTotalAmount = ((purchaseRows.first['total_amount'] ?? 0) as num)
          .toDouble();
      final returnAmount = subtotal > 0.000001
          ? roundCurrency(oldTotalAmount * lineGross / subtotal)
          : lineGross;

      final supplierId = purchaseRows.first['account_id'] as int;
      await txn.insert('ledger_transactions', {
        'account_id': supplierId,
        'source_type': 'return',
        'source_id': returnId,
        'amount': returnAmount,
        'entry_kind': 'debit',
        'description': 'Purchase return #$returnId',
        'created_at': DateTime.now().toIso8601String(),
      });

      final newTotalAmount = roundCurrency(
        (oldTotalAmount - returnAmount).clamp(0, double.infinity).toDouble(),
      );
      final paidRows = await txn.rawQuery(
        '''
        SELECT COALESCE(SUM(pp.amount), 0) AS paid_amount
        FROM payments pp
        WHERE pp.invoice_type = 'purchase'
          AND pp.invoice_id = ?
          AND pp.reversal_for_id IS NULL
        ''',
        [purchaseId],
      );
      final paidAmount = ((paidRows.first['paid_amount'] ?? 0) as num)
          .toDouble();
      final nextStatus = paidAmount + 0.000001 >= newTotalAmount
          ? 'completed'
          : 'partial';

      await txn.update(
        'purchases',
        {
          'total_amount': newTotalAmount,
          'status': nextStatus,
          'last_modified_by_user_id': actorUserId,
        },
        where: 'id = ?',
        whereArgs: [purchaseId],
      );
    });
  }

  Future<void> cancelPurchase(int purchaseId) async {
    await _appDatabase.database;

    await _transactionRunner.run((txn) async {
      final actorUserId = _sessionService.requireUserId();

      final purchaseRows = await txn.query(
        'purchases',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [purchaseId],
        limit: 1,
      );
      if (purchaseRows.isEmpty) {
        throw StateError('Purchase not found.');
      }
      if (purchaseRows.first['status'] == 'cancelled') {
        return;
      }

      final returnRows = await txn.rawQuery(
        '''
        SELECT COUNT(*) AS count_returns
        FROM returns
        WHERE invoice_type = 'purchase' AND invoice_id = ?
        ''',
        [purchaseId],
      );
      final hasReturns = ((returnRows.first['count_returns'] ?? 0) as num) > 0;
      if (hasReturns) {
        throw StateError(
          'Cannot cancel purchase with returns. Reverse all returns first.',
        );
      }

      final stockRows = await txn.query(
        'stock_movements',
        where:
            'invoice_type = ? AND invoice_id = ? AND reversal_for_id IS NULL',
        whereArgs: ['purchase', purchaseId],
      );

      final requiredOutByProduct = <int, double>{};
      for (final movement in stockRows) {
        final originalType = movement['movement_type'] as String;
        final opposite = originalType == 'in' ? 'out' : 'in';
        if (opposite != 'out') continue;
        final productId = movement['product_id'] as int;
        final quantity = ((movement['quantity'] ?? 0) as num).toDouble();
        requiredOutByProduct[productId] =
            (requiredOutByProduct[productId] ?? 0) + quantity;
      }

      if (requiredOutByProduct.isNotEmpty) {
        final productIds = requiredOutByProduct.keys.toList();
        final placeholders = List.filled(productIds.length, '?').join(',');
        final stockNowRows = await txn.rawQuery('''
          SELECT
            p.id,
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
          GROUP BY p.id
          ''', productIds);

        final currentStockByProduct = <int, double>{
          for (final row in stockNowRows)
            (row['id'] as num).toInt(): ((row['current_stock'] ?? 0) as num)
                .toDouble(),
        };

        for (final entry in requiredOutByProduct.entries) {
          final available = currentStockByProduct[entry.key] ?? 0;
          if (entry.value > available + 0.000001) {
            throw StateError(
              'Cannot cancel purchase because current stock is insufficient.',
            );
          }
        }
      }

      for (final movement in stockRows) {
        final originalType = movement['movement_type'] as String;
        final opposite = originalType == 'in' ? 'out' : 'in';
        await txn.insert('stock_movements', {
          'product_id': movement['product_id'],
          'invoice_type': 'cancellation',
          'invoice_id': purchaseId,
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
        whereArgs: ['purchase', purchaseId, 'payment', 'purchase', purchaseId],
      );
      for (final entry in ledgerRows) {
        final kind = entry['entry_kind'] as String;
        final oppositeKind = kind == 'debit' ? 'credit' : 'debit';
        await txn.insert('ledger_transactions', {
          'account_id': entry['account_id'],
          'source_type': 'cancellation',
          'source_id': purchaseId,
          'amount': entry['amount'],
          'entry_kind': oppositeKind,
          'description': 'Reversal for purchase #$purchaseId',
          'reversal_for_id': entry['id'],
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      final payments = await txn.query(
        'payments',
        where:
            'invoice_type = ? AND invoice_id = ? AND reversal_for_id IS NULL',
        whereArgs: ['purchase', purchaseId],
      );
      for (final payment in payments) {
        await txn.insert('payments', {
          'account_id': payment['account_id'],
          'invoice_type': 'purchase',
          'invoice_id': purchaseId,
          'payment_method': payment['payment_method'],
          'amount': -((payment['amount'] as num).toDouble()),
          'is_refund': payment['is_refund'],
          'is_standalone': payment['is_standalone'],
          'reversal_for_id': payment['id'],
          'notes': 'Reversal for purchase #$purchaseId',
          'created_by_user_id': actorUserId,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      await txn.update(
        'purchases',
        {'status': 'cancelled', 'last_modified_by_user_id': actorUserId},
        where: 'id = ?',
        whereArgs: [purchaseId],
      );
    });
  }

  String _toDbMethod(PaymentMethod method) {
    return switch (method) {
      PaymentMethod.cash => 'cash',
      PaymentMethod.vodafoneCash => 'vodafone_cash',
      PaymentMethod.visa => 'visa',
      PaymentMethod.cashAndWallet => throw StateError(
        'Purchases cannot use split cash+wallet payment.',
      ),
    };
  }
}
