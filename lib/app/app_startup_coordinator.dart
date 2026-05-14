import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:clothes_inventory/core/config/first_run_state_store.dart';
import 'package:clothes_inventory/features/backup/data/backup_lifecycle_service.dart';

class AppStartupCoordinator {
  AppStartupCoordinator({
    required FirstRunStateStore firstRunStateStore,
    required BackupLifecycleService backupLifecycleService,
  }) : _firstRunStateStore = firstRunStateStore,
       _backupLifecycleService = backupLifecycleService;

  final FirstRunStateStore _firstRunStateStore;
  final BackupLifecycleService _backupLifecycleService;

  static const Duration _deferredStartupDelay = Duration(seconds: 6);

  Future<void> runDeferredStartupTasks() async {
    final bool isFirstRun = await _firstRunStateStore.isFirstRun();

    if (isFirstRun) {
      await _firstRunStateStore.markFirstRunCompleted();
      return;
    }

    // Defer non-essential startup work to avoid launch burst activity.
    await Future<void>.delayed(_deferredStartupDelay);

    try {
      await _backupLifecycleService.handleAppStartup();
    } catch (error, stackTrace) {
      assert(() {
        debugPrint('Deferred startup tasks failed: $error\n$stackTrace');
        return true;
      }());
    }
  }
}
