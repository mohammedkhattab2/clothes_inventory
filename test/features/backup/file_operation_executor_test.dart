import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:delta_erp/features/backup/data/backup_logger.dart';
import 'package:delta_erp/features/backup/data/file_operation_executor.dart';
import 'package:delta_erp/features/backup/domain/backup_models.dart';

void main() {
  group('FileOperationExecutor', () {
    test('returns success when action succeeds first time', () async {
      final executor = FileOperationExecutor(
        logger: const BackupLogger(),
        retryDelay: Duration.zero,
      );

      var calls = 0;
      final result = await executor.run(
        operation: 'success_first',
        action: () async {
          calls++;
        },
      );

      expect(result.success, isTrue);
      expect(calls, 1);
    });

    test('retries until success on later attempt', () async {
      final executor = FileOperationExecutor(
        logger: const BackupLogger(),
        retryDelay: Duration.zero,
      );

      var calls = 0;
      final result = await executor.run(
        operation: 'retry_then_success',
        action: () async {
          calls++;
          if (calls < 3) {
            throw FileSystemException(
              'Transient lock.',
              'C:/tmp.db',
              const OSError(
                'The process cannot access the file because it is being used by another process.',
              ),
            );
          }
        },
      );

      expect(result.success, isTrue);
      expect(calls, 3);
    });

    test('maps permission errors to permission_denied', () async {
      final executor = FileOperationExecutor(
        logger: const BackupLogger(),
        retryDelay: Duration.zero,
      );

      var calls = 0;
      final result = await executor.run(
        operation: 'permission_error',
        action: () async {
          calls++;
          throw FileSystemException(
            'Cannot write file',
            'C:/protected/file.zip',
            const OSError('Access is denied'),
          );
        },
      );

      expect(result.success, isFalse);
      expect(result.errorCode, BackupErrorCodes.permissionDenied);
      expect(calls, 3);
    });

    test('maps file lock errors to file_locked', () async {
      final executor = FileOperationExecutor(
        logger: const BackupLogger(),
        retryDelay: Duration.zero,
      );

      var calls = 0;
      final result = await executor.run(
        operation: 'file_locked_error',
        action: () async {
          calls++;
          throw FileSystemException(
            'Cannot access file',
            'C:/inuse/file.zip',
            const OSError(
              'The process cannot access the file because it is being used by another process.',
            ),
          );
        },
      );

      expect(result.success, isFalse);
      expect(result.errorCode, BackupErrorCodes.fileLocked);
      expect(calls, 3);
    });

    test('maps unknown exceptions to unknown_error', () async {
      final executor = FileOperationExecutor(
        logger: const BackupLogger(),
        retryDelay: Duration.zero,
      );

      var calls = 0;
      final result = await executor.run(
        operation: 'unknown_error',
        action: () async {
          calls++;
          throw StateError('Unexpected failure');
        },
      );

      expect(result.success, isFalse);
      expect(result.errorCode, BackupErrorCodes.unknownError);
      expect(calls, 3);
    });
  });
}
