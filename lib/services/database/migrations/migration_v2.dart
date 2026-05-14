import 'package:sqflite/sqflite.dart';

class MigrationV2 {
  Future<void> up(Database db) async {
    await db.execute('ALTER TABLE accounts RENAME TO accounts_old');

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
      INSERT INTO accounts (id, name, account_type, phone, address, created_at)
      SELECT id, name, account_type, phone, address, created_at
      FROM accounts_old;
    ''');

    await db.execute('''
      CREATE TABLE sales_new (
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
      INSERT INTO sales_new (id, account_id, invoice_number, status, total_amount, notes, created_at)
      SELECT id, account_id, invoice_number, status, total_amount, notes, created_at
      FROM sales;
    ''');
    await db.execute('DROP TABLE sales');
    await db.execute('ALTER TABLE sales_new RENAME TO sales');

    await db.execute('''
      CREATE TABLE purchases_new (
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
      INSERT INTO purchases_new (id, account_id, invoice_number, status, total_amount, notes, created_at)
      SELECT id, account_id, invoice_number, status, total_amount, notes, created_at
      FROM purchases;
    ''');
    await db.execute('DROP TABLE purchases');
    await db.execute('ALTER TABLE purchases_new RENAME TO purchases');

    await db.execute('''
      CREATE TABLE payments_new (
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
        FOREIGN KEY(reversal_for_id) REFERENCES payments_new(id)
      );
    ''');
    await db.execute('''
      INSERT INTO payments_new (
        id, account_id, invoice_type, invoice_id, payment_method, amount,
        is_refund, is_standalone, reversal_for_id, notes, created_at
      )
      SELECT
        id, account_id, invoice_type, invoice_id, payment_method, amount,
        is_refund, is_standalone, reversal_for_id, notes, created_at
      FROM payments;
    ''');
    await db.execute('DROP TABLE payments');
    await db.execute('ALTER TABLE payments_new RENAME TO payments');

    await db.execute('''
      CREATE TABLE ledger_transactions_new (
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
        FOREIGN KEY(reversal_for_id) REFERENCES ledger_transactions_new(id)
      );
    ''');
    await db.execute('''
      INSERT INTO ledger_transactions_new (
        id, account_id, source_type, source_id, amount, entry_kind, description, reversal_for_id, created_at
      )
      SELECT
        id, account_id, source_type, source_id, amount, entry_kind, description, reversal_for_id, created_at
      FROM ledger_transactions;
    ''');
    await db.execute('DROP TABLE ledger_transactions');
    await db.execute(
      'ALTER TABLE ledger_transactions_new RENAME TO ledger_transactions',
    );

    await db.execute('''
      CREATE TABLE expenses_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        payment_method TEXT NOT NULL CHECK(payment_method IN ('cash', 'vodafone_cash')),
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(account_id) REFERENCES accounts(id)
      );
    ''');
    await db.execute('''
      INSERT INTO expenses_new (id, account_id, amount, payment_method, notes, created_at)
      SELECT id, account_id, amount, payment_method, notes, created_at
      FROM expenses;
    ''');
    await db.execute('DROP TABLE expenses');
    await db.execute('ALTER TABLE expenses_new RENAME TO expenses');

    await db.execute('DROP TABLE accounts_old');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        payment_method TEXT NOT NULL CHECK(payment_method IN ('cash', 'vodafone_cash')),
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(account_id) REFERENCES accounts(id)
      );
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_accounts_type ON accounts(account_type);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_expenses_account_created ON expenses(account_id, created_at);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ledger_transactions_account_id ON ledger_transactions(account_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payments_invoice ON payments(invoice_type, invoice_id);',
    );

    await db.execute('PRAGMA foreign_keys = ON');
  }
}
