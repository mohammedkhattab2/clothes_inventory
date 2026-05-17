import 'dart:async';
import 'dart:io';

import 'package:delta_erp/features/backup/data/backup_logger.dart';
import 'package:delta_erp/features/backup/domain/backup_models.dart';

class FileOperationExecutor {
  const FileOperationExecutor({
    required BackupLogger logger,
    this.maxAttempts = 3,
    this.retryDelay = const Duration(milliseconds: 220),
  }) : _logger = logger;

  final BackupLogger _logger;
  final int maxAttempts;
  final Duration retryDelay;

  Future<OperationResult> run({
    required String operation,
    required Future<void> Function() action,
  }) async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await action();
        _logger.info('file_operation_attempt', {
          'operation': operation,
          'attempt': attempt,
          'status': 'success',
        });
        return OperationResult.ok('File operation succeeded.');
      } on FileSystemException catch (error, stackTrace) {
        final isPermission = isPermissionError(error);
        final isLocked = isLockedError(error);
        _logger.error('file_operation_attempt_failed', error, stackTrace, {
          'operation': operation,
          'attempt': attempt,
        });
        if (attempt == maxAttempts) {
          return OperationResult.fail(
            'File operation failed: ${error.message}',
            errorCode: isPermission
                ? BackupErrorCodes.permissionDenied
                : isLocked
                ? BackupErrorCodes.fileLocked
                : BackupErrorCodes.unknownError,
            meta: {'operation': operation, 'attempts': maxAttempts},
          );
        }
      } catch (error, stackTrace) {
        _logger.error('file_operation_unexpected_error', error, stackTrace, {
          'operation': operation,
          'attempt': attempt,
        });
        if (attempt == maxAttempts) {
          return OperationResult.fail(
            'File operation failed unexpectedly.',
            errorCode: BackupErrorCodes.unknownError,
            meta: {'operation': operation, 'attempts': maxAttempts},
          );
        }
      }

      await Future<void>.delayed(retryDelay);
    }

    return OperationResult.fail(
      'File operation failed.',
      errorCode: BackupErrorCodes.unknownError,
      meta: {'operation': operation, 'attempts': maxAttempts},
    );
  }

  bool isPermissionError(FileSystemException error) {
    final message = error.osError?.message.toLowerCase() ?? '';
    return message.contains('access is denied') ||
        message.contains('permission denied');
  }

  bool isLockedError(FileSystemException error) {
    final message = error.osError?.message.toLowerCase() ?? '';
    return message.contains('being used by another process') ||
        message.contains('file is locked') ||
        message.contains('cannot access the file');
  }
}
