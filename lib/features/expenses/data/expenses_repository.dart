import 'package:clothes_inventory/features/accounts/data/accounts_repository.dart';
import 'package:clothes_inventory/services/database/app_database.dart';
import 'package:clothes_inventory/services/database/db_transaction_runner.dart';
import 'package:sqflite/sqflite.dart';

class ExpenseRecord {
  const ExpenseRecord({
    required this.id,
    required this.accountId,
    required this.accountName,
    required this.amount,
    required this.paymentMethod,
    required this.createdAt,
    this.notes,
  });

  final int id;
  final int accountId;
  final String accountName;
  final double amount;
  final String paymentMethod;
  final DateTime createdAt;
  final String? notes;
}

class ExpensesRepository {
  const ExpensesRepository(this._appDatabase, this._transactionRunner);

  final AppDatabase _appDatabase;
  final DbTransactionRunner _transactionRunner;

  static const List<String> _defaultExpenseAccounts = [
    'Salaries',
    'Rent',
    'Electricity',
    'Water',
    'Internet',
    'Miscellaneous',
  ];

  Future<void> ensureDefaultExpenseAccounts() async {
    final db = await _appDatabase.database;
    for (final name in _defaultExpenseAccounts) {
      final rows = await db.query(
        'accounts',
        columns: ['id'],
        where: 'name = ? AND account_type = ?',
        whereArgs: [name, 'expense'],
        limit: 1,
      );
      if (rows.isEmpty) {
        await db.insert('accounts', {
          'name': name,
          'account_type': 'expense',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    }
  }

  Future<List<AccountLookup>> listExpenseAccounts() async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      'accounts',
      columns: ['id', 'name', 'account_type'],
      where: 'account_type = ?',
      whereArgs: ['expense'],
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
        .toList(growable: false);
  }

  Future<List<ExpenseRecord>> listExpenses({
    DateTime? fromDate,
    DateTime? toDate,
    int? accountId,
    bool includeReversals = true,
    String? searchQuery,
    String sortBy = 'created_desc',
    int limit = 300,
    int offset = 0,
  }) async {
    final db = await _appDatabase.database;
    final where = <String>['1=1'];
    final args = <Object?>[];

    if (fromDate != null) {
      where.add('datetime(e.created_at) >= datetime(?)');
      args.add(fromDate.toIso8601String());
    }
    if (toDate != null) {
      final endExclusive = DateTime(
        toDate.year,
        toDate.month,
        toDate.day,
      ).add(const Duration(days: 1));
      where.add('datetime(e.created_at) < datetime(?)');
      args.add(endExclusive.toIso8601String());
    }
    if (accountId != null) {
      where.add('e.account_id = ?');
      args.add(accountId);
    }
    if (!includeReversals) {
      where.add('e.amount > 0');
      where.add(_notReversedExpenseWhereClause('e'));
    }

    final query = searchQuery?.trim().toLowerCase() ?? '';
    if (query.isNotEmpty) {
      where.add(
        "(LOWER(a.name) LIKE ? OR LOWER(COALESCE(e.notes, '')) LIKE ? OR LOWER(e.payment_method) LIKE ?)",
      );
      final like = '%$query%';
      args
        ..add(like)
        ..add(like)
        ..add(like);
    }

    final orderBy = switch (sortBy) {
      'created_asc' => 'datetime(e.created_at) ASC, e.id ASC',
      'amount_desc' => 'e.amount DESC, datetime(e.created_at) DESC, e.id DESC',
      'amount_asc' => 'e.amount ASC, datetime(e.created_at) DESC, e.id DESC',
      _ => 'datetime(e.created_at) DESC, e.id DESC',
    };

    args.add(limit);
    args.add(offset);

    final rows = await db.rawQuery('''
      SELECT
        e.id,
        e.account_id,
        a.name AS account_name,
        e.amount,
        e.payment_method,
        e.notes,
        e.created_at
      FROM expenses e
      JOIN accounts a ON a.id = e.account_id
      WHERE ${where.join(' AND ')}
      ORDER BY $orderBy
      LIMIT ? OFFSET ?
      ''', args);

    return rows
        .map(
          (row) => ExpenseRecord(
            id: (row['id'] as num).toInt(),
            accountId: (row['account_id'] as num).toInt(),
            accountName: (row['account_name'] as String?) ?? 'Expense',
            amount: ((row['amount'] ?? 0) as num).toDouble(),
            paymentMethod: (row['payment_method'] as String?) ?? 'cash',
            notes: row['notes'] as String?,
            createdAt: DateTime.parse(row['created_at'] as String),
          ),
        )
        .toList(growable: false);
  }

  Future<int> getExpensesCount({
    DateTime? fromDate,
    DateTime? toDate,
    int? accountId,
    bool includeReversals = true,
    String? searchQuery,
  }) async {
    final db = await _appDatabase.database;
    final where = <String>['1=1'];
    final args = <Object?>[];

    if (fromDate != null) {
      where.add('datetime(e.created_at) >= datetime(?)');
      args.add(fromDate.toIso8601String());
    }
    if (toDate != null) {
      final endExclusive = DateTime(
        toDate.year,
        toDate.month,
        toDate.day,
      ).add(const Duration(days: 1));
      where.add('datetime(e.created_at) < datetime(?)');
      args.add(endExclusive.toIso8601String());
    }
    if (accountId != null) {
      where.add('e.account_id = ?');
      args.add(accountId);
    }
    if (!includeReversals) {
      where.add('e.amount > 0');
      where.add(_notReversedExpenseWhereClause('e'));
    }

    final query = searchQuery?.trim().toLowerCase() ?? '';
    if (query.isNotEmpty) {
      where.add(
        "(LOWER(a.name) LIKE ? OR LOWER(COALESCE(e.notes, '')) LIKE ? OR LOWER(e.payment_method) LIKE ?)",
      );
      final like = '%$query%';
      args
        ..add(like)
        ..add(like)
        ..add(like);
    }

    final rows = await db.rawQuery('''
      SELECT COUNT(*) AS total
      FROM expenses e
      JOIN accounts a ON a.id = e.account_id
      WHERE ${where.join(' AND ')}
      ''', args);

    if (rows.isEmpty) return 0;
    return (rows.first['total'] as num).toInt();
  }

  Future<void> createExpense({
    required int accountId,
    required double amount,
    required String paymentMethod,
    String? notes,
  }) async {
    final normalizedAmount = amount.abs();
    if (normalizedAmount <= 0) {
      throw StateError('Enter a valid amount.');
    }

    await _transactionRunner.run((txn) async {
      final accountRows = await txn.query(
        'accounts',
        columns: ['id', 'name', 'account_type'],
        where: 'id = ?',
        whereArgs: [accountId],
        limit: 1,
      );

      if (accountRows.isEmpty) {
        throw StateError('Expense account not found.');
      }

      final accountType = accountRows.first['account_type'] as String;
      if (accountType != 'expense') {
        throw StateError('Selected account is not an expense account.');
      }

      await _insertExpenseWithEntries(
        txn,
        accountId: accountId,
        amount: normalizedAmount,
        paymentMethod: paymentMethod,
        notes: notes,
      );
    });
  }

  Future<void> cancelExpense({required int expenseId, String? reason}) async {
    await _transactionRunner.run((txn) async {
      await _reverseExpenseInTxn(txn, expenseId: expenseId, reason: reason);
    });
  }

  Future<void> updateExpense({
    required int expenseId,
    required int accountId,
    required double amount,
    required String paymentMethod,
    String? notes,
  }) async {
    final normalizedAmount = amount.abs();
    if (normalizedAmount <= 0) {
      throw StateError('Enter a valid amount.');
    }

    await _transactionRunner.run((txn) async {
      final original = await _loadExpenseForMutation(txn, expenseId);
      if (original == null) {
        throw StateError('Expense not found.');
      }

      if (original.amount <= 0) {
        throw StateError('Reversed expense cannot be edited.');
      }

      await _validateExpenseAccount(txn, accountId);

      await _reverseExpenseInTxn(txn, expenseId: expenseId, reason: 'updated');

      await _insertExpenseWithEntries(
        txn,
        accountId: accountId,
        amount: normalizedAmount,
        paymentMethod: paymentMethod,
        notes: notes,
      );
    });
  }

  Future<double> sumExpensePayments({
    DateTime? fromDate,
    DateTime? toDate,
    int? accountId,
  }) async {
    final db = await _appDatabase.database;
    final where = <String>['1=1'];
    final args = <Object?>[];

    if (fromDate != null) {
      where.add('datetime(created_at) >= datetime(?)');
      args.add(fromDate.toIso8601String());
    }
    if (toDate != null) {
      final endExclusive = DateTime(
        toDate.year,
        toDate.month,
        toDate.day,
      ).add(const Duration(days: 1));
      where.add('datetime(created_at) < datetime(?)');
      args.add(endExclusive.toIso8601String());
    }
    if (accountId != null) {
      where.add('account_id = ?');
      args.add(accountId);
    }

    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM expenses
      WHERE ${where.join(' AND ')}
      ''', args);

    return ((rows.first['total'] ?? 0) as num).toDouble();
  }

  Future<double> sumGrossExpensePayments({
    DateTime? fromDate,
    DateTime? toDate,
    int? accountId,
  }) async {
    final db = await _appDatabase.database;
    final where = <String>['amount > 0'];
    final args = <Object?>[];

    if (fromDate != null) {
      where.add('datetime(created_at) >= datetime(?)');
      args.add(fromDate.toIso8601String());
    }
    if (toDate != null) {
      final endExclusive = DateTime(
        toDate.year,
        toDate.month,
        toDate.day,
      ).add(const Duration(days: 1));
      where.add('datetime(created_at) < datetime(?)');
      args.add(endExclusive.toIso8601String());
    }
    if (accountId != null) {
      where.add('account_id = ?');
      args.add(accountId);
    }

    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM expenses
      WHERE ${where.join(' AND ')}
      ''', args);

    return ((rows.first['total'] ?? 0) as num).toDouble();
  }

  Future<void> _validateExpenseAccount(Transaction txn, int accountId) async {
    final accountRows = await txn.query(
      'accounts',
      columns: ['id', 'account_type'],
      where: 'id = ?',
      whereArgs: [accountId],
      limit: 1,
    );

    if (accountRows.isEmpty) {
      throw StateError('Expense account not found.');
    }

    final accountType = accountRows.first['account_type'] as String;
    if (accountType != 'expense') {
      throw StateError('Selected account is not an expense account.');
    }
  }

  Future<void> _insertExpenseWithEntries(
    Transaction txn, {
    required int accountId,
    required double amount,
    required String paymentMethod,
    String? notes,
  }) async {
    final expenseId = await txn.insert('expenses', {
      'account_id': accountId,
      'amount': amount,
      'payment_method': paymentMethod,
      'notes': notes?.trim().isEmpty ?? true ? null : notes!.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });

    await txn.insert('payments', {
      'account_id': accountId,
      'invoice_type': 'expense',
      'invoice_id': expenseId,
      'payment_method': paymentMethod,
      'amount': amount,
      'is_refund': amount < 0 ? 1 : 0,
      'is_standalone': 0,
      'notes': notes?.trim().isEmpty ?? true ? 'Expense payment' : notes,
      'created_at': DateTime.now().toIso8601String(),
    });

    await txn.insert('ledger_transactions', {
      'account_id': accountId,
      'source_type': 'expense',
      'source_id': expenseId,
      'amount': amount.abs(),
      'entry_kind': amount >= 0 ? 'debit' : 'credit',
      'description': notes?.trim().isEmpty ?? true
          ? 'Operating expense'
          : notes,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<_ExpenseMutationRow?> _loadExpenseForMutation(
    Transaction txn,
    int expenseId,
  ) async {
    final rows = await txn.query(
      'expenses',
      columns: ['id', 'account_id', 'amount', 'payment_method'],
      where: 'id = ?',
      whereArgs: [expenseId],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    return _ExpenseMutationRow(
      id: (rows.first['id'] as num).toInt(),
      accountId: (rows.first['account_id'] as num).toInt(),
      amount: ((rows.first['amount'] ?? 0) as num).toDouble(),
      paymentMethod: (rows.first['payment_method'] as String?) ?? 'cash',
    );
  }

  Future<int?> _findPrimaryPaymentId(Transaction txn, int expenseId) async {
    final rows = await txn.query(
      'payments',
      columns: ['id'],
      where: 'invoice_type = ? AND invoice_id = ? AND reversal_for_id IS NULL',
      whereArgs: ['expense', expenseId],
      orderBy: 'id ASC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (rows.first['id'] as num).toInt();
  }

  Future<int?> _findPrimaryExpenseLedgerId(
    Transaction txn,
    int expenseId,
  ) async {
    final rows = await txn.query(
      'ledger_transactions',
      columns: ['id'],
      where: 'source_type = ? AND source_id = ? AND reversal_for_id IS NULL',
      whereArgs: ['expense', expenseId],
      orderBy: 'id ASC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (rows.first['id'] as num).toInt();
  }

  Future<void> _reverseExpenseInTxn(
    Transaction txn, {
    required int expenseId,
    String? reason,
  }) async {
    final original = await _loadExpenseForMutation(txn, expenseId);
    if (original == null) {
      throw StateError('Expense not found.');
    }

    if (original.amount <= 0) {
      throw StateError('Expense is already reversed.');
    }

    final alreadyReversed = await _hasExpenseReversal(txn, expenseId);
    if (alreadyReversed) {
      throw StateError('Expense is already reversed.');
    }

    final cleanedReason = reason?.trim();
    final reversalNotes =
        'Reversal for expense #$expenseId${cleanedReason == null || cleanedReason.isEmpty ? '' : ': $cleanedReason'}';

    final reversalExpenseId = await txn.insert('expenses', {
      'account_id': original.accountId,
      'amount': -original.amount,
      'payment_method': original.paymentMethod,
      'notes': reversalNotes,
      'created_at': DateTime.now().toIso8601String(),
    });

    final originalPaymentId = await _findPrimaryPaymentId(txn, expenseId);
    await txn.insert('payments', {
      'account_id': original.accountId,
      'invoice_type': 'expense',
      'invoice_id': reversalExpenseId,
      'payment_method': original.paymentMethod,
      'amount': -original.amount,
      'is_refund': 1,
      'is_standalone': 0,
      'reversal_for_id': originalPaymentId,
      'notes': reversalNotes,
      'created_at': DateTime.now().toIso8601String(),
    });

    final originalLedgerId = await _findPrimaryExpenseLedgerId(txn, expenseId);
    await txn.insert('ledger_transactions', {
      'account_id': original.accountId,
      'source_type': 'expense',
      'source_id': reversalExpenseId,
      'amount': original.amount,
      'entry_kind': 'credit',
      'description': reversalNotes,
      'reversal_for_id': originalLedgerId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  String _notReversedExpenseWhereClause(String expenseAlias) =>
      '''
    NOT EXISTS (
      SELECT 1
      FROM payments p_orig
      JOIN payments p_rev ON p_rev.reversal_for_id = p_orig.id
      WHERE p_orig.invoice_type = 'expense'
        AND p_orig.invoice_id = $expenseAlias.id
        AND p_orig.reversal_for_id IS NULL
        AND p_rev.invoice_type = 'expense'
    )
  ''';

  Future<bool> _hasExpenseReversal(Transaction txn, int expenseId) async {
    final rows = await txn.rawQuery(
      '''
      SELECT EXISTS(
        SELECT 1
        FROM payments p_orig
        JOIN payments p_rev ON p_rev.reversal_for_id = p_orig.id
        WHERE p_orig.invoice_type = 'expense'
          AND p_orig.invoice_id = ?
          AND p_orig.reversal_for_id IS NULL
          AND p_rev.invoice_type = 'expense'
      ) AS has_reversal
    ''',
      <Object?>[expenseId],
    );

    if (rows.isEmpty) {
      return false;
    }

    final raw = rows.first['has_reversal'];
    return ((raw ?? 0) as num).toInt() == 1;
  }
}

class _ExpenseMutationRow {
  const _ExpenseMutationRow({
    required this.id,
    required this.accountId,
    required this.amount,
    required this.paymentMethod,
  });

  final int id;
  final int accountId;
  final double amount;
  final String paymentMethod;
}
