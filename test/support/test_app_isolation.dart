import 'dart:io';

import 'package:delta_erp/core/utils/app_paths.dart';
import 'package:delta_erp/services/database/app_database.dart';
import 'package:delta_erp/services/di/service_locator.dart';

/// Binds [AppPaths] to a unique temp directory, resets [getIt], and runs
/// [setupServiceLocator] so tests never read or wipe the real
/// `%LOCALAPPDATA%\\ClothesInventoryApp\\app.db` (or the Linux/macOS equivalent).
class TestAppIsolation {
  TestAppIsolation._();

  static Directory? _root;

  static Future<void> bootstrap() async {
    await AppDatabase.instance.closeDatabaseForMaintenance();
    await getIt.reset(dispose: false);
    _root = await Directory.systemTemp.createTemp('inventory_unit_test_');
    AppPaths.bindTestApplicationDataRoot(_root!.path);
    await setupServiceLocator();
  }

  static Future<void> shutdown() async {
    await AppDatabase.instance.closeDatabaseForMaintenance();
    AppPaths.clearTestApplicationDataRoot();
    await getIt.reset(dispose: false);
    final root = _root;
    _root = null;
    if (root != null && await root.exists()) {
      await root.delete(recursive: true);
    }
  }
}
