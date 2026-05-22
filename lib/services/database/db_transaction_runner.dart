import 'dart:developer' as dev;

import 'package:sqflite/sqflite.dart';
import 'package:delta_erp/services/database/app_database.dart';
import 'package:delta_erp/services/database/maintenance_coordinator.dart';

class DbTransactionRunner {
  DbTransactionRunner(this._appDatabase, this._maintenanceCoordinator);

  final AppDatabase _appDatabase;
  final MaintenanceCoordinator _maintenanceCoordinator;

  Future<T> run<T>(Future<T> Function(Transaction txn) action) async {
    if (_maintenanceCoordinator.isMaintenanceMode) {
      throw StateError('Database write is blocked during maintenance mode.');
    }
    try {
      final db = await _appDatabase.database;
      return await db.transaction((txn) => action(txn));
    } catch (e, st) {
      if (e is StateError) {
        rethrow;
      }
      dev.log(
        'Database transaction failed',
        name: 'DbTransactionRunner',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}
