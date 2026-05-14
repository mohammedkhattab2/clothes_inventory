import 'package:clothes_inventory/core/utils/number_utils.dart';
import 'package:clothes_inventory/core/utils/return_rules.dart';
import 'package:clothes_inventory/features/purchases/domain/purchase_models.dart';
import 'package:clothes_inventory/features/sales/domain/sale_models.dart';
import 'package:clothes_inventory/services/auth/session_service.dart';
import 'package:clothes_inventory/services/database/app_database.dart';
import 'package:clothes_inventory/services/database/db_transaction_runner.dart';

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

class PurchaseInvoiceLine {
  const PurchaseInvoiceLine({
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

    args.add(limit);
    args.add(offset);

    final rows = await db.rawQuery('''
      SELECT
        p.id,
        p.invoice_number,
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
        p.created_at
      FROM purchases p
      JOIN accounts a ON a.id = p.account_id
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
          ),
        )
        .toList();
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
      final taxPercentage = roundCurrency(request.taxPercentage.clamp(0, 100));
      final taxAmount = roundCurrency(subtotalAmount * (taxPercentage / 100));
      final totalAmount = roundCurrency(subtotalAmount + taxAmount);
      final paidAmount = roundCurrency(
        request.paidAmount.clamp(0, totalAmount),
      );
      final status = paidAmount >= totalAmount ? 'completed' : 'partial';
      final invoiceNo = 'P-${DateTime.now().millisecondsSinceEpoch}';
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
      final returnAmount = roundCurrency(
        requestedQty * (unitPrice - unitDiscount),
      );

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

      final oldTotalAmount = ((purchaseRows.first['total_amount'] ?? 0) as num)
          .toDouble();
      final newTotalAmount = roundCurrency(
        (oldTotalAmount - returnAmount).clamp(0, double.infinity).toDouble(),
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
      final paidAmount = ((paidRows.first['paid_amount'] ?? 0) as num)
          .toDouble();
      final nextStatus = paidAmount + 0.000001 >= newTotalAmount
          ? 'completed'
          : 'partial';

      await txn.update(
        'purchases',
        {'total_amount': newTotalAmount, 'status': nextStatus},
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
        {'status': 'cancelled'},
        where: 'id = ?',
        whereArgs: [purchaseId],
      );
    });
  }

  String _toDbMethod(PaymentMethod method) {
    return method == PaymentMethod.cash ? 'cash' : 'vodafone_cash';
  }
}
