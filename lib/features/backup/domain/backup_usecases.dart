import 'package:delta_erp/features/backup/domain/backup_models.dart';
import 'package:delta_erp/features/backup/domain/backup_repository.dart';

class CreateBackupUseCase {
  const CreateBackupUseCase(this._repository);

  final BackupRepository _repository;

  Future<OperationResult> call({
    String? destinationPath,
    bool overwriteConfirmed = false,
    bool isAuto = false,
  }) {
    return _repository.createBackup(
      destinationPath: destinationPath,
      overwriteConfirmed: overwriteConfirmed,
      isAuto: isAuto,
    );
  }
}

class RestoreBackupUseCase {
  const RestoreBackupUseCase(this._repository);

  final BackupRepository _repository;

  Future<OperationResult> call({
    required String backupPath,
    required bool confirmed,
  }) {
    return _repository.restoreBackup(
      backupPath: backupPath,
      confirmed: confirmed,
    );
  }
}

class AutoBackupUseCase {
  const AutoBackupUseCase(this._repository);

  final BackupRepository _repository;

  Future<OperationResult> call({required String trigger}) {
    return _repository.runAutoBackupIfDue(trigger: trigger);
  }
}

class PruneBackupsUseCase {
  const PruneBackupsUseCase(this._repository);

  final BackupRepository _repository;

  Future<OperationResult> call({int keepLatest = 5}) {
    return _repository.pruneBackups(keepLatest: keepLatest);
  }
}

class ValidateBackupUseCase {
  const ValidateBackupUseCase(this._repository);

  final BackupRepository _repository;

  Future<OperationResult> call(String backupPath) {
    return _repository.validateBackup(backupPath);
  }
}

class GetLastBackupInfoUseCase {
  const GetLastBackupInfoUseCase(this._repository);

  final BackupRepository _repository;

  Future<BackupSummary?> call() {
    return _repository.getLastBackupInfo();
  }
}
