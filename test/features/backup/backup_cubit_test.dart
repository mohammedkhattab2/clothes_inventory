import 'package:flutter_test/flutter_test.dart';
import 'package:delta_erp/features/backup/domain/backup_models.dart';
import 'package:delta_erp/features/backup/domain/backup_repository.dart';
import 'package:delta_erp/features/backup/presentation/backup_cubit.dart';

class _FakeBackupRepository implements BackupRepository {
  _FakeBackupRepository({
    required this.createBackupResult,
    required this.restoreBackupResult,
    this.summary,
  });

  final OperationResult createBackupResult;
  final OperationResult restoreBackupResult;
  final BackupSummary? summary;

  @override
  Future<void> cleanupTempArtifacts() async {}

  @override
  Future<OperationResult> createBackup({
    String? destinationPath,
    bool overwriteConfirmed = false,
    bool isAuto = false,
  }) async {
    return createBackupResult;
  }

  @override
  Future<String> getDefaultBackupDirectory() async {
    return 'C:/backups';
  }

  @override
  Future<BackupSummary?> getLastBackupInfo() async {
    return summary;
  }

  @override
  Future<AutoBackupLastResult?> getLastAutoBackupResult() async {
    return null;
  }

  @override
  Future<BackupSettings> loadSettings() async {
    return const BackupSettings(
      autoBackupEnabled: true,
      debounceThresholdMinutes: 1440,
      retentionCount: 5,
      isNetworkMode: false,
      backupDirectory: null,
    );
  }

  @override
  Future<OperationResult> saveSettings(BackupSettings settings) async {
    return OperationResult.ok('ok');
  }

  @override
  Future<List<BackupSummary>> listBackups() async {
    return summary == null
        ? const <BackupSummary>[]
        : <BackupSummary>[summary!];
  }

  @override
  Future<OperationResult> deleteBackup(String path) async {
    return OperationResult.ok('deleted');
  }

  @override
  Future<OperationResult> verifyCurrentDatabaseHealth() async {
    return OperationResult.ok('ok');
  }

  @override
  Future<OperationResult> pruneBackups({int keepLatest = 5}) async {
    return OperationResult.ok('ok');
  }

  @override
  Future<OperationResult> restoreBackup({
    required String backupPath,
    required bool confirmed,
  }) async {
    return restoreBackupResult;
  }

  @override
  Future<OperationResult> runAutoBackupIfDue({required String trigger}) async {
    return OperationResult.ok('ok');
  }

  @override
  Future<OperationResult> validateBackup(String backupPath) async {
    return OperationResult.ok('ok');
  }
}

void main() {
  group('BackupCubit', () {
    test('createBackup emits success state when operation succeeds', () async {
      final repository = _FakeBackupRepository(
        createBackupResult: OperationResult.ok('Backup created.'),
        restoreBackupResult: OperationResult.ok('Restore done.'),
        summary: BackupSummary(
          path: 'C:/backups/backup.zip',
          createdAt: DateTime.now().toUtc(),
          sizeBytes: 1024,
        ),
      );
      final cubit = BackupCubit(repository: repository);

      await cubit.createBackup(destinationPath: 'C:/backups/backup.zip');

      expect(cubit.state.status, BackupStatus.success);
      expect(cubit.state.message, 'Backup created.');
      expect(cubit.state.lastBackupPath, 'C:/backups/backup.zip');
      cubit.close();
    });

    test('restoreBackup emits error state when validation fails', () async {
      final repository = _FakeBackupRepository(
        createBackupResult: OperationResult.ok('Backup created.'),
        restoreBackupResult: OperationResult.fail(
          'Restore failed.',
          errorCode: BackupErrorCodes.integrityFailed,
        ),
      );
      final cubit = BackupCubit(repository: repository);

      await cubit.restoreBackup(
        backupPath: 'C:/backups/backup.zip',
        confirmed: true,
      );

      expect(cubit.state.status, BackupStatus.error);
      expect(cubit.state.errorCode, BackupErrorCodes.integrityFailed);
      cubit.close();
    });
  });
}
