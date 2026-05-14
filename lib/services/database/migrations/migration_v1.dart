import 'package:sqflite/sqflite.dart';

class MigrationV1 {
  Future<void> up(Database db) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      );
    ''');

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        barcode TEXT UNIQUE,
        category_id INTEGER,
        unit_type TEXT NOT NULL CHECK(unit_type IN ('piece', 'weight')),
        sale_price REAL NOT NULL,
        sale_price_half_wholesale REAL NOT NULL DEFAULT 0,
        sale_price_wholesale REAL NOT NULL DEFAULT 0,
        purchase_price REAL NOT NULL,
        low_stock_threshold REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE SET NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        account_type TEXT NOT NULL CHECK(account_type IN ('customer', 'supplier', 'expense')),
        phone TEXT,
        address TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      );
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER,
        invoice_number TEXT NOT NULL UNIQUE,
        status TEXT NOT NULL DEFAULT 'completed' CHECK(status IN ('completed', 'partial', 'cancelled')),
        total_amount REAL NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE SET NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        discount_amount REAL NOT NULL DEFAULT 0,
        line_total REAL NOT NULL,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(sale_id) REFERENCES sales(id) ON DELETE CASCADE,
        FOREIGN KEY(product_id) REFERENCES products(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE purchases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL,
        invoice_number TEXT NOT NULL UNIQUE,
        status TEXT NOT NULL DEFAULT 'completed' CHECK(status IN ('completed', 'partial', 'cancelled')),
        total_amount REAL NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(account_id) REFERENCES accounts(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE purchase_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        discount_amount REAL NOT NULL DEFAULT 0,
        line_total REAL NOT NULL,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(purchase_id) REFERENCES purchases(id) ON DELETE CASCADE,
        FOREIGN KEY(product_id) REFERENCES products(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER,
        invoice_type TEXT CHECK(invoice_type IN ('sale', 'purchase', 'expense')),
        invoice_id INTEGER,
        payment_method TEXT NOT NULL CHECK(payment_method IN ('cash', 'vodafone_cash')),
        amount REAL NOT NULL,
        is_refund INTEGER NOT NULL DEFAULT 0,
        is_standalone INTEGER NOT NULL DEFAULT 0,
        reversal_for_id INTEGER,
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(account_id) REFERENCES accounts(id),
        FOREIGN KEY(reversal_for_id) REFERENCES payments(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE ledger_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL,
        source_type TEXT NOT NULL CHECK(source_type IN ('sale', 'purchase', 'payment', 'return', 'cancellation', 'expense')),
        source_id INTEGER,
        amount REAL NOT NULL,
        entry_kind TEXT NOT NULL CHECK(entry_kind IN ('debit', 'credit', 'reversal')),
        description TEXT,
        reversal_for_id INTEGER,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(account_id) REFERENCES accounts(id),
        FOREIGN KEY(reversal_for_id) REFERENCES ledger_transactions(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        invoice_type TEXT NOT NULL CHECK(invoice_type IN ('sale', 'purchase', 'return', 'cancellation')),
        invoice_id INTEGER,
        movement_type TEXT NOT NULL CHECK(movement_type IN ('in', 'out', 'reversal')),
        quantity REAL NOT NULL,
        unit_type TEXT NOT NULL CHECK(unit_type IN ('piece', 'weight')),
        reversal_for_id INTEGER,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(product_id) REFERENCES products(id),
        FOREIGN KEY(reversal_for_id) REFERENCES stock_movements(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE returns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_type TEXT NOT NULL CHECK(invoice_type IN ('sale', 'purchase')),
        invoice_id INTEGER NOT NULL,
        original_line_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        reason TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      );
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        payment_method TEXT NOT NULL CHECK(payment_method IN ('cash', 'vodafone_cash')),
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(account_id) REFERENCES accounts(id)
      );
    ''');

    await db.execute('CREATE INDEX idx_products_name ON products(name);');
    await db.execute('CREATE INDEX idx_products_barcode ON products(barcode);');
    await db.execute(
      'CREATE INDEX idx_stock_movements_product_id ON stock_movements(product_id);',
    );
    await db.execute(
      'CREATE INDEX idx_ledger_transactions_account_id ON ledger_transactions(account_id);',
    );
    await db.execute(
      'CREATE INDEX idx_payments_invoice ON payments(invoice_type, invoice_id);',
    );
    await db.execute(
      'CREATE INDEX idx_accounts_type ON accounts(account_type);',
    );
    await db.execute(
      'CREATE INDEX idx_expenses_account_created ON expenses(account_id, created_at);',
    );
  }
}
