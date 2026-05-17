import 'dart:developer' as dev;

import 'package:sqflite/sqflite.dart';
import 'package:delta_erp/services/database/maintenance_coordinator.dart';

class DbTransactionRunner {
  const DbTransactionRunner(this._db, this._maintenanceCoordinator);

  final Database _db;
  final MaintenanceCoordinator _maintenanceCoordinator;

  Future<T> run<T>(Future<T> Function(Transaction txn) action) async {
    if (_maintenanceCoordinator.isMaintenanceMode) {
      throw StateError('Database write is blocked during maintenance mode.');
    }
    try {
      return await _db.transaction((txn) => action(txn));
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
