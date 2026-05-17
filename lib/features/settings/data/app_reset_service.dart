import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:delta_erp/core/utils/app_paths.dart';
import 'package:delta_erp/services/database/app_database.dart';
import 'package:delta_erp/services/database/maintenance_coordinator.dart';

class AppResetResult {
  const AppResetResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class AppResetService {
  const AppResetService({
    required AppDatabase appDatabase,
    required MaintenanceCoordinator maintenanceCoordinator,
  }) : _appDatabase = appDatabase,
       _maintenanceCoordinator = maintenanceCoordinator;

  final AppDatabase _appDatabase;
  final MaintenanceCoordinator _maintenanceCoordinator;

  Future<AppResetResult> resetApplicationData() async {
    if (_maintenanceCoordinator.isOperationRunning ||
        _maintenanceCoordinator.isMaintenanceMode) {
      return const AppResetResult(
        success: false,
        message:
            'Cannot reset while a critical operation is running. Please try again later.',
      );
    }

    try {
      final appDataDir = await AppPaths.getAppDataDir();
      final appDataPath = p.normalize(appDataDir.path);
      final dbPath = p.normalize(await AppPaths.getDatabasePath());
      final logsPath = p.normalize(await AppPaths.getLogsPath());
      final tempPath = p.normalize(await AppPaths.getTempDir());

      if (!_isPathInsideAppData(appDataPath, dbPath) ||
          !_isPathInsideAppData(appDataPath, logsPath) ||
          !_isPathInsideAppData(appDataPath, tempPath)) {
        return const AppResetResult(
          success: false,
          message:
              'Safety check failed. Reset paths are outside AppData and were blocked.',
        );
      }

      await _writeResetLog(logsPath);

      await _appDatabase.closeDatabaseForMaintenance();

      if (await appDataDir.exists()) {
        await appDataDir.delete(recursive: true);
      }

      return const AppResetResult(
        success: true,
        message: 'Application data deleted successfully.',
      );
    } catch (error) {
      return AppResetResult(success: false, message: 'Reset failed: $error');
    }
  }

  Future<void> restartApplication() async {
    if (!Platform.isWindows) {
      throw const ProcessException(
        'restart',
        <String>[],
        'Automatic restart is only supported on Windows.',
      );
    }

    final currentExecutable = File(Platform.resolvedExecutable);
    final appExecutable = await _resolveWindowsAppExecutable(currentExecutable);
    final args = appExecutable.path == currentExecutable.path
        ? List<String>.from(Platform.executableArguments)
        : const <String>[];

    await Process.start(
      appExecutable.path,
      args,
      mode: ProcessStartMode.detached,
      workingDirectory: appExecutable.parent.path,
    );

    exit(0);
  }

  Future<File> _resolveWindowsAppExecutable(File currentExecutable) async {
    final exeDir = currentExecutable.parent;
    final directCandidate = File(p.join(exeDir.path, 'DeltaErp.exe'));
    if (await directCandidate.exists()) {
      return directCandidate;
    }

    final siblingCandidates = await exeDir
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .where(
          (file) =>
              p.extension(file.path).toLowerCase() == '.exe' &&
              p.basename(file.path).toLowerCase() !=
                  p.basename(currentExecutable.path).toLowerCase(),
        )
        .toList();

    if (siblingCandidates.isNotEmpty) {
      return siblingCandidates.first;
    }

    return currentExecutable;
  }

  bool _isPathInsideAppData(String appDataPath, String candidatePath) {
    if (p.equals(appDataPath, candidatePath)) {
      return true;
    }
    return p.isWithin(appDataPath, candidatePath);
  }

  Future<void> _writeResetLog(String logsPath) async {
    try {
      final logFile = File(logsPath);
      await logFile.parent.create(recursive: true);
      final now = DateTime.now().toIso8601String();
      await logFile.writeAsString(
        '[$now] Factory reset requested by user.\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // Ignore logging failure to keep reset path resilient.
    }
  }
}
