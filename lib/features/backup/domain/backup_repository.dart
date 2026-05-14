import 'package:clothes_inventory/features/backup/domain/backup_models.dart';

abstract class BackupRepository {
  Future<OperationResult> createBackup({
    String? destinationPath,
    bool overwriteConfirmed = false,
    bool isAuto = false,
  });

  Future<OperationResult> restoreBackup({
    required String backupPath,
    required bool confirmed,
  });

  Future<OperationResult> validateBackup(String backupPath);

  Future<OperationResult> runAutoBackupIfDue({required String trigger});

  Future<OperationResult> pruneBackups({int keepLatest = 5});

  Future<OperationResult> verifyCurrentDatabaseHealth();

  Future<BackupSettings> loadSettings();

  Future<OperationResult> saveSettings(BackupSettings settings);

  Future<List<BackupSummary>> listBackups();

  Future<OperationResult> deleteBackup(String path);

  Future<BackupSummary?> getLastBackupInfo();

  Future<String> getDefaultBackupDirectory();

  Future<void> cleanupTempArtifacts();
}
