import 'package:clothes_inventory/services/database/app_database.dart';
import 'package:clothes_inventory/services/database/db_transaction_runner.dart';

class AccountSummary {
  const AccountSummary({
    required this.id,
    required this.name,
    required this.accountType,
    required this.balance,
  });

  final int id;
  final String name;
  final String accountType;
  final double balance;
}

class AccountLookup {
  const AccountLookup({
    required this.id,
    required this.name,
    required this.accountType,
  });

  final int id;
  final String name;
  final String accountType;
}

class SettlementInvoiceOption {
  const SettlementInvoiceOption({
    required this.id,
    required this.invoiceType,
    required this.invoiceNumber,
    required this.outstanding,
    required this.createdAt,
  });

  final int id;
  final String invoiceType;
  final String invoiceNumber;
  final double outstanding;
  final DateTime createdAt;
}

class AccountsRepository {
  const AccountsRepository(this._appDatabase, this._transactionRunner);

  final AppDatabase _appDatabase;
  final DbTransactionRunner _transactionRunner;
  static const double _epsilon = 0.000001;

  Future<List<AccountLookup>> listAllAccounts() async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      'accounts',
      columns: ['id', 'name', 'account_type'],
      orderBy: 'name ASC',
    );

    return rows
        .map(
          (row) => AccountLookup(
            id: row['id'] as int,
            name: row['name'] as String,
            accountType: row['account_type'] as String,
          ),
        )
        .toList();
  }

  Future<List<AccountLookup>> listByType(String accountType) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      'accounts',
      columns: ['id', 'name', 'account_type'],
      where: 'account_type = ?',
      whereArgs: [accountType],
      orderBy: 'name ASC',
    );

    return rows
        .map(
          (row) => AccountLookup(
            id: row['id'] as int,
            name: row['name'] as String,
            accountType: row['account_type'] as String,
          ),
        )
        .toList();
  }

  Future<int> createAccount({
    required String name,
    required String accountType,
    String? phone,
    String? address,
  }) async {
    final db = await _appDatabase.database;
    return db.insert('accounts', {
      'name': name.trim(),
      'account_type': accountType,
      'phone': phone,
      'address': address,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<AccountSummary>> getAccountSummaries() async {
    final db = await _appDatabase.database;

    final rows = await db.rawQuery('''
      SELECT
        a.id,
        a.name,
        a.account_type,
        COALESCE(SUM(
          CASE
            WHEN a.account_type = 'customer' AND lt.entry_kind IN ('debit', 'reversal') THEN lt.amount
            WHEN a.account_type = 'customer' AND lt.entry_kind = 'credit' THEN -lt.amount
            WHEN a.account_type = 'supplier' AND lt.entry_kind IN ('debit', 'reversal') THEN -lt.amount
            WHEN a.account_type = 'supplier' AND lt.entry_kind = 'credit' THEN lt.amount
            WHEN a.account_type = 'expense' AND lt.entry_kind IN ('debit', 'reversal') THEN lt.amount
            WHEN a.account_type = 'expense' AND lt.entry_kind = 'credit' THEN -lt.amount
            ELSE 0
          END
        ), 0) AS balance
      FROM accounts a
      LEFT JOIN ledger_transactions lt ON lt.account_id = a.id
      GROUP BY a.id, a.name, a.account_type
      ORDER BY a.name ASC
    ''');

    return rows
        .map(
          (row) => AccountSummary(
            id: row['id'] as int,
            name: row['name'] as String,
            accountType: row['account_type'] as String,
            balance: ((row['balance'] ?? 0) as num).toDouble(),
          ),
        )
        .toList();
  }

  Future<List<AccountSummary>> getAccountSummariesWithTransactionsOnly() async {
    final db = await _appDatabase.database;

    final rows = await db.rawQuery('''
      SELECT
        a.id,
        a.name,
        a.account_type,
        COALESCE(SUM(
          CASE
            WHEN a.account_type = 'customer' AND lt.entry_kind IN ('debit', 'reversal') THEN lt.amount
            WHEN a.account_type = 'customer' AND lt.entry_kind = 'credit' THEN -lt.amount
            WHEN a.account_type = 'supplier' AND lt.entry_kind IN ('debit', 'reversal') THEN -lt.amount
            WHEN a.account_type = 'supplier' AND lt.entry_kind = 'credit' THEN lt.amount
            WHEN a.account_type = 'expense' AND lt.entry_kind IN ('debit', 'reversal') THEN lt.amount
            WHEN a.account_type = 'expense' AND lt.entry_kind = 'credit' THEN -lt.amount
            ELSE 0
          END
        ), 0) AS balance
      FROM accounts a
      JOIN ledger_transactions lt ON lt.account_id = a.id
      GROUP BY a.id, a.name, a.account_type
      ORDER BY a.name ASC
    ''');

    return rows
        .map(
          (row) => AccountSummary(
            id: row['id'] as int,
            name: row['name'] as String,
            accountType: row['account_type'] as String,
            balance: ((row['balance'] ?? 0) as num).toDouble(),
          ),
        )
        .toList();
  }

  Future<double> getAccountBalance(int accountId) async {
    final db = await _appDatabase.database;

    final rows = await db.rawQuery(
      '''
      SELECT
        a.account_type,
        COALESCE(SUM(
          CASE
            WHEN a.account_type = 'customer' AND lt.entry_kind IN ('debit', 'reversal') THEN lt.amount
            WHEN a.account_type = 'customer' AND lt.entry_kind = 'credit' THEN -lt.amount
            WHEN a.account_type = 'supplier' AND lt.entry_kind IN ('debit', 'reversal') THEN -lt.amount
            WHEN a.account_type = 'supplier' AND lt.entry_kind = 'credit' THEN lt.amount
            WHEN a.account_type = 'expense' AND lt.entry_kind IN ('debit', 'reversal') THEN lt.amount
            WHEN a.account_type = 'expense' AND lt.entry_kind = 'credit' THEN -lt.amount
            ELSE 0
          END
        ), 0) AS balance
      FROM accounts a
      LEFT JOIN ledger_transactions lt ON lt.account_id = a.id
      WHERE a.id = ?
      GROUP BY a.account_type
    ''',
      [accountId],
    );

    if (rows.isEmpty) return 0;
    return ((rows.first['balance'] ?? 0) as num).toDouble();
  }

  Future<List<SettlementInvoiceOption>> listOutstandingInvoices(
    int accountId,
  ) async {
    final db = await _appDatabase.database;

    final accountRows = await db.query(
      'accounts',
      columns: ['account_type'],
      where: 'id = ?',
      whereArgs: [accountId],
      limit: 1,
    );
    if (accountRows.isEmpty) {
      return const <SettlementInvoiceOption>[];
    }

    final accountType = accountRows.first['account_type'] as String;
    if (accountType == 'customer') {
      final rows = await db.rawQuery(
        '''
        SELECT
          s.id,
          s.invoice_number,
          s.created_at,
          MAX(
            0,
            s.total_amount - COALESCE((
              SELECT SUM(pay.amount)
              FROM payments pay
              WHERE pay.invoice_type = 'sale'
                AND pay.invoice_id = s.id
                AND pay.reversal_for_id IS NULL
            ), 0)
          ) AS outstanding
        FROM sales s
        WHERE s.account_id = ?
          AND s.status != 'cancelled'
          AND s.status != 'pending'
        ORDER BY datetime(s.created_at) DESC, s.id DESC
      ''',
        <Object?>[accountId],
      );

      return rows
          .map(
            (row) => SettlementInvoiceOption(
              id: (row['id'] as num).toInt(),
              invoiceType: 'sale',
              invoiceNumber:
                  (row['invoice_number'] as String?) ??
                  'S-${(row['id'] as num).toInt()}',
              outstanding: ((row['outstanding'] ?? 0) as num).toDouble(),
              createdAt: DateTime.parse(row['created_at'] as String),
            ),
          )
          .where((row) => row.outstanding > _epsilon)
          .toList(growable: false);
    }

    if (accountType == 'supplier') {
      final rows = await db.rawQuery(
        '''
        SELECT
          p.id,
          p.invoice_number,
          p.created_at,
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
                JOIN ledger_transactions ltr
                  ON ltr.source_type = 'return'
                 AND ltr.source_id = r.id
                WHERE r.invoice_type = 'purchase'
                  AND r.invoice_id = p.id
                  AND ltr.entry_kind = 'debit'
                  AND ltr.reversal_for_id IS NULL
              ), 0)
              -
              COALESCE((
                SELECT SUM(pay.amount)
                FROM payments pay
                WHERE pay.invoice_type = 'purchase'
                  AND pay.invoice_id = p.id
                  AND pay.reversal_for_id IS NULL
              ), 0)
            )
          ) AS outstanding
        FROM purchases p
        WHERE p.account_id = ?
          AND p.status != 'cancelled'
        ORDER BY datetime(p.created_at) DESC, p.id DESC
      ''',
        <Object?>[accountId],
      );

      return rows
          .map(
            (row) => SettlementInvoiceOption(
              id: (row['id'] as num).toInt(),
              invoiceType: 'purchase',
              invoiceNumber:
                  (row['invoice_number'] as String?) ??
                  'P-${(row['id'] as num).toInt()}',
              outstanding: ((row['outstanding'] ?? 0) as num).toDouble(),
              createdAt: DateTime.parse(row['created_at'] as String),
            ),
          )
          .where((row) => row.outstanding > _epsilon)
          .toList(growable: false);
    }

    return const <SettlementInvoiceOption>[];
  }

  Future<void> createStandalonePayment({
    required int accountId,
    required double amount,
    required String paymentMethod,
    int? targetInvoiceId,
    String? notes,
  }) async {
    await _appDatabase.database;

    await _transactionRunner.run((txn) async {
      final accountRows = await txn.query(
        'accounts',
        columns: ['account_type'],
        where: 'id = ?',
        whereArgs: [accountId],
        limit: 1,
      );
      if (accountRows.isEmpty) {
        throw StateError('Account not found.');
      }

      final accountType = accountRows.first['account_type'] as String;
      final absAmount = amount.abs();
      final isPositive = amount >= 0;
      final nowIso = DateTime.now().toIso8601String();
      final description = notes ?? 'Standalone payment';

      String entryKind;
      late final double cashAmount;
      if (accountType == 'customer') {
        entryKind = isPositive ? 'credit' : 'debit';
        cashAmount = amount;
      } else if (accountType == 'supplier') {
        entryKind = isPositive ? 'debit' : 'credit';
        cashAmount = isPositive ? -absAmount : absAmount;
      } else {
        throw StateError(
          'Standalone payments are not supported for expense accounts.',
        );
      }

      var remainingToAllocate = isPositive ? absAmount : 0.0;

      if (remainingToAllocate > _epsilon && accountType == 'customer') {
        final outstandingInvoices = targetInvoiceId == null
            ? await _loadCustomerOutstandingInvoices(txn, accountId: accountId)
            : await _loadTargetCustomerOutstandingInvoice(
                txn,
                accountId: accountId,
                invoiceId: targetInvoiceId,
              );
        for (final invoice in outstandingInvoices) {
          if (remainingToAllocate <= _epsilon) {
            break;
          }

          final allocated = remainingToAllocate < invoice.outstanding
              ? remainingToAllocate
              : invoice.outstanding;
          if (allocated <= _epsilon) {
            continue;
          }

          if (targetInvoiceId != null &&
              remainingToAllocate > invoice.outstanding + _epsilon) {
            throw StateError(
              'Amount cannot exceed selected invoice outstanding.',
            );
          }

          final paymentId = await _insertPaymentRow(
            txn,
            accountId: accountId,
            invoiceType: 'sale',
            invoiceId: invoice.id,
            paymentMethod: paymentMethod,
            amount: allocated,
            notes: description,
            createdAtIso: nowIso,
          );

          await _insertSettlementLedger(
            txn,
            accountId: accountId,
            paymentId: paymentId,
            amount: allocated,
            entryKind: entryKind,
            description: description,
            createdAtIso: nowIso,
          );

          remainingToAllocate -= allocated;
          await _refreshSaleInvoiceStatus(txn, saleId: invoice.id);
        }
      }

      if (remainingToAllocate > _epsilon && accountType == 'supplier') {
        final outstandingInvoices = targetInvoiceId == null
            ? await _loadSupplierOutstandingInvoices(txn, accountId: accountId)
            : await _loadTargetSupplierOutstandingInvoice(
                txn,
                accountId: accountId,
                invoiceId: targetInvoiceId,
              );
        for (final invoice in outstandingInvoices) {
          if (remainingToAllocate <= _epsilon) {
            break;
          }

          final allocated = remainingToAllocate < invoice.outstanding
              ? remainingToAllocate
              : invoice.outstanding;
          if (allocated <= _epsilon) {
            continue;
          }

          if (targetInvoiceId != null &&
              remainingToAllocate > invoice.outstanding + _epsilon) {
            throw StateError(
              'Amount cannot exceed selected invoice outstanding.',
            );
          }

          final paymentId = await _insertPaymentRow(
            txn,
            accountId: accountId,
            invoiceType: 'purchase',
            invoiceId: invoice.id,
            paymentMethod: paymentMethod,
            amount: allocated,
            notes: description,
            createdAtIso: nowIso,
          );

          await _insertSettlementLedger(
            txn,
            accountId: accountId,
            paymentId: paymentId,
            amount: allocated,
            entryKind: entryKind,
            description: description,
            createdAtIso: nowIso,
          );

          remainingToAllocate -= allocated;
          await _refreshPurchaseInvoiceStatus(txn, purchaseId: invoice.id);
        }
      }

      if (!isPositive || remainingToAllocate > _epsilon) {
        final residualAbsAmount = isPositive ? remainingToAllocate : absAmount;
        final residualCashAmount = amount < 0
            ? cashAmount
            : (cashAmount >= 0 ? residualAbsAmount : -residualAbsAmount);

        final paymentId = await _insertPaymentRow(
          txn,
          accountId: accountId,
          invoiceType: null,
          invoiceId: null,
          paymentMethod: paymentMethod,
          amount: residualCashAmount,
          notes: description,
          createdAtIso: nowIso,
        );

        await _insertSettlementLedger(
          txn,
          accountId: accountId,
          paymentId: paymentId,
          amount: residualAbsAmount,
          entryKind: entryKind,
          description: description,
          createdAtIso: nowIso,
        );
      }
    });
  }

  Future<int> _insertPaymentRow(
    dynamic txn, {
    required int accountId,
    required String? invoiceType,
    required int? invoiceId,
    required String paymentMethod,
    required double amount,
    required String notes,
    required String createdAtIso,
  }) {
    return txn.insert('payments', {
      'account_id': accountId,
      'invoice_type': invoiceType,
      'invoice_id': invoiceId,
      'payment_method': paymentMethod,
      'amount': amount,
      'is_refund': amount < 0 ? 1 : 0,
      // Account settlements affect operating cash flow, not owner financing.
      'is_standalone': 0,
      'notes': notes,
      'created_at': createdAtIso,
    });
  }

  Future<void> _insertSettlementLedger(
    dynamic txn, {
    required int accountId,
    required int paymentId,
    required double amount,
    required String entryKind,
    required String description,
    required String createdAtIso,
  }) {
    return txn.insert('ledger_transactions', {
      'account_id': accountId,
      'source_type': 'payment',
      'source_id': paymentId,
      'amount': amount,
      'entry_kind': entryKind,
      'description': description,
      'created_at': createdAtIso,
    });
  }

  Future<List<_OutstandingInvoice>> _loadCustomerOutstandingInvoices(
    dynamic txn, {
    required int accountId,
  }) async {
    final List<Map<String, Object?>> rows = List<Map<String, Object?>>.from(
      await txn.rawQuery(
        '''
      SELECT
        s.id,
        MAX(
          0,
          s.total_amount - COALESCE((
            SELECT SUM(pay.amount)
            FROM payments pay
            WHERE pay.invoice_type = 'sale'
              AND pay.invoice_id = s.id
              AND pay.reversal_for_id IS NULL
          ), 0)
        ) AS outstanding
      FROM sales s
      WHERE s.account_id = ?
        AND s.status != 'cancelled'
        AND s.status != 'pending'
      ORDER BY datetime(s.created_at) DESC, s.id DESC
    ''',
        <Object?>[accountId],
      ),
    );

    return rows
        .map<_OutstandingInvoice>(
          (row) => _OutstandingInvoice(
            id: (row['id'] as num).toInt(),
            outstanding: ((row['outstanding'] ?? 0) as num).toDouble(),
          ),
        )
        .where((invoice) => invoice.outstanding > _epsilon)
        .toList(growable: false);
  }

  Future<List<_OutstandingInvoice>> _loadSupplierOutstandingInvoices(
    dynamic txn, {
    required int accountId,
  }) async {
    final List<Map<String, Object?>> rows = List<Map<String, Object?>>.from(
      await txn.rawQuery(
        '''
      SELECT
        p.id,
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
              JOIN ledger_transactions ltr
                ON ltr.source_type = 'return'
               AND ltr.source_id = r.id
              WHERE r.invoice_type = 'purchase'
                AND r.invoice_id = p.id
                AND ltr.entry_kind = 'debit'
                AND ltr.reversal_for_id IS NULL
            ), 0)
            -
            COALESCE((
              SELECT SUM(pay.amount)
              FROM payments pay
              WHERE pay.invoice_type = 'purchase'
                AND pay.invoice_id = p.id
                AND pay.reversal_for_id IS NULL
            ), 0)
          )
        ) AS outstanding
      FROM purchases p
      WHERE p.account_id = ?
        AND p.status != 'cancelled'
      ORDER BY datetime(p.created_at) DESC, p.id DESC
    ''',
        <Object?>[accountId],
      ),
    );

    return rows
        .map<_OutstandingInvoice>(
          (row) => _OutstandingInvoice(
            id: (row['id'] as num).toInt(),
            outstanding: ((row['outstanding'] ?? 0) as num).toDouble(),
          ),
        )
        .where((invoice) => invoice.outstanding > _epsilon)
        .toList(growable: false);
  }

  Future<List<_OutstandingInvoice>> _loadTargetCustomerOutstandingInvoice(
    dynamic txn, {
    required int accountId,
    required int invoiceId,
  }) async {
    final all = await _loadCustomerOutstandingInvoices(
      txn,
      accountId: accountId,
    );
    for (final invoice in all) {
      if (invoice.id == invoiceId) {
        return <_OutstandingInvoice>[invoice];
      }
    }
    return const <_OutstandingInvoice>[];
  }

  Future<List<_OutstandingInvoice>> _loadTargetSupplierOutstandingInvoice(
    dynamic txn, {
    required int accountId,
    required int invoiceId,
  }) async {
    final all = await _loadSupplierOutstandingInvoices(
      txn,
      accountId: accountId,
    );
    for (final invoice in all) {
      if (invoice.id == invoiceId) {
        return <_OutstandingInvoice>[invoice];
      }
    }
    return const <_OutstandingInvoice>[];
  }

  Future<void> _refreshSaleInvoiceStatus(
    dynamic txn, {
    required int saleId,
  }) async {
    final rows = await txn.rawQuery(
      '''
      SELECT
        s.total_amount,
        COALESCE((
          SELECT SUM(pay.amount)
          FROM payments pay
          WHERE pay.invoice_type = 'sale'
            AND pay.invoice_id = s.id
            AND pay.reversal_for_id IS NULL
        ), 0) AS paid_amount
      FROM sales s
      WHERE s.id = ?
      LIMIT 1
    ''',
      <Object?>[saleId],
    );

    if (rows.isEmpty) {
      return;
    }

    final total = ((rows.first['total_amount'] ?? 0) as num).toDouble();
    final paid = ((rows.first['paid_amount'] ?? 0) as num).toDouble();
    final nextStatus = paid + _epsilon >= total ? 'completed' : 'partial';

    await txn.update(
      'sales',
      <String, Object?>{'status': nextStatus},
      where: 'id = ? AND status != ? AND status != ?',
      whereArgs: <Object?>[saleId, 'cancelled', 'pending'],
    );
  }

  Future<void> _refreshPurchaseInvoiceStatus(
    dynamic txn, {
    required int purchaseId,
  }) async {
    final rows = await txn.rawQuery(
      '''
      SELECT
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
              JOIN ledger_transactions ltr
                ON ltr.source_type = 'return'
               AND ltr.source_id = r.id
              WHERE r.invoice_type = 'purchase'
                AND r.invoice_id = p.id
                AND ltr.entry_kind = 'debit'
                AND ltr.reversal_for_id IS NULL
            ), 0)
          )
        ) AS total_amount,
        COALESCE((
          SELECT SUM(pay.amount)
          FROM payments pay
          WHERE pay.invoice_type = 'purchase'
            AND pay.invoice_id = p.id
            AND pay.reversal_for_id IS NULL
        ), 0) AS paid_amount
      FROM purchases p
      WHERE p.id = ?
      LIMIT 1
    ''',
      <Object?>[purchaseId],
    );

    if (rows.isEmpty) {
      return;
    }

    final total = ((rows.first['total_amount'] ?? 0) as num).toDouble();
    final paid = ((rows.first['paid_amount'] ?? 0) as num).toDouble();
    final nextStatus = paid + _epsilon >= total ? 'completed' : 'partial';

    await txn.update(
      'purchases',
      <String, Object?>{'status': nextStatus},
      where: 'id = ? AND status != ?',
      whereArgs: <Object?>[purchaseId, 'cancelled'],
    );
  }
}

class _OutstandingInvoice {
  const _OutstandingInvoice({required this.id, required this.outstanding});

  final int id;
  final double outstanding;
}
