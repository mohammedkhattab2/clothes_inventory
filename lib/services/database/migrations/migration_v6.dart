import 'package:sqflite/sqflite.dart';

class MigrationV6 {
  Future<void> up(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        actor_user_id INTEGER,
        target_user_id INTEGER,
        details TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      );
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_user_audit_logs_created_at ON user_audit_logs(created_at);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_user_audit_logs_actor_user_id ON user_audit_logs(actor_user_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_user_audit_logs_target_user_id ON user_audit_logs(target_user_id);',
    );
  }
}
