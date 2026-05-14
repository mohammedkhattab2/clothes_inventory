import 'package:sqflite/sqflite.dart';

class MigrationV3 {
  Future<void> up(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ocr_product_mappings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ocr_text TEXT NOT NULL,
        product_id INTEGER NOT NULL,
        usage_count INTEGER NOT NULL DEFAULT 1,
        last_used_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(product_id) REFERENCES products(id),
        UNIQUE(ocr_text, product_id)
      );
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ocr_product_mappings_text ON ocr_product_mappings(ocr_text);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ocr_product_mappings_usage ON ocr_product_mappings(ocr_text, usage_count DESC, last_used_at DESC);',
    );
  }
}
