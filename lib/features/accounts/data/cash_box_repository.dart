import 'package:clothes_inventory/services/database/app_database.dart';
import 'package:sqflite/sqflite.dart';

class StandaloneCashMovement {
  const StandaloneCashMovement({
    required this.id,
    required this.amount,
    required this.paymentMethod,
    required this.notes,
    required this.createdAt,
  });

  final int id;
  final double amount;
  final String paymentMethod;
  final String? notes;
  final DateTime createdAt;

  bool get isInflow => amount >= 0;
  double get absoluteAmount => amount.abs();
}

class CashBoxRepository {
  const CashBoxRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<void> _ensureSettingsTable() async {
    final db = await _appDatabase.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<double> getOpeningBalanceOffset() async {
    await _ensureSettingsTable();
    final db = await _appDatabase.database;
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: const ['cash_box_opening_offset'],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return double.tryParse((rows.first['value'] as String?) ?? '') ?? 0;
  }

  Future<void> setOpeningBalanceOffset(double value) async {
    await _ensureSettingsTable();
    final db = await _appDatabase.database;
    await db.insert('app_settings', {
      'key': 'cash_box_opening_offset',
      'value': value.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<StandaloneCashMovement>> listStandaloneMovements({
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 200,
  }) async {
    final db = await _appDatabase.database;
    final where = <String>['is_standalone = 1', 'reversal_for_id IS NULL'];
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

    args.add(limit);

    final rows = await db.rawQuery('''
      SELECT
        id,
        amount,
        payment_method,
        notes,
        created_at
      FROM payments
      WHERE ${where.join(' AND ')}
      ORDER BY datetime(created_at) DESC, id DESC
      LIMIT ?
      ''', args);

    return rows
        .map(
          (row) => StandaloneCashMovement(
            id: (row['id'] as num).toInt(),
            amount: ((row['amount'] ?? 0) as num).toDouble(),
            paymentMethod: (row['payment_method'] as String?) ?? 'cash',
            notes: row['notes'] as String?,
            createdAt: DateTime.parse(row['created_at'] as String),
          ),
        )
        .toList(growable: false);
  }

  Future<double> sumStandaloneNet({DateTime? toDate}) async {
    final db = await _appDatabase.database;
    final where = <String>['is_standalone = 1', 'reversal_for_id IS NULL'];
    final args = <Object?>[];

    if (toDate != null) {
      final endExclusive = DateTime(
        toDate.year,
        toDate.month,
        toDate.day,
      ).add(const Duration(days: 1));
      where.add('datetime(created_at) < datetime(?)');
      args.add(endExclusive.toIso8601String());
    }

    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS net_amount
      FROM payments
      WHERE ${where.join(' AND ')}
      ''', args);

    if (rows.isEmpty) return 0;
    return ((rows.first['net_amount'] ?? 0) as num).toDouble();
  }

  Future<void> addStandaloneMovement({
    required bool isInflow,
    required double amount,
    required String paymentMethod,
    String? notes,
  }) async {
    final db = await _appDatabase.database;
    final absAmount = amount.abs();

    if (absAmount <= 0) {
      throw StateError('Enter a valid amount.'.trim());
    }

    await db.insert('payments', {
      'account_id': null,
      'invoice_type': null,
      'invoice_id': null,
      'payment_method': paymentMethod,
      'amount': isInflow ? absAmount : -absAmount,
      'is_refund': isInflow ? 0 : 1,
      'is_standalone': 1,
      'notes': notes?.trim().isEmpty ?? true ? null : notes!.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateStandaloneMovement({
    required int movementId,
    required bool isInflow,
    required double amount,
    required String paymentMethod,
    String? notes,
  }) async {
    final db = await _appDatabase.database;
    final absAmount = amount.abs();
    if (absAmount <= 0) {
      throw StateError('Enter a valid amount.');
    }

    final affected = await db.update(
      'payments',
      {
        'payment_method': paymentMethod,
        'amount': isInflow ? absAmount : -absAmount,
        'is_refund': isInflow ? 0 : 1,
        'notes': notes?.trim().isEmpty ?? true ? null : notes!.trim(),
      },
      where: 'id = ? AND is_standalone = 1 AND reversal_for_id IS NULL',
      whereArgs: [movementId],
    );

    if (affected == 0) {
      throw StateError('Cash movement not found.');
    }
  }

  Future<void> deleteStandaloneMovement(int movementId) async {
    final db = await _appDatabase.database;
    final affected = await db.delete(
      'payments',
      where: 'id = ? AND is_standalone = 1 AND reversal_for_id IS NULL',
      whereArgs: [movementId],
    );

    if (affected == 0) {
      throw StateError('Cash movement not found.');
    }
  }
}
