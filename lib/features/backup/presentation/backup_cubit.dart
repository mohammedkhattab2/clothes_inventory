import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:delta_erp/features/backup/domain/backup_models.dart';
import 'package:delta_erp/features/backup/domain/backup_repository.dart';
import 'package:delta_erp/features/backup/domain/backup_usecases.dart';

part 'backup_state.dart';

class BackupCubit extends Cubit<BackupState> {
  BackupCubit({required BackupRepository repository})
    : _repository = repository,
      _createBackup = CreateBackupUseCase(repository),
      _restoreBackup = RestoreBackupUseCase(repository),
      _validateBackup = ValidateBackupUseCase(repository),
      _getLastBackupInfo = GetLastBackupInfoUseCase(repository),
      _autoBackup = AutoBackupUseCase(repository),
      super(const BackupState());

  final BackupRepository _repository;
  final CreateBackupUseCase _createBackup;
  final RestoreBackupUseCase _restoreBackup;
  final ValidateBackupUseCase _validateBackup;
  final GetLastBackupInfoUseCase _getLastBackupInfo;
  final AutoBackupUseCase _autoBackup;

  Future<void> loadOverview() async {
    final summary = await _getLastBackupInfo();
    final settings = await _repository.loadSettings();
    final history = await _repository.listBackups();
    final lastAuto = await _repository.getLastAutoBackupResult();
    final backupPath = summary?.path;
    final backupAt = summary?.createdAt;
    final backupSize = summary?.sizeBytes;
    final isHealthy = backupAt != null
        ? DateTime.now().toUtc().difference(backupAt) <=
              const Duration(hours: 24)
        : false;
    emit(
      state.copyWith(
        lastBackupPath: backupPath,
        lastBackupAt: backupAt,
        lastBackupSizeBytes: backupSize,
        isHealthy: isHealthy,
        autoBackupEnabled: settings.autoBackupEnabled,
        debounceThresholdMinutes: settings.debounceThresholdMinutes,
        retentionCount: settings.retentionCount,
        isNetworkMode: settings.isNetworkMode,
        backupDirectory: settings.backupDirectory,
        backupHistory: history,
        lastAutoBackupResult: lastAuto,
      ),
    );
  }

  Future<OperationResult> deleteBackup(String path) async {
    emit(
      state.copyWith(
        status: BackupStatus.loading,
        message: 'backup.deleting',
      ),
    );
    try {
      final result = await _repository.deleteBackup(path);
      await loadOverview();

      if (result.success) {
        emit(
          state.copyWith(
            status: BackupStatus.success,
            message: result.message,
            operationMeta: result.meta,
            errorCode: null,
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: BackupStatus.error,
            message: result.message,
            errorCode: result.errorCode,
            operationMeta: result.meta,
          ),
        );
      }
      return result;
    } catch (error) {
      return _emitUnexpectedError('backup.delete_failed', error);
    }
  }

  Future<OperationResult> saveSettings({
    required bool autoBackupEnabled,
    required int debounceThresholdMinutes,
    required int retentionCount,
    required bool isNetworkMode,
    required String? backupDirectory,
    bool runAutoBackupAfterSave = true,
  }) async {
    emit(
      state.copyWith(
        status: BackupStatus.loading,
        message: 'backup.saving_settings',
      ),
    );

    final settings = BackupSettings(
      autoBackupEnabled: autoBackupEnabled,
      debounceThresholdMinutes: debounceThresholdMinutes,
      retentionCount: retentionCount,
      isNetworkMode: isNetworkMode,
      backupDirectory: backupDirectory,
    );
    try {
      final result = await _repository.saveSettings(settings);
      await loadOverview();

      if (result.success) {
        emit(
          state.copyWith(
            status: BackupStatus.success,
            message: result.message,
            operationMeta: result.meta,
            errorCode: null,
          ),
        );
        if (runAutoBackupAfterSave && autoBackupEnabled) {
          await runAutoBackupIfDue(trigger: 'settings_saved');
        }
      } else {
        emit(
          state.copyWith(
            status: BackupStatus.error,
            message: result.message,
            errorCode: result.errorCode,
            operationMeta: result.meta,
          ),
        );
      }
      return result;
    } catch (error) {
      return _emitUnexpectedError('backup.save_settings_failed', error);
    }
  }

  Future<OperationResult> runAutoBackupIfDue({required String trigger}) async {
    try {
      final result = await _autoBackup(trigger: trigger);
      await loadOverview();
      return result;
    } catch (error) {
      return _emitUnexpectedError('backup.auto_failed', error);
    }
  }

  Future<OperationResult> dryRunValidateBackup(String backupPath) async {
    emit(
      state.copyWith(
        status: BackupStatus.loading,
        message: 'backup.validating_package',
      ),
    );
    try {
      final result = await _validateBackup(backupPath);

      if (result.success) {
        emit(
          state.copyWith(
            status: BackupStatus.success,
            message: 'backup.validation_succeeded',
            operationMeta: result.meta,
            errorCode: null,
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: BackupStatus.error,
            message: result.message,
            errorCode: result.errorCode,
            operationMeta: result.meta,
          ),
        );
      }

      return result;
    } catch (error) {
      return _emitUnexpectedError('backup.validation_failed', error);
    }
  }

  Future<OperationResult> createBackup({
    String? destinationPath,
    bool overwriteConfirmed = false,
    bool isAuto = false,
  }) async {
    emit(
      state.copyWith(
        status: BackupStatus.loading,
        message: 'backup.creating',
      ),
    );
    try {
      final result = await _createBackup(
        destinationPath: destinationPath,
        overwriteConfirmed: overwriteConfirmed,
        isAuto: isAuto,
      );
      await loadOverview();
      if (result.success) {
        emit(
          state.copyWith(
            status: BackupStatus.success,
            message: result.message,
            operationMeta: result.meta,
            errorCode: null,
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: BackupStatus.error,
            message: result.message,
            errorCode: result.errorCode,
            operationMeta: result.meta,
          ),
        );
      }
      return result;
    } on StateError {
      return _emitMaintenanceBusy();
    } catch (error) {
      return _emitUnexpectedError('backup.create_failed', error);
    }
  }

  Future<OperationResult> restoreBackup({
    required String backupPath,
    required bool confirmed,
  }) async {
    emit(
      state.copyWith(
        status: BackupStatus.loading,
        message: 'backup.restoring',
      ),
    );

    try {
      final validation = await _validateBackup(backupPath);
      if (!validation.success) {
        emit(
          state.copyWith(
            status: BackupStatus.error,
            message: validation.message,
            errorCode: validation.errorCode,
            operationMeta: validation.meta,
          ),
        );
        return validation;
      }

      final result = await _restoreBackup(
        backupPath: backupPath,
        confirmed: confirmed,
      );
      await loadOverview();
      if (result.success) {
        emit(
          state.copyWith(
            status: BackupStatus.success,
            message: result.message,
            operationMeta: result.meta,
            errorCode: null,
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: BackupStatus.error,
            message: result.message,
            errorCode: result.errorCode,
            operationMeta: result.meta,
          ),
        );
      }
      return result;
    } on StateError {
      return _emitMaintenanceBusy();
    } catch (error) {
      return _emitUnexpectedError('backup.restore_failed', error);
    }
  }

  Future<String> getDefaultBackupDirectory() {
    return _repository.getDefaultBackupDirectory();
  }

  void clearTransient() {
    emit(
      state.copyWith(status: BackupStatus.idle, message: null, clearMeta: true),
    );
  }

  OperationResult _emitMaintenanceBusy() {
    const message = 'backup.maintenance_busy';
    emit(
      state.copyWith(
        status: BackupStatus.error,
        message: message,
        errorCode: BackupErrorCodes.dbLocked,
      ),
    );
    return OperationResult.fail(
      message,
      errorCode: BackupErrorCodes.dbLocked,
    );
  }

  OperationResult _emitUnexpectedError(String fallback, Object error) {
    final message = error is StateError ? 'backup.maintenance_busy' : fallback;
    emit(
      state.copyWith(
        status: BackupStatus.error,
        message: message,
        errorCode: BackupErrorCodes.unknownError,
      ),
    );
    return OperationResult.fail(
      message,
      errorCode: BackupErrorCodes.unknownError,
    );
  }
}
