import 'package:clothes_inventory/services/database/app_database.dart';

class AccountStatementTransaction {
  const AccountStatementTransaction({
    required this.id,
    required this.accountId,
    required this.createdAt,
    required this.type,
    required this.referenceId,
    required this.signedAmount,
    required this.runningBalance,
    this.paymentMethod,
    this.invoiceType,
    this.invoiceId,
    this.description,
  });

  final int id;
  final int accountId;
  final DateTime createdAt;
  final String type;
  final int? referenceId;
  final String? paymentMethod;
  final String? invoiceType;
  final int? invoiceId;
  final String? description;
  final double signedAmount;
  final double runningBalance;

  double get debit => signedAmount > 0 ? signedAmount : 0;
  double get credit => signedAmount < 0 ? signedAmount.abs() : 0;

  String get typeLabel {
    switch (type) {
      case 'sale':
        return 'Sale';
      case 'purchase':
        return 'Purchase';
      case 'payment':
        if (paymentMethod == 'vodafone_cash') {
          return 'Payment (Vodafone Cash)';
        }
        if (paymentMethod == 'visa') {
          return 'Payment (Visa)';
        }
        return 'Payment (Cash)';
      case 'return':
        return 'Return';
      case 'cancellation':
        return 'Cancellation';
      case 'expense':
        return 'Expense';
      default:
        return type;
    }
  }

  String get referenceLabel {
    if (type == 'payment') {
      if (invoiceType != null && invoiceId != null) {
        return 'Payment #${referenceId ?? '-'} ($invoiceType:$invoiceId)';
      }
      return 'Payment #${referenceId ?? '-'}';
    }
    if (referenceId != null) {
      return '$typeLabel #$referenceId';
    }
    return description ?? '-';
  }
}

class AccountStatementRepository {
  AccountStatementRepository(this._appDatabase);

  final AppDatabase _appDatabase;
  bool _indexReady = false;

  Future<void> _ensureIndexes() async {
    if (_indexReady) return;
    final db = await _appDatabase.database;
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ledger_account_created ON ledger_transactions(account_id, created_at, id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ledger_account_type_created ON ledger_transactions(account_id, source_type, created_at, id);',
    );
    _indexReady = true;
  }

  Future<List<AccountStatementTransaction>> getAccountTransactions({
    required int accountId,
    DateTime? fromDate,
    DateTime? toDate,
    String? type,
  }) async {
    await _ensureIndexes();
    final db = await _appDatabase.database;

    final queryFilter = _buildFilter(
      accountId: accountId,
      fromDate: fromDate,
      toDate: toDate,
      type: type,
    );
    final where = queryFilter.where;
    final args = queryFilter.args;

    final rows = await db.rawQuery('''
      WITH filtered AS (
        SELECT
          lt.id,
          lt.account_id,
          lt.source_type,
          lt.source_id,
          lt.entry_kind,
          lt.amount,
          lt.created_at,
          lt.description,
          a.account_type,
          p.payment_method,
          p.invoice_type,
          p.invoice_id,
          CASE
            WHEN a.account_type = 'customer' AND lt.entry_kind IN ('debit', 'reversal') THEN lt.amount
            WHEN a.account_type = 'customer' AND lt.entry_kind = 'credit' THEN -lt.amount
            WHEN a.account_type = 'supplier' AND lt.entry_kind IN ('debit', 'reversal') THEN -lt.amount
            WHEN a.account_type = 'supplier' AND lt.entry_kind = 'credit' THEN lt.amount
            WHEN a.account_type = 'expense' AND lt.entry_kind IN ('debit', 'reversal') THEN lt.amount
            WHEN a.account_type = 'expense' AND lt.entry_kind = 'credit' THEN -lt.amount
            ELSE 0
          END AS signed_amount
        FROM ledger_transactions lt
        JOIN accounts a ON a.id = lt.account_id
        LEFT JOIN payments p ON lt.source_type = 'payment' AND p.id = lt.source_id
        WHERE ${where.join(' AND ')}
      )
      SELECT
        id,
        account_id,
        source_type,
        source_id,
        payment_method,
        invoice_type,
        invoice_id,
        description,
        created_at,
        signed_amount,
        SUM(signed_amount) OVER (
          ORDER BY datetime(created_at) ASC, id ASC
          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS running_balance
      FROM filtered
      ORDER BY datetime(created_at) ASC, id ASC
      ''', args);

    return rows.map((row) {
      return AccountStatementTransaction(
        id: row['id'] as int,
        accountId: row['account_id'] as int,
        createdAt: DateTime.parse(row['created_at'] as String),
        type: row['source_type'] as String,
        referenceId: row['source_id'] as int?,
        paymentMethod: row['payment_method'] as String?,
        invoiceType: row['invoice_type'] as String?,
        invoiceId: row['invoice_id'] as int?,
        description: row['description'] as String?,
        signedAmount: ((row['signed_amount'] ?? 0) as num).toDouble(),
        runningBalance: ((row['running_balance'] ?? 0) as num).toDouble(),
      );
    }).toList();
  }

  Future<List<AccountStatementTransaction>> getAccountTransactionsPaginated({
    required int accountId,
    required int limit,
    required int offset,
    DateTime? fromDate,
    DateTime? toDate,
    String? type,
  }) async {
    await _ensureIndexes();
    final db = await _appDatabase.database;

    final openingBalance = await getOpeningBalance(
      accountId,
      offset,
      fromDate: fromDate,
      toDate: toDate,
      type: type,
    );

    final queryFilter = _buildFilter(
      accountId: accountId,
      fromDate: fromDate,
      toDate: toDate,
      type: type,
    );

    final rows = await db.rawQuery(
      '''
      WITH filtered AS (
        SELECT
          lt.id,
          lt.account_id,
          lt.source_type,
          lt.source_id,
          lt.entry_kind,
          lt.amount,
          lt.created_at,
          lt.description,
          a.account_type,
          p.payment_method,
          p.invoice_type,
          p.invoice_id,
          CASE
            WHEN a.account_type = 'customer' AND lt.entry_kind IN ('debit', 'reversal') THEN lt.amount
            WHEN a.account_type = 'customer' AND lt.entry_kind = 'credit' THEN -lt.amount
            WHEN a.account_type = 'supplier' AND lt.entry_kind IN ('debit', 'reversal') THEN -lt.amount
            WHEN a.account_type = 'supplier' AND lt.entry_kind = 'credit' THEN lt.amount
            WHEN a.account_type = 'expense' AND lt.entry_kind IN ('debit', 'reversal') THEN lt.amount
            WHEN a.account_type = 'expense' AND lt.entry_kind = 'credit' THEN -lt.amount
            ELSE 0
          END AS signed_amount
        FROM ledger_transactions lt
        JOIN accounts a ON a.id = lt.account_id
        LEFT JOIN payments p ON lt.source_type = 'payment' AND p.id = lt.source_id
        WHERE ${queryFilter.where.join(' AND ')}
      ),
      page_rows AS (
        SELECT *
        FROM filtered
        ORDER BY datetime(created_at) ASC, id ASC
        LIMIT ? OFFSET ?
      )
      SELECT
        id,
        account_id,
        source_type,
        source_id,
        payment_method,
        invoice_type,
        invoice_id,
        description,
        created_at,
        signed_amount,
        (? + SUM(signed_amount) OVER (
          ORDER BY datetime(created_at) ASC, id ASC
          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )) AS running_balance
      FROM page_rows
      ORDER BY datetime(created_at) ASC, id ASC
      ''',
      [...queryFilter.args, limit, offset, openingBalance],
    );

    return rows.map((row) {
      return AccountStatementTransaction(
        id: row['id'] as int,
        accountId: row['account_id'] as int,
        createdAt: DateTime.parse(row['created_at'] as String),
        type: row['source_type'] as String,
        referenceId: row['source_id'] as int?,
        paymentMethod: row['payment_method'] as String?,
        invoiceType: row['invoice_type'] as String?,
        invoiceId: row['invoice_id'] as int?,
        description: row['description'] as String?,
        signedAmount: ((row['signed_amount'] ?? 0) as num).toDouble(),
        runningBalance: ((row['running_balance'] ?? 0) as num).toDouble(),
      );
    }).toList();
  }

  Future<double> getOpeningBalance(
    int accountId,
    int offset, {
    DateTime? fromDate,
    DateTime? toDate,
    String? type,
  }) async {
    await _ensureIndexes();
    if (offset <= 0) return 0;

    final db = await _appDatabase.database;
    final queryFilter = _buildFilter(
      accountId: accountId,
      fromDate: fromDate,
      toDate: toDate,
      type: type,
    );

    final rows = await db.rawQuery(
      '''
      WITH filtered AS (
        SELECT
          CASE
            WHEN a.account_type = 'customer' AND lt.entry_kind IN ('debit', 'reversal') THEN lt.amount
            WHEN a.account_type = 'customer' AND lt.entry_kind = 'credit' THEN -lt.amount
            WHEN a.account_type = 'supplier' AND lt.entry_kind IN ('debit', 'reversal') THEN -lt.amount
            WHEN a.account_type = 'supplier' AND lt.entry_kind = 'credit' THEN lt.amount
            WHEN a.account_type = 'expense' AND lt.entry_kind IN ('debit', 'reversal') THEN lt.amount
            WHEN a.account_type = 'expense' AND lt.entry_kind = 'credit' THEN -lt.amount
            ELSE 0
          END AS signed_amount,
          lt.created_at,
          lt.id
        FROM ledger_transactions lt
        JOIN accounts a ON a.id = lt.account_id
        WHERE ${queryFilter.where.join(' AND ')}
      )
      SELECT COALESCE(SUM(signed_amount), 0) AS opening_balance
      FROM (
        SELECT signed_amount
        FROM filtered
        ORDER BY datetime(created_at) ASC, id ASC
        LIMIT ? OFFSET 0
      )
      ''',
      [...queryFilter.args, offset],
    );

    if (rows.isEmpty) return 0;
    return ((rows.first['opening_balance'] ?? 0) as num).toDouble();
  }

  Future<int> getAccountTransactionsCount({
    required int accountId,
    DateTime? fromDate,
    DateTime? toDate,
    String? type,
  }) async {
    await _ensureIndexes();
    final db = await _appDatabase.database;
    final queryFilter = _buildFilter(
      accountId: accountId,
      fromDate: fromDate,
      toDate: toDate,
      type: type,
    );

    final rows = await db.rawQuery('''
      SELECT COUNT(*) AS total
      FROM ledger_transactions lt
      WHERE ${queryFilter.where.join(' AND ')}
      ''', queryFilter.args);

    if (rows.isEmpty) return 0;
    return (rows.first['total'] as num).toInt();
  }

  Future<double> getAccountRunningBalance(int accountId) async {
    await _ensureIndexes();
    final db = await _appDatabase.database;

    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(
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
      FROM ledger_transactions lt
      JOIN accounts a ON a.id = lt.account_id
      WHERE lt.account_id = ?
      ''',
      [accountId],
    );

    if (rows.isEmpty) return 0;
    return ((rows.first['balance'] ?? 0) as num).toDouble();
  }

  _QueryFilter _buildFilter({
    required int accountId,
    DateTime? fromDate,
    DateTime? toDate,
    String? type,
  }) {
    final where = <String>['lt.account_id = ?'];
    final args = <Object?>[accountId];

    if (fromDate != null) {
      where.add('datetime(lt.created_at) >= datetime(?)');
      args.add(fromDate.toIso8601String());
    }
    if (toDate != null) {
      final endExclusive = DateTime(
        toDate.year,
        toDate.month,
        toDate.day,
      ).add(const Duration(days: 1));
      where.add('datetime(lt.created_at) < datetime(?)');
      args.add(endExclusive.toIso8601String());
    }
    if (type != null && type.isNotEmpty && type != 'all') {
      where.add('lt.source_type = ?');
      args.add(type);
    }

    return _QueryFilter(where: where, args: args);
  }
}

class _QueryFilter {
  const _QueryFilter({required this.where, required this.args});

  final List<String> where;
  final List<Object?> args;
}
