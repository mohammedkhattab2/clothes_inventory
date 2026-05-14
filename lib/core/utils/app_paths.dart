import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class AppPaths {
  AppPaths._();

  static const String _appFolderName = 'ClothesInventoryApp';
  static const String _dbFileName = 'app.db';
  static const String _logsFileName = 'logs.txt';
  static const String _tempFolderName = 'temp';
  static const String _backupFolderName = 'Backups';

  static Future<String> getDefaultBackupDirectoryPath() async {
    final directory = await getAppDataDir();
    final backupDir = Directory(p.join(directory.path, _backupFolderName));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir.path;
  }

  static Future<String> getBackupTempCopyPath() async {
    final tempDir = await getTempDir();
    return p.join(tempDir, 'temp_copy.db');
  }

  static Future<String> getRestoreTempDirectoryPath() async {
    final tempDir = await getTempDir();
    final restoreDir = Directory(p.join(tempDir, 'temp_restore'));
    if (!await restoreDir.exists()) {
      await restoreDir.create(recursive: true);
    }
    return restoreDir.path;
  }

  static Future<String> getStagedRestoreDatabasePath() async {
    final restoreDir = await getRestoreTempDirectoryPath();
    return p.join(restoreDir, 'app.db');
  }

  static Future<String> getPreRestoreSnapshotPath() async {
    final tempDir = await getTempDir();
    return p.join(tempDir, 'pre_restore_snapshot.db');
  }

  static Future<Directory> getAppDataDir() async {
    try {
      final appDir = Directory(_resolveBaseAppDataPath());
      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
      }
      return appDir;
    } catch (error) {
      throw FileSystemException(
        'Could not create application data directory.',
        error.toString(),
      );
    }
  }

  static Future<String> getDatabasePath() async {
    final dir = await getAppDataDir();
    return p.join(dir.path, _dbFileName);
  }

  static Future<String> getLogsPath() async {
    final dir = await getAppDataDir();
    return p.join(dir.path, _logsFileName);
  }

  static Future<String> getTempDir() async {
    final dir = await getAppDataDir();
    final tempDir = Directory(p.join(dir.path, _tempFolderName));

    try {
      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }
      return tempDir.path;
    } catch (error) {
      throw FileSystemException(
        'Could not create temporary directory.',
        error.toString(),
      );
    }
  }

  static Future<bool> healthCheck() async {
    try {
      final appDir = await getAppDataDir();
      final probe = File(p.join(appDir.path, '.healthcheck'));
      await probe.writeAsString(DateTime.now().toIso8601String(), flush: true);
      if (await probe.exists()) {
        await probe.delete();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> debugPrintResolvedPaths() async {
    if (!kDebugMode) return;

    try {
      final appDir = await getAppDataDir();
      final dbPath = await getDatabasePath();
      final logsPath = await getLogsPath();
      final tempPath = await getTempDir();
      debugPrint('[AppPaths] appDir: ${appDir.path}');
      debugPrint('[AppPaths] dbPath: $dbPath');
      debugPrint('[AppPaths] logsPath: $logsPath');
      debugPrint('[AppPaths] tempPath: $tempPath');
    } catch (error) {
      debugPrint('[AppPaths] Failed to resolve paths: $error');
    }
  }

  static String _resolveBaseAppDataPath() {
    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData == null || localAppData.trim().isEmpty) {
        throw const FileSystemException('LOCALAPPDATA not found');
      }
      return '$localAppData\\$_appFolderName';
    }

    final home = Platform.environment['HOME'];
    if (home != null && home.trim().isNotEmpty) {
      return '$home/.local/share/$_appFolderName';
    }

    return '${Directory.systemTemp.path}/$_appFolderName';
  }
}
