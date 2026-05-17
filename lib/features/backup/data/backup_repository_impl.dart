import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:delta_erp/core/utils/app_paths.dart';
import 'package:delta_erp/features/backup/data/backup_logger.dart';
import 'package:delta_erp/features/backup/data/backup_preferences_store.dart';
import 'package:delta_erp/features/backup/data/file_operation_executor.dart';
import 'package:delta_erp/features/backup/domain/backup_models.dart';
import 'package:delta_erp/features/backup/domain/backup_repository.dart';
import 'package:delta_erp/features/products/data/product_repository.dart';
import 'package:delta_erp/services/database/app_database.dart';
import 'package:delta_erp/services/database/maintenance_coordinator.dart';

class BackupRepositoryImpl implements BackupRepository {
  BackupRepositoryImpl({
    required AppDatabase appDatabase,
    required MaintenanceCoordinator maintenanceCoordinator,
    required BackupPreferencesStore preferencesStore,
    required BackupLogger logger,
    required ProductRepository productRepository,
    FileOperationExecutor? fileOperationExecutor,
  }) : _appDatabase = appDatabase,
       _maintenance = maintenanceCoordinator,
       _preferences = preferencesStore,
       _logger = logger,
       _productRepository = productRepository,
       _fileOperationExecutor =
           fileOperationExecutor ?? FileOperationExecutor(logger: logger);

  final AppDatabase _appDatabase;
  final MaintenanceCoordinator _maintenance;
  final BackupPreferencesStore _preferences;
  final BackupLogger _logger;
  final ProductRepository _productRepository;
  final FileOperationExecutor _fileOperationExecutor;

  static const String _appVersion = '1.0.0+1';

  @override
  Future<OperationResult> createBackup({
    String? destinationPath,
    bool overwriteConfirmed = false,
    bool isAuto = false,
  }) async {
    return _maintenance.runExclusive('backup', () async {
      final stopwatch = Stopwatch()..start();
      final dbPath = await AppPaths.getDatabasePath();
      final dbFile = File(dbPath);
      if (!await dbFile.exists()) {
        return OperationResult.fail(
          'Database file was not found.',
          errorCode: BackupErrorCodes.fileNotFound,
        );
      }

      final dbSize = await dbFile.length();
      if (dbSize <= 0) {
        return OperationResult.fail(
          'Database file is empty and cannot be backed up.',
          errorCode: BackupErrorCodes.invalidBackup,
        );
      }

      final db = await _appDatabase.database;
      await _checkpointWal(db);

      final targetPath = await _resolveTargetPath(destinationPath);
      final parent = Directory(p.dirname(targetPath));
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }

      if (await File(targetPath).exists() && !overwriteConfirmed) {
        return OperationResult.fail(
          'Target backup file already exists.',
          errorCode: BackupErrorCodes.invalidBackup,
          meta: {
            'requiresOverwriteConfirmation': true,
            'targetPath': targetPath,
          },
        );
      }

      final spaceResult = await _ensureEnoughSpace(parent.path, dbSize * 2);
      if (!spaceResult.success) {
        return spaceResult;
      }

      final stagedDbPath = await AppPaths.getBackupTempCopyPath();
      final stagedDbFile = File(stagedDbPath);
      await _fileOperationExecutor.run(
        operation: 'delete_temp_copy',
        action: () async {
          if (await stagedDbFile.exists()) {
            await stagedDbFile.delete();
          }
        },
      );

      final copyResult = await _fileOperationExecutor.run(
        operation: 'copy_db_to_temp',
        action: () async {
          await dbFile.copy(stagedDbPath);
        },
      );
      if (!copyResult.success) {
        return copyResult;
      }

      final stagedBytes = await stagedDbFile.readAsBytes();
      final checksum = sha256.convert(stagedBytes).toString();
      final isNetworkMode = await _preferences.isNetworkMode();
      final metadata = BackupMetadata(
        appVersion: _appVersion,
        dbVersion: _appDatabase.dbVersion,
        createdAt: DateTime.now().toUtc(),
        checksum: checksum,
        device: Platform.localHostname,
        lastSyncAt: null,
        isFullBackup: true,
        isNetworkMode: isNetworkMode,
        signature: null,
        signatureAlgorithm: 'HMAC-SHA256',
      );

      final zipBytes = _buildBackupZip(stagedBytes, metadata);
      final tmpZipPath = '$targetPath.tmp';
      final tmpZipFile = File(tmpZipPath);
      await _fileOperationExecutor.run(
        operation: 'write_zip_tmp',
        action: () async {
          await tmpZipFile.writeAsBytes(zipBytes, flush: true);
        },
      );

      final zipValidation = await validateBackup(tmpZipPath);
      if (!zipValidation.success) {
        return OperationResult.fail(
          'Generated backup package is invalid.',
          errorCode: BackupErrorCodes.invalidBackup,
          meta: zipValidation.meta,
        );
      }

      final finalFile = File(targetPath);
      if (await finalFile.exists()) {
        final deleteResult = await _fileOperationExecutor.run(
          operation: 'delete_existing_backup',
          action: () async {
            await finalFile.delete();
          },
        );
        if (!deleteResult.success) {
          return deleteResult;
        }
      }

      final moveResult = await _fileOperationExecutor.run(
        operation: 'move_tmp_to_target',
        action: () async {
          await tmpZipFile.rename(targetPath);
        },
      );
      if (!moveResult.success) {
        return moveResult;
      }

      final backupSize = await File(targetPath).length();
      final summary = BackupSummary(
        path: targetPath,
        createdAt: metadata.createdAt,
        sizeBytes: backupSize,
      );
      await _preferences.saveLastBackup(summary);
      if (!isAuto) {
        final savedDir = await _preferences.getBackupDirectory();
        if (savedDir == null || savedDir.trim().isEmpty) {
          await _preferences.setBackupDirectory(p.dirname(targetPath));
        }
      }
      final retention = await _preferences.getRetentionCount();
      await pruneBackups(keepLatest: retention);

      stopwatch.stop();
      _logger.info('backup_completed', {
        'path': targetPath,
        'size': backupSize,
        'duration_ms': stopwatch.elapsedMilliseconds,
        'is_auto': isAuto,
      });

      return OperationResult.ok(
        'Backup created successfully.',
        meta: {
          'path': targetPath,
          'sizeBytes': backupSize,
          'durationMs': stopwatch.elapsedMilliseconds,
          'checksum': checksum,
        },
      );
    });
  }

  @override
  Future<OperationResult> restoreBackup({
    required String backupPath,
    required bool confirmed,
  }) async {
    if (!confirmed) {
      return OperationResult.fail(
        'Restore operation was not confirmed.',
        errorCode: BackupErrorCodes.invalidBackup,
      );
    }

    return _maintenance.runExclusive('restore', () async {
      final preValidation = await validateBackup(backupPath);
      if (!preValidation.success) {
        return preValidation;
      }

      final validationMeta = preValidation.meta ?? <String, dynamic>{};
      final metadataJson = validationMeta['metadata'] as Map<String, dynamic>?;
      final metadata = metadataJson == null
          ? null
          : BackupMetadata.fromJson(metadataJson);

      if (metadata == null) {
        return OperationResult.fail(
          'Backup metadata is missing.',
          errorCode: BackupErrorCodes.invalidBackup,
        );
      }

      if (metadata.dbVersion > _appDatabase.dbVersion) {
        return OperationResult.fail(
          'Backup version is newer than this app can restore.',
          errorCode: BackupErrorCodes.incompatibleVersion,
          meta: {
            'backupVersion': metadata.dbVersion,
            'currentVersion': _appDatabase.dbVersion,
          },
        );
      }

      final stageResult = await _extractBackupDatabase(backupPath);
      if (!stageResult.success) {
        return stageResult;
      }

      final stagedDbPath =
          (stageResult.meta ?? const <String, dynamic>{})['stagedDbPath']
              as String?;
      if (stagedDbPath == null) {
        return OperationResult.fail(
          'Failed to stage restore database.',
          errorCode: BackupErrorCodes.invalidBackup,
        );
      }

      final preRestoreSnapshotPath = await AppPaths.getPreRestoreSnapshotPath();
      final currentDb = await _appDatabase.database;
      await _checkpointWal(currentDb);
      final snapshotResult = await _createPreRestoreSnapshot(
        preRestoreSnapshotPath,
      );
      if (!snapshotResult.success) {
        return snapshotResult;
      }

      final activeDbPath = await AppPaths.getDatabasePath();
      var rollbackAttempted = false;
      var rollbackSucceeded = false;

      _maintenance.enterMaintenanceMode();
      try {
        await _appDatabase.closeDatabaseForMaintenance();
        final replaceResult = await _replaceDatabaseFile(
          stagedDbPath,
          activeDbPath,
        );
        if (!replaceResult.success) {
          throw _RestoreFailure(replaceResult);
        }

        await _appDatabase.reopenDatabaseAfterMaintenance();
        final postIntegrity = await _runIntegrityCheck(activeDbPath);
        if (!postIntegrity.success) {
          throw _RestoreFailure(postIntegrity);
        }

        final smoke = await _runSmokeQuery();
        if (!smoke.success) {
          throw _RestoreFailure(smoke);
        }

        _productRepository.clearCache();
        await _preferences.setPendingRestore(true);
        return OperationResult.ok(
          'Restore completed successfully. Application restart is required.',
          meta: {
            'requiresRestart': true,
            'report': const RestoreReport(
              restoreSucceeded: true,
              rollbackAttempted: false,
              rollbackSucceeded: false,
              requiresRestart: true,
              details: 'Restore completed and integrity verified.',
            ).toJson(),
          },
        );
      } on _RestoreFailure catch (restoreFailure) {
        rollbackAttempted = true;
        final rollback = await _replaceDatabaseFile(
          preRestoreSnapshotPath,
          activeDbPath,
        );
        if (rollback.success) {
          rollbackSucceeded = true;
          await _appDatabase.reopenDatabaseAfterMaintenance();
          final rollbackIntegrity = await _runIntegrityCheck(activeDbPath);
          rollbackSucceeded = rollbackIntegrity.success;
        }

        return OperationResult.fail(
          restoreFailure.result.message,
          errorCode: rollbackSucceeded
              ? restoreFailure.result.errorCode
              : BackupErrorCodes.rollbackFailed,
          meta: {
            'restoreError': restoreFailure.result.meta,
            'report': RestoreReport(
              restoreSucceeded: false,
              rollbackAttempted: rollbackAttempted,
              rollbackSucceeded: rollbackSucceeded,
              requiresRestart: false,
              details: rollbackSucceeded
                  ? 'Restore failed but rollback succeeded.'
                  : 'Restore failed and rollback did not succeed.',
            ).toJson(),
          },
        );
      } catch (error, stackTrace) {
        _logger.error('restore_unhandled_error', error, stackTrace, {
          'activeDbPath': activeDbPath,
          'stagedDbPath': stagedDbPath,
        });
        return OperationResult.fail(
          'Restore failed due to an unexpected error.',
          errorCode: BackupErrorCodes.unknownError,
        );
      } finally {
        _maintenance.exitMaintenanceMode();
      }
    });
  }

  @override
  Future<OperationResult> validateBackup(String backupPath) async {
    final file = File(backupPath);
    if (!await file.exists()) {
      return OperationResult.fail(
        'Selected backup file does not exist.',
        errorCode: BackupErrorCodes.fileNotFound,
      );
    }

    final fileSize = await file.length();
    if (fileSize <= 0) {
      return OperationResult.fail(
        'Selected backup file is empty.',
        errorCode: BackupErrorCodes.invalidBackup,
      );
    }

    try {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      final metadataEntry = archive.files
          .where((f) => f.name == 'metadata.json')
          .firstOrNull;
      final dbEntry = archive.files
          .where((f) => f.name == 'app.db')
          .firstOrNull;
      if (metadataEntry == null || dbEntry == null) {
        return OperationResult.fail(
          'Backup package structure is invalid.',
          errorCode: BackupErrorCodes.invalidBackup,
          meta: {
            'fileExists': true,
            'fileSizeBytes': fileSize,
            'zipReadable': true,
            'metadataReadable': metadataEntry != null,
            'containsDatabaseFile': dbEntry != null,
          },
        );
      }

      final metadataText = utf8.decode(metadataEntry.content as List<int>);
      final metadataMap = jsonDecode(metadataText) as Map<String, dynamic>;
      final metadata = BackupMetadata.fromJson(metadataMap);

      final dbBytes = dbEntry.content as List<int>;
      final checksum = sha256.convert(dbBytes).toString();
      if (checksum != metadata.checksum) {
        return OperationResult.fail(
          'Backup checksum validation failed.',
          errorCode: BackupErrorCodes.invalidBackup,
          meta: {
            'expectedChecksum': metadata.checksum,
            'actualChecksum': checksum,
          },
        );
      }

      final stagedPath = await AppPaths.getStagedRestoreDatabasePath();
      await File(stagedPath).writeAsBytes(dbBytes, flush: true);
      final integrity = await _runIntegrityCheck(stagedPath);
      if (!integrity.success) {
        return integrity;
      }

      final report = BackupValidationReport(
        fileExists: true,
        fileSizeBytes: fileSize,
        zipReadable: true,
        metadataReadable: true,
        containsDatabaseFile: true,
        checksumValid: true,
        integrityOk: true,
      );

      return OperationResult.ok(
        'Backup validation succeeded.',
        meta: {...report.toJson(), 'metadata': metadata.toJson()},
      );
    } catch (error, stackTrace) {
      _logger.error('backup_validation_failed', error, stackTrace, {
        'path': backupPath,
      });
      return OperationResult.fail(
        'Backup validation failed.',
        errorCode: BackupErrorCodes.invalidBackup,
      );
    }
  }

  @override
  Future<OperationResult> runAutoBackupIfDue({required String trigger}) async {
    final enabled = await _preferences.isAutoBackupEnabled();
    if (!enabled) {
      final result = OperationResult.ok('Auto backup is disabled.');
      await _recordAutoBackupResult(
        trigger: trigger,
        outcome: 'disabled',
        message: result.message,
      );
      return result;
    }

    final thresholdMinutes = await _preferences.getDebounceThresholdMinutes();
    final lastBackup = await _preferences.getLastBackup();
    final now = DateTime.now().toUtc();
    if (lastBackup != null) {
      final delta = now.difference(lastBackup.createdAt);
      if (delta.inMinutes < thresholdMinutes) {
        final result = OperationResult.ok(
          'Auto backup skipped due to debounce threshold.',
          meta: {
            'trigger': trigger,
            'lastBackupAt': lastBackup.createdAt.toIso8601String(),
            'thresholdMinutes': thresholdMinutes,
          },
        );
        await _recordAutoBackupResult(
          trigger: trigger,
          outcome: 'skipped',
          message: result.message,
        );
        return result;
      }
    }

    final preferredDir = await _preferences.getBackupDirectory();
    final destination = preferredDir == null || preferredDir.trim().isEmpty
        ? null
        : p.join(preferredDir, _generateBackupFileName());
    try {
      final result = await createBackup(
        destinationPath: destination,
        isAuto: true,
      );
      await _recordAutoBackupResult(
        trigger: trigger,
        outcome: result.success ? 'success' : 'error',
        message: result.message,
      );
      return result;
    } catch (error, stackTrace) {
      _logger.error('auto_backup_failed', error, stackTrace, {
        'trigger': trigger,
      });
      final message = error is StateError
          ? 'Another maintenance operation is already running.'
          : 'Auto backup failed unexpectedly.';
      await _recordAutoBackupResult(
        trigger: trigger,
        outcome: 'error',
        message: message,
      );
      return OperationResult.fail(
        message,
        errorCode: BackupErrorCodes.unknownError,
      );
    }
  }

  Future<void> _recordAutoBackupResult({
    required String trigger,
    required String outcome,
    required String message,
  }) async {
    await _preferences.saveLastAutoBackupResult(
      AutoBackupLastResult(
        at: DateTime.now().toUtc(),
        outcome: outcome,
        message: message,
        trigger: trigger,
      ),
    );
  }

  @override
  Future<OperationResult> pruneBackups({int keepLatest = 5}) async {
    final directoryPath = await getDefaultBackupDirectory();
    final dir = Directory(directoryPath);
    if (!await dir.exists()) {
      return OperationResult.ok('Backup directory does not exist.');
    }

    final entries = await dir
        .list()
        .where(
          (entry) => entry is File && entry.path.toLowerCase().endsWith('.zip'),
        )
        .cast<File>()
        .toList();

    entries.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );
    if (entries.length <= keepLatest) {
      return OperationResult.ok('No backup pruning required.');
    }

    var deleted = 0;
    for (final file in entries.skip(keepLatest)) {
      try {
        await file.delete();
        deleted++;
      } catch (error, stackTrace) {
        _logger.error('backup_prune_delete_failed', error, stackTrace, {
          'path': file.path,
        });
      }
    }

    return OperationResult.ok(
      'Backup retention cleanup completed.',
      meta: {'deleted': deleted},
    );
  }

  @override
  Future<OperationResult> verifyCurrentDatabaseHealth() async {
    final dbPath = await AppPaths.getDatabasePath();
    final integrity = await _runIntegrityCheck(dbPath);
    if (!integrity.success) {
      return integrity;
    }
    return _runSmokeQuery();
  }

  @override
  Future<BackupSummary?> getLastBackupInfo() {
    return _preferences.getLastBackup();
  }

  @override
  Future<AutoBackupLastResult?> getLastAutoBackupResult() {
    return _preferences.getLastAutoBackupResult();
  }

  @override
  Future<List<BackupSummary>> listBackups() async {
    final directoryPath = await getDefaultBackupDirectory();
    final dir = Directory(directoryPath);
    if (!await dir.exists()) {
      return const <BackupSummary>[];
    }

    final files = await dir
        .list()
        .where(
          (entry) => entry is File && entry.path.toLowerCase().endsWith('.zip'),
        )
        .cast<File>()
        .toList();

    final summaries = <BackupSummary>[];
    for (final file in files) {
      final stat = await file.stat();
      summaries.add(
        BackupSummary(
          path: file.path,
          createdAt: stat.modified.toUtc(),
          sizeBytes: stat.size,
        ),
      );
    }

    summaries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return summaries;
  }

  @override
  Future<OperationResult> deleteBackup(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return OperationResult.fail(
        'Backup file not found for deletion.',
        errorCode: BackupErrorCodes.fileNotFound,
      );
    }

    final result = await _fileOperationExecutor.run(
      operation: 'delete_backup_file',
      action: () async {
        await file.delete();
      },
    );

    if (!result.success) {
      return result;
    }

    final last = await _preferences.getLastBackup();
    if (last != null && p.equals(last.path, path)) {
      final history = await listBackups();
      if (history.isNotEmpty) {
        await _preferences.saveLastBackup(history.first);
      }
    }

    return OperationResult.ok(
      'Backup deleted successfully.',
      meta: {'path': path},
    );
  }

  @override
  Future<BackupSettings> loadSettings() async {
    final autoEnabled = await _preferences.isAutoBackupEnabled();
    final threshold = await _preferences.getDebounceThresholdMinutes();
    final retention = await _preferences.getRetentionCount();
    final networkMode = await _preferences.isNetworkMode();
    final directory = await _preferences.getBackupDirectory();

    return BackupSettings(
      autoBackupEnabled: autoEnabled,
      debounceThresholdMinutes: threshold,
      retentionCount: retention,
      isNetworkMode: networkMode,
      backupDirectory: directory,
    );
  }

  @override
  Future<OperationResult> saveSettings(BackupSettings settings) async {
    final retention = settings.retentionCount.clamp(1, 30);
    final threshold = settings.debounceThresholdMinutes.clamp(15, 60 * 24 * 7);

    await _preferences.setAutoBackupEnabled(settings.autoBackupEnabled);
    await _preferences.setRetentionCount(retention);
    await _preferences.setDebounceThresholdMinutes(threshold);
    await _preferences.setNetworkMode(settings.isNetworkMode);
    await _preferences.setBackupDirectory(settings.backupDirectory);

    return OperationResult.ok(
      'Backup settings saved successfully.',
      meta: {
        'autoBackupEnabled': settings.autoBackupEnabled,
        'retentionCount': retention,
        'debounceThresholdMinutes': threshold,
        'isNetworkMode': settings.isNetworkMode,
        'backupDirectory': settings.backupDirectory,
      },
    );
  }

  @override
  Future<String> getDefaultBackupDirectory() async {
    final saved = await _preferences.getBackupDirectory();
    if (saved != null && saved.trim().isNotEmpty) {
      return saved;
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(
      p.join(docsDir.path, 'DeltaFlow', 'Backups'),
    );
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir.path;
  }

  @override
  Future<void> cleanupTempArtifacts() async {
    final targets = <String>[
      await AppPaths.getBackupTempCopyPath(),
      await AppPaths.getStagedRestoreDatabasePath(),
      await AppPaths.getPreRestoreSnapshotPath(),
      await AppPaths.getRestoreTempDirectoryPath(),
    ];

    for (final target in targets) {
      final entityType = FileSystemEntity.typeSync(target);
      try {
        if (entityType == FileSystemEntityType.file) {
          await File(target).delete();
        } else if (entityType == FileSystemEntityType.directory) {
          await Directory(target).delete(recursive: true);
        }
      } catch (error, stackTrace) {
        _logger.error('backup_temp_cleanup_failed', error, stackTrace, {
          'path': target,
        });
      }
    }
  }

  Future<void> _checkpointWal(Database db) async {
    try {
      await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
      _logger.info('wal_checkpoint_completed', const <String, Object?>{});
    } catch (error, stackTrace) {
      _logger.warn('wal_checkpoint_skipped', {'error': error.toString()});
      _logger.error(
        'wal_checkpoint_error',
        error,
        stackTrace,
        const <String, Object?>{},
      );
    }
  }

  Future<OperationResult> _runSmokeQuery() async {
    try {
      final db = await _appDatabase.database;
      await db.rawQuery('SELECT name FROM sqlite_master LIMIT 1');
      return OperationResult.ok('Smoke query succeeded.');
    } catch (error, stackTrace) {
      _logger.error(
        'restore_smoke_query_failed',
        error,
        stackTrace,
        const <String, Object?>{},
      );
      return OperationResult.fail(
        'Post-restore smoke query failed.',
        errorCode: BackupErrorCodes.integrityFailed,
      );
    }
  }

  Future<OperationResult> _runIntegrityCheck(String dbPath) async {
    Database? db;
    try {
      db = await openDatabase(dbPath, readOnly: true, singleInstance: false);
      final rows = await db.rawQuery('PRAGMA integrity_check');
      final result = rows.isEmpty
          ? null
          : rows.first.values.first.toString().toLowerCase();
      if (result != 'ok') {
        return OperationResult.fail(
          'Integrity check failed.',
          errorCode: BackupErrorCodes.integrityFailed,
          meta: {'integrityResult': result},
        );
      }
      return OperationResult.ok('Integrity check succeeded.');
    } catch (error, stackTrace) {
      _logger.error('integrity_check_failed', error, stackTrace, {
        'dbPath': dbPath,
      });
      return OperationResult.fail(
        'Failed to run integrity check.',
        errorCode: BackupErrorCodes.integrityFailed,
      );
    } finally {
      await db?.close();
    }
  }

  Future<OperationResult> _extractBackupDatabase(String backupPath) async {
    try {
      final bytes = await File(backupPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      final dbEntry = archive.files
          .where((f) => f.name == 'app.db')
          .firstOrNull;
      if (dbEntry == null) {
        return OperationResult.fail(
          'Backup package does not contain database file.',
          errorCode: BackupErrorCodes.invalidBackup,
        );
      }

      final restoreDirPath = await AppPaths.getRestoreTempDirectoryPath();
      final restoreDir = Directory(restoreDirPath);
      if (await restoreDir.exists()) {
        await restoreDir.delete(recursive: true);
      }
      await restoreDir.create(recursive: true);

      final stagedDbPath = p.join(restoreDir.path, 'app.db');
      await File(
        stagedDbPath,
      ).writeAsBytes(dbEntry.content as List<int>, flush: true);
      return OperationResult.ok(
        'Backup extracted to staging.',
        meta: {'stagedDbPath': stagedDbPath},
      );
    } catch (error, stackTrace) {
      _logger.error('extract_backup_failed', error, stackTrace, {
        'path': backupPath,
      });
      return OperationResult.fail(
        'Failed to extract backup archive.',
        errorCode: BackupErrorCodes.invalidBackup,
      );
    }
  }

  Future<OperationResult> _createPreRestoreSnapshot(String snapshotPath) async {
    final activeDbPath = await AppPaths.getDatabasePath();
    final activeDb = File(activeDbPath);
    if (!await activeDb.exists()) {
      return OperationResult.fail(
        'Active database file does not exist for pre-restore backup.',
        errorCode: BackupErrorCodes.fileNotFound,
      );
    }

    final snapshotFile = File(snapshotPath);
    final snapshotDir = snapshotFile.parent;
    if (!await snapshotDir.exists()) {
      await snapshotDir.create(recursive: true);
    }

    return _fileOperationExecutor.run(
      operation: 'create_pre_restore_snapshot',
      action: () async {
        if (await snapshotFile.exists()) {
          await snapshotFile.delete();
        }
        await activeDb.copy(snapshotPath);

        final sourceSidecars = _sqliteSidecarPaths(activeDbPath);
        final targetSidecars = _sqliteSidecarPaths(snapshotPath);
        for (var i = 0; i < sourceSidecars.length; i++) {
          final source = File(sourceSidecars[i]);
          final target = File(targetSidecars[i]);
          if (await target.exists()) {
            await target.delete();
          }
          if (await source.exists()) {
            await source.copy(target.path);
          }
        }
      },
    );
  }

  Future<OperationResult> _replaceDatabaseFile(
    String sourcePath,
    String targetPath,
  ) {
    final source = File(sourcePath);
    final target = File(targetPath);
    return _fileOperationExecutor.run(
      operation: 'replace_database_file',
      action: () async {
        if (!await source.exists()) {
          throw FileSystemException(
            'Source file missing for replace operation.',
            sourcePath,
          );
        }

        for (final sidecar in _sqliteSidecarPaths(targetPath)) {
          final sidecarFile = File(sidecar);
          if (await sidecarFile.exists()) {
            await sidecarFile.delete();
          }
        }

        if (await target.exists()) {
          await target.delete();
        }
        await source.copy(targetPath);

        final sourceSidecars = _sqliteSidecarPaths(sourcePath);
        final targetSidecars = _sqliteSidecarPaths(targetPath);
        for (var i = 0; i < sourceSidecars.length; i++) {
          final sourceSidecar = File(sourceSidecars[i]);
          final targetSidecar = File(targetSidecars[i]);
          if (await targetSidecar.exists()) {
            await targetSidecar.delete();
          }
          if (await sourceSidecar.exists()) {
            await sourceSidecar.copy(targetSidecar.path);
          }
        }
      },
    );
  }

  List<String> _sqliteSidecarPaths(String dbPath) {
    return <String>['$dbPath-wal', '$dbPath-shm'];
  }

  Future<OperationResult> _ensureEnoughSpace(
    String targetDirectoryPath,
    int requiredBytes,
  ) async {
    if (requiredBytes <= 0) {
      return OperationResult.ok('Free-space check succeeded.');
    }

    final available = await _tryGetFreeBytes(targetDirectoryPath);
    if (available == null) {
      _logger.warn('free_space_check_skipped', {
        'targetDirectoryPath': targetDirectoryPath,
        'requiredBytes': requiredBytes,
      });
      return OperationResult.ok('Free-space check skipped.');
    }

    if (available < requiredBytes) {
      return OperationResult.fail(
        'Insufficient disk space for backup operation.',
        errorCode: BackupErrorCodes.diskFull,
        meta: {
          'requiredBytes': requiredBytes,
          'availableBytes': available,
          'targetDirectoryPath': targetDirectoryPath,
        },
      );
    }

    return OperationResult.ok('Free-space check succeeded.');
  }

  Future<int?> _tryGetFreeBytes(String path) async {
    if (!Platform.isWindows) {
      return null;
    }

    final root = p.rootPrefix(path);
    if (root.isEmpty) {
      return null;
    }
    final drive = root.replaceAll('\\', '');
    try {
      final result = await Process.run('fsutil', ['volume', 'diskfree', drive]);
      if (result.exitCode != 0) {
        return null;
      }
      final output = '${result.stdout}\n${result.stderr}';
      final match =
          RegExp(r'Total # of free bytes\s*:\s*([0-9,]+)').firstMatch(output) ??
          RegExp(
            r'Total # of avail free bytes\s*:\s*([0-9,]+)',
          ).firstMatch(output);
      if (match == null) {
        return null;
      }
      final raw = match.group(1)?.replaceAll(',', '');
      return int.tryParse(raw ?? '');
    } catch (_) {
      return null;
    }
  }

  Archive _buildArchive(List<int> dbBytes, BackupMetadata metadata) {
    final archive = Archive();
    archive.addFile(ArchiveFile('app.db', dbBytes.length, dbBytes));
    final metadataBytes = utf8.encode(jsonEncode(metadata.toJson()));
    archive.addFile(
      ArchiveFile('metadata.json', metadataBytes.length, metadataBytes),
    );
    return archive;
  }

  List<int> _buildBackupZip(List<int> dbBytes, BackupMetadata metadata) {
    final archive = _buildArchive(dbBytes, metadata);
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw StateError('Failed to encode backup ZIP archive.');
    }
    return encoded;
  }

  Future<String> _resolveTargetPath(String? destinationPath) async {
    if (destinationPath != null && destinationPath.trim().isNotEmpty) {
      final trimmed = destinationPath.trim();
      if (trimmed.toLowerCase().endsWith('.zip')) {
        return trimmed;
      }
      return p.join(trimmed, _generateBackupFileName());
    }

    final directory = await getDefaultBackupDirectory();
    final target = p.join(directory, _generateBackupFileName());
    return target;
  }

  String _generateBackupFileName() {
    final now = DateTime.now();
    final yyyy = now.year.toString().padLeft(4, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    final sec = now.second.toString().padLeft(2, '0');
    final sss = now.millisecond.toString().padLeft(3, '0');
    return 'backup_$yyyy-$mm-$dd'
        '_$hh-$min-$sec-$sss.zip';
  }
}

class _RestoreFailure implements Exception {
  const _RestoreFailure(this.result);

  final OperationResult result;
}
