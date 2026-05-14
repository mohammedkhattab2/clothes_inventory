import 'dart:async';
import 'dart:io';

import 'package:clothes_inventory/features/backup/data/backup_logger.dart';
import 'package:clothes_inventory/features/backup/data/backup_preferences_store.dart';
import 'package:clothes_inventory/features/backup/domain/backup_repository.dart';

class BackupLifecycleService {
  BackupLifecycleService({
    required BackupRepository repository,
    required BackupPreferencesStore preferencesStore,
    required BackupLogger logger,
  }) : _repository = repository,
       _preferences = preferencesStore,
       _logger = logger;

  final BackupRepository _repository;
  final BackupPreferencesStore _preferences;
  final BackupLogger _logger;

  Future<void> handleAppStartup() async {
    await _repository.cleanupTempArtifacts();

    final pendingRestore = await _preferences.isPendingRestore();
    if (pendingRestore) {
      _logger.info('pending_restore_flag_detected', const <String, Object?>{});
      final verifyResult = await _repository.verifyCurrentDatabaseHealth();
      _logger.info('pending_restore_verification_result', {
        'success': verifyResult.success,
        'errorCode': verifyResult.errorCode,
        'message': verifyResult.message,
      });
      if (verifyResult.success) {
        await _preferences.setPendingRestore(false);
      }
    }

    final result = await _repository.runAutoBackupIfDue(trigger: 'startup');
    _logger.info('auto_backup_startup_result', {
      'success': result.success,
      'message': result.message,
      'errorCode': result.errorCode,
    });
  }

  Future<void> handleAppExit() async {
    final result = await _repository.runAutoBackupIfDue(trigger: 'exit');
    _logger.info('auto_backup_exit_result', {
      'success': result.success,
      'message': result.message,
      'errorCode': result.errorCode,
    });
  }

  Future<void> restartApplication({
    Duration delay = const Duration(milliseconds: 900),
  }) async {
    await Future<void>.delayed(delay);
    final executablePath = Platform.resolvedExecutable;
    await Process.start(executablePath, const <String>[]);
    exit(0);
  }
}
