import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:clothes_inventory/features/auth/domain/auth_user.dart';
import 'package:clothes_inventory/features/auth/domain/user_audit_log_entry.dart';
import 'package:clothes_inventory/services/database/app_database.dart';

class AuthRepository {
  AuthRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<void> ensureOwnerSeeded() async {
    final db = await _appDatabase.database;
    final countRows = await db.rawQuery('SELECT COUNT(*) AS c FROM users');
    final count = ((countRows.first['c'] ?? 0) as num).toInt();
    if (count > 0) {
      return;
    }

    final now = DateTime.now().toIso8601String();
    await db.insert('users', {
      'username': 'owner',
      'full_name': 'Owner',
      'pin_hash': _hashSecret('0000'),
      'password_hash': _hashSecret('123456'),
      'role': UserRole.owner.dbValue,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<AuthUser?> loginWithPassword({
    required String username,
    required String password,
  }) async {
    final row = await _findUserByUsername(username);
    if (row == null) return null;
    if (!_isRowActive(row)) return null;

    final storedHash = (row['password_hash'] as String?) ?? '';
    if (storedHash.isEmpty) return null;
    if (storedHash != _hashSecret(password)) return null;

    return _mapUser(row);
  }

  Future<AuthUser?> loginWithPin({
    required String username,
    required String pin,
  }) async {
    final row = await _findUserByUsername(username);
    if (row == null) return null;
    if (!_isRowActive(row)) return null;

    final storedHash = (row['pin_hash'] as String?) ?? '';
    if (storedHash.isEmpty) return null;
    if (storedHash != _hashSecret(pin)) return null;

    return _mapUser(row);
  }

  Future<List<AuthUser>> listUsers() async {
    final db = await _appDatabase.database;
    final rows = await db.query('users', orderBy: 'id ASC');
    return rows.map(_mapUser).toList(growable: false);
  }

  Future<int> createUser({
    required String username,
    required String fullName,
    required String pin,
    required String password,
    required UserRole role,
    bool isActive = true,
    int? actorUserId,
  }) async {
    final normalizedUsername = username.trim();
    final normalizedFullName = fullName.trim();

    if (normalizedUsername.isEmpty) {
      throw ArgumentError('Username is required.');
    }
    if (normalizedFullName.isEmpty) {
      throw ArgumentError('Full name is required.');
    }
    if (pin.trim().isEmpty) {
      throw ArgumentError('PIN is required.');
    }
    if (password.trim().isEmpty) {
      throw ArgumentError('Password is required.');
    }

    final existing = await _findUserByUsername(normalizedUsername);
    if (existing != null) {
      throw StateError('Username already exists.');
    }

    final db = await _appDatabase.database;
    final now = DateTime.now().toIso8601String();
    final insertedId = await db.insert('users', {
      'username': normalizedUsername,
      'full_name': normalizedFullName,
      'pin_hash': _hashSecret(pin),
      'password_hash': _hashSecret(password),
      'role': role.dbValue,
      'is_active': isActive ? 1 : 0,
      'created_at': now,
      'updated_at': now,
    });

    await _logAudit(
      action: 'create_user',
      actorUserId: actorUserId,
      targetUserId: insertedId,
      details: jsonEncode({
        'role': role.dbValue,
        'is_active': isActive ? 1 : 0,
      }),
    );

    return insertedId;
  }

  Future<void> setUserActive({
    required int userId,
    required bool isActive,
    int? actorUserId,
  }) async {
    final db = await _appDatabase.database;

    if (!isActive) {
      final rows = await db.query(
        'users',
        columns: ['role', 'is_active'],
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final row = rows.first;
        final isOwner = (row['role'] as String?) == UserRole.owner.dbValue;
        final wasActive = ((row['is_active'] as num?) ?? 0) == 1;
        if (isOwner && wasActive) {
          final ownerCountRows = await db.rawQuery(
            "SELECT COUNT(*) AS c FROM users WHERE role = ? AND is_active = 1",
            [UserRole.owner.dbValue],
          );
          final activeOwners = ((ownerCountRows.first['c'] ?? 0) as num)
              .toInt();
          if (activeOwners <= 1) {
            throw StateError('Cannot deactivate the last active owner.');
          }
        }
      }
    }

    final now = DateTime.now().toIso8601String();
    await db.update(
      'users',
      {'is_active': isActive ? 1 : 0, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [userId],
    );

    await _logAudit(
      action: 'set_user_active',
      actorUserId: actorUserId,
      targetUserId: userId,
      details: jsonEncode({'is_active': isActive ? 1 : 0}),
    );
  }

  Future<void> updateUserCredentials({
    required int userId,
    String? pin,
    String? password,
    int? actorUserId,
  }) async {
    final normalizedPin = (pin ?? '').trim();
    final normalizedPassword = (password ?? '').trim();
    if (normalizedPin.isEmpty && normalizedPassword.isEmpty) {
      throw ArgumentError('At least PIN or Password is required.');
    }

    final values = <String, Object?>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (normalizedPin.isNotEmpty) {
      values['pin_hash'] = _hashSecret(normalizedPin);
    }
    if (normalizedPassword.isNotEmpty) {
      values['password_hash'] = _hashSecret(normalizedPassword);
    }

    final db = await _appDatabase.database;
    await db.update('users', values, where: 'id = ?', whereArgs: [userId]);

    await _logAudit(
      action: 'update_credentials',
      actorUserId: actorUserId,
      targetUserId: userId,
      details: jsonEncode({
        'pin_updated': normalizedPin.isNotEmpty ? 1 : 0,
        'password_updated': normalizedPassword.isNotEmpty ? 1 : 0,
      }),
    );
  }

  Future<void> updateUserProfile({
    required int userId,
    required String fullName,
    required UserRole role,
    int? currentSessionUserId,
    int? actorUserId,
  }) async {
    final normalizedFullName = fullName.trim();
    if (normalizedFullName.isEmpty) {
      throw ArgumentError('Full name is required.');
    }

    final db = await _appDatabase.database;
    final rows = await db.query(
      'users',
      columns: ['role', 'is_active'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('User not found.');
    }

    final currentRole = userRoleFromDb(
      (rows.first['role'] as String?) ?? 'cashier',
    );
    final isActive = ((rows.first['is_active'] as num?) ?? 0) == 1;

    if (currentSessionUserId != null &&
        currentSessionUserId == userId &&
        role != currentRole) {
      throw StateError('Cannot change your role during active session.');
    }

    if (currentRole == UserRole.owner && role != UserRole.owner && isActive) {
      final ownerCountRows = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM users WHERE role = ? AND is_active = 1",
        [UserRole.owner.dbValue],
      );
      final activeOwners = ((ownerCountRows.first['c'] ?? 0) as num).toInt();
      if (activeOwners <= 1) {
        throw StateError('Cannot change role of the last active owner.');
      }
    }

    await db.update(
      'users',
      {
        'full_name': normalizedFullName,
        'role': role.dbValue,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [userId],
    );

    await _logAudit(
      action: 'update_user_profile',
      actorUserId: actorUserId,
      targetUserId: userId,
      details: jsonEncode({'role': role.dbValue}),
    );
  }

  Future<void> deleteUser({
    required int userId,
    int? actorUserId,
    int? currentSessionUserId,
  }) async {
    if (currentSessionUserId != null && currentSessionUserId == userId) {
      throw StateError('Cannot delete current session user.');
    }

    final db = await _appDatabase.database;
    final rows = await db.query(
      'users',
      columns: ['username', 'role', 'is_active'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('User not found.');
    }

    final username = (rows.first['username'] as String?) ?? '-';
    final role = userRoleFromDb((rows.first['role'] as String?) ?? 'cashier');
    final isActive = ((rows.first['is_active'] as num?) ?? 0) == 1;

    if (role == UserRole.owner && isActive) {
      final ownerCountRows = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM users WHERE role = ? AND is_active = 1",
        [UserRole.owner.dbValue],
      );
      final activeOwners = ((ownerCountRows.first['c'] ?? 0) as num).toInt();
      if (activeOwners <= 1) {
        throw StateError('Cannot delete the last active owner.');
      }
    }

    final linkedRows = await db.rawQuery(
      '''
      SELECT (
        (SELECT COUNT(*) FROM sales WHERE created_by_user_id = ?) +
        (SELECT COUNT(*) FROM purchases WHERE created_by_user_id = ?) +
        (SELECT COUNT(*) FROM payments WHERE created_by_user_id = ?) +
        (SELECT COUNT(*) FROM returns WHERE created_by_user_id = ?)
      ) AS c
      ''',
      [userId, userId, userId, userId],
    );
    final linkedCount = ((linkedRows.first['c'] ?? 0) as num).toInt();
    if (linkedCount > 0) {
      throw StateError(
        'Cannot delete user with linked invoices or transactions.',
      );
    }

    await db.delete('users', where: 'id = ?', whereArgs: [userId]);

    await _logAudit(
      action: 'delete_user',
      actorUserId: actorUserId,
      targetUserId: userId,
      details: jsonEncode({'username': username}),
    );
  }

  Future<List<UserAuditLogEntry>> listAuditLogs({int limit = 40}) async {
    final db = await _appDatabase.database;
    final rows = await db.rawQuery(
      '''
      SELECT
        l.id,
        l.action,
        l.actor_user_id,
        l.target_user_id,
        l.details,
        l.created_at,
        au.username AS actor_username,
        tu.username AS target_username
      FROM user_audit_logs l
      LEFT JOIN users au ON au.id = l.actor_user_id
      LEFT JOIN users tu ON tu.id = l.target_user_id
      ORDER BY datetime(l.created_at) DESC, l.id DESC
      LIMIT ?
      ''',
      [limit],
    );

    return rows
        .map(
          (row) => UserAuditLogEntry(
            id: (row['id'] as num).toInt(),
            action: (row['action'] as String?) ?? '-',
            actorUserId: (row['actor_user_id'] as num?)?.toInt(),
            actorUsername: row['actor_username'] as String?,
            targetUserId: (row['target_user_id'] as num?)?.toInt(),
            targetUsername: row['target_username'] as String?,
            details: row['details'] as String?,
            createdAt:
                DateTime.tryParse((row['created_at'] ?? '').toString()) ??
                DateTime.now(),
          ),
        )
        .toList(growable: false);
  }

  Future<Map<String, Object?>?> _findUserByUsername(String username) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      'users',
      where: 'LOWER(username) = LOWER(?)',
      whereArgs: [username.trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  AuthUser _mapUser(Map<String, Object?> row) {
    return AuthUser(
      id: (row['id'] as num).toInt(),
      username: (row['username'] as String?) ?? '',
      fullName:
          (row['full_name'] as String?) ?? (row['username'] as String?) ?? '',
      role: userRoleFromDb((row['role'] as String?) ?? 'cashier'),
      isActive: ((row['is_active'] as num?) ?? 0) == 1,
    );
  }

  bool _isRowActive(Map<String, Object?> row) {
    return ((row['is_active'] as num?) ?? 0) == 1;
  }

  String _hashSecret(String value) {
    return sha256.convert(utf8.encode(value)).toString();
  }

  Future<void> _logAudit({
    required String action,
    int? actorUserId,
    int? targetUserId,
    String? details,
  }) async {
    final db = await _appDatabase.database;
    await db.insert('user_audit_logs', {
      'action': action,
      'actor_user_id': actorUserId,
      'target_user_id': targetUserId,
      'details': details,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
