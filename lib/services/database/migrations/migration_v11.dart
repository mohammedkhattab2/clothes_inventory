import 'package:sqflite/sqflite.dart';

/// Tracks who last changed an invoice (returns, amendments, settlement payments, cancel).
class MigrationV11 {
  Future<void> up(Database db) async {
    await db.execute(
      'ALTER TABLE sales ADD COLUMN last_modified_by_user_id INTEGER',
    );
    await db.execute(
      'ALTER TABLE purchases ADD COLUMN last_modified_by_user_id INTEGER',
    );
  }
}
