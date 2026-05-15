import 'package:sqflite/sqflite.dart';

/// Invoice numbers: `S000001` / `P000001` via [invoice_sequences].
class MigrationV8 {
  Future<void> up(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoice_sequences (
        doc_type TEXT NOT NULL PRIMARY KEY,
        next_value INTEGER NOT NULL CHECK (next_value >= 1)
      )
    ''');

    await db.insert(
      'invoice_sequences',
      {'doc_type': 'sale', 'next_value': 1},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await db.insert(
      'invoice_sequences',
      {'doc_type': 'purchase', 'next_value': 1},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
}
