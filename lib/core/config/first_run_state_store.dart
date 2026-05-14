import 'dart:convert';
import 'dart:io';

import 'package:clothes_inventory/core/utils/app_paths.dart';

class FirstRunStateStore {
  static const String _stateFileName = 'runtime_state.json';
  static const String _firstRunCompletedKey = 'first_run_completed';

  Future<bool> isFirstRun() async {
    final state = await _readState();
    return !(state[_firstRunCompletedKey] == true);
  }

  Future<void> markFirstRunCompleted() async {
    final state = await _readState();
    state[_firstRunCompletedKey] = true;
    await _writeState(state);
  }

  Future<Map<String, dynamic>> _readState() async {
    try {
      final file = await _stateFile();
      if (!await file.exists()) {
        return <String, dynamic>{};
      }

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return <String, dynamic>{};
      }

      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _writeState(Map<String, dynamic> state) async {
    try {
      final file = await _stateFile();
      await file.writeAsString(jsonEncode(state), flush: false);
    } catch (_) {
      // Startup state persistence must never crash the app.
    }
  }

  Future<File> _stateFile() async {
    final appDir = await AppPaths.getAppDataDir();
    return File('${appDir.path}${Platform.pathSeparator}$_stateFileName');
  }
}
