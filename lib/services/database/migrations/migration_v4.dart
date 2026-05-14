import 'package:sqflite/sqflite.dart';

class MigrationV4 {
  Future<void> up(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS supplier_stats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER NOT NULL UNIQUE,
        invoice_count INTEGER NOT NULL DEFAULT 0,
        avg_item_count REAL NOT NULL DEFAULT 0,
        price_stability_score REAL NOT NULL DEFAULT 1,
        last_invoice_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(supplier_id) REFERENCES accounts(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_price_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        supplier_id INTEGER,
        unit_price REAL NOT NULL,
        observed_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(product_id) REFERENCES products(id),
        FOREIGN KEY(supplier_id) REFERENCES accounts(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_correction_patterns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ocr_text TEXT NOT NULL,
        suggested_product_id INTEGER,
        selected_product_id INTEGER NOT NULL,
        correction_count INTEGER NOT NULL DEFAULT 1,
        last_corrected_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(suggested_product_id) REFERENCES products(id),
        FOREIGN KEY(selected_product_id) REFERENCES products(id),
        UNIQUE(ocr_text, suggested_product_id, selected_product_id)
      );
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_supplier_stats_supplier ON supplier_stats(supplier_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_product_price_history_product ON product_price_history(product_id, observed_at DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_product_price_history_supplier ON product_price_history(supplier_id, observed_at DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_user_correction_text ON user_correction_patterns(ocr_text, correction_count DESC, last_corrected_at DESC);',
    );
  }
}
