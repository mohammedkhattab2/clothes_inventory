import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:clothes_inventory/features/backup/domain/backup_models.dart';

class BackupPreferencesStore {
  static const String _lastBackupJsonKey = 'backup.last_backup_json';
  static const String _autoEnabledKey = 'backup.auto_enabled';
  static const String _thresholdMinutesKey = 'backup.threshold_minutes';
  static const String _retentionCountKey = 'backup.retention_count';
  static const String _backupDirectoryKey = 'backup.directory';
  static const String _pendingRestoreKey = 'backup.pending_restore';
  static const String _networkModeKey = 'backup.is_network_mode';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<void> saveLastBackup(BackupSummary summary) async {
    final prefs = await _prefs;
    await prefs.setString(_lastBackupJsonKey, jsonEncode(summary.toJson()));
  }

  Future<BackupSummary?> getLastBackup() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_lastBackupJsonKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return BackupSummary.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<bool> isAutoBackupEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_autoEnabledKey) ?? true;
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(_autoEnabledKey, enabled);
  }

  Future<int> getDebounceThresholdMinutes() async {
    final prefs = await _prefs;
    return prefs.getInt(_thresholdMinutesKey) ?? 60 * 24;
  }

  Future<void> setDebounceThresholdMinutes(int minutes) async {
    final prefs = await _prefs;
    await prefs.setInt(_thresholdMinutesKey, minutes);
  }

  Future<int> getRetentionCount() async {
    final prefs = await _prefs;
    return prefs.getInt(_retentionCountKey) ?? 5;
  }

  Future<void> setRetentionCount(int count) async {
    final prefs = await _prefs;
    await prefs.setInt(_retentionCountKey, count);
  }

  Future<String?> getBackupDirectory() async {
    final prefs = await _prefs;
    return prefs.getString(_backupDirectoryKey);
  }

  Future<void> setBackupDirectory(String? path) async {
    final prefs = await _prefs;
    if (path == null || path.trim().isEmpty) {
      await prefs.remove(_backupDirectoryKey);
      return;
    }
    await prefs.setString(_backupDirectoryKey, path);
  }

  Future<bool> isPendingRestore() async {
    final prefs = await _prefs;
    return prefs.getBool(_pendingRestoreKey) ?? false;
  }

  Future<void> setPendingRestore(bool pending) async {
    final prefs = await _prefs;
    await prefs.setBool(_pendingRestoreKey, pending);
  }

  Future<bool> isNetworkMode() async {
    final prefs = await _prefs;
    return prefs.getBool(_networkModeKey) ?? false;
  }

  Future<void> setNetworkMode(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(_networkModeKey, enabled);
  }
}
