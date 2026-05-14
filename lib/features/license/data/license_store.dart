import 'dart:io';

import 'package:clothes_inventory/core/utils/app_paths.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LicenseStore {
  static const String _fileName = 'offline_license.json';
  static const String _lastTrustedTimeKey = 'license_last_trusted_utc';
  static const String _activationLogsKey = 'license_activation_logs';
  static const String _trialStartedAtKey = 'trial_started_at_utc';
  static const String _trialMarkerFileName = 'trial_start.marker';
  static const String _trialProofKey = 'trial_proof_v1';
  static const String _trialProofFileName = 'trial_proof.marker';
  static const String _trialLockedKey = 'trial_locked';
  static const String _trialLockedFileName = 'trial_locked.marker';
  static const String _trialRegistryPath = r'HKCU\Software\ClothesInventoryApp';
  static const String _trialRegistryValue = 'TrialStartedAtUtc';
  static const String _trialProofRegistryValue = 'TrialProofV1';
  static const String _trialLockedRegistryValue = 'TrialLocked';
  static const int _maxActivationLogs = 5;

  Future<File> _licenseFile() async {
    final Directory dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    final String filePath = p.join(dir.path, _fileName);
    return File(filePath);
  }

  Future<String?> loadRawLicense() async {
    final File file = await _licenseFile();
    if (!await file.exists()) {
      return null;
    }
    return file.readAsString();
  }

  Future<void> saveRawLicense(String raw) async {
    final File file = await _licenseFile();
    await file.writeAsString(raw, flush: true);
  }

  Future<void> clearLicense() async {
    final File file = await _licenseFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<DateTime?> loadLastTrustedTimeUtc() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_lastTrustedTimeKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toUtc();
  }

  Future<void> saveLastTrustedTimeUtc(DateTime value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastTrustedTimeKey, value.toUtc().toIso8601String());
  }

  Future<List<String>> loadActivationLogsRaw() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String>? logs = prefs.getStringList(_activationLogsKey);
    return logs ?? const <String>[];
  }

  Future<void> appendActivationLogRaw(String entryJson) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> current =
        prefs.getStringList(_activationLogsKey)?.toList() ?? <String>[];
    current.insert(0, entryJson);
    if (current.length > _maxActivationLogs) {
      current.removeRange(_maxActivationLogs, current.length);
    }
    await prefs.setStringList(_activationLogsKey, current);
  }

  Future<DateTime?> loadTrialStartedAtUtc() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final DateTime? fromPrefs = _parseUtc(prefs.getString(_trialStartedAtKey));
    final DateTime? fromMarker = await _loadTrialStartedAtFromFileUtc();
    final DateTime? fromRegistry = await _loadTrialStartedAtFromRegistryUtc();

    final List<DateTime> candidates = <DateTime?>[
      fromPrefs,
      fromMarker,
      fromRegistry,
    ].whereType<DateTime>().toList(growable: false);
    if (candidates.isEmpty) {
      return null;
    }

    // Choosing the oldest source prevents extending trial by editing one source.
    candidates.sort();
    final DateTime canonical = candidates.first;
    await _syncTrialStartAcrossStores(canonical);
    return canonical;
  }

  Future<DateTime> ensureTrialStartedAtUtc() async {
    final DateTime? existing = await loadTrialStartedAtUtc();
    if (existing != null) {
      return existing;
    }

    final DateTime nowUtc = DateTime.now().toUtc();
    await saveTrialStartedAtUtc(nowUtc);
    return nowUtc;
  }

  Future<void> saveTrialStartedAtUtc(DateTime value) async {
    final String iso = value.toUtc().toIso8601String();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_trialStartedAtKey, iso);

    final File marker = await _trialMarkerFile();
    final Directory parent = marker.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    await marker.writeAsString(iso, flush: true);

    await _saveTrialStartedAtToRegistry(iso);
  }

  Future<String?> loadTrialProof() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? fromPrefs = _normalizeString(prefs.getString(_trialProofKey));
    final String? fromFile = await _loadStringFromAppDataFile(
      _trialProofFileName,
    );
    final String? fromRegistry = await _loadStringFromRegistry(
      _trialProofRegistryValue,
    );

    final List<String> values = <String?>[
      fromPrefs,
      fromFile,
      fromRegistry,
    ].whereType<String>().toList(growable: false);

    if (values.isEmpty) {
      return null;
    }

    final Set<String> distinct = values.toSet();
    if (distinct.length > 1) {
      return '__CONFLICT__';
    }

    final String canonical = values.first;
    await saveTrialProof(canonical);
    return canonical;
  }

  Future<void> saveTrialProof(String proof) async {
    final String normalized = proof.trim();
    if (normalized.isEmpty) {
      return;
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_trialProofKey, normalized);
    await _saveStringToAppDataFile(_trialProofFileName, normalized);
    await _saveStringToRegistry(_trialProofRegistryValue, normalized);
  }

  Future<bool> loadTrialLocked() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool? fromPrefs = prefs.getBool(_trialLockedKey);
    final bool? fromFile = _parseBool(
      await _loadStringFromAppDataFile(_trialLockedFileName),
    );
    final bool? fromRegistry = _parseBool(
      await _loadStringFromRegistry(_trialLockedRegistryValue),
    );

    final bool canonical =
        (fromPrefs ?? false) || (fromFile ?? false) || (fromRegistry ?? false);

    await saveTrialLocked(canonical);
    return canonical;
  }

  Future<void> saveTrialLocked(bool locked) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_trialLockedKey, locked);
    final String value = locked ? '1' : '0';
    await _saveStringToAppDataFile(_trialLockedFileName, value);
    await _saveStringToRegistry(_trialLockedRegistryValue, value);
  }

  Future<DateTime?> _loadTrialStartedAtFromFileUtc() async {
    final File marker = await _trialMarkerFile();
    if (!await marker.exists()) {
      return null;
    }
    final String raw = await marker.readAsString();
    return _parseUtc(raw);
  }

  Future<DateTime?> _loadTrialStartedAtFromRegistryUtc() async {
    if (!Platform.isWindows) {
      return null;
    }

    try {
      final ProcessResult result = await Process.run('reg', <String>[
        'query',
        _trialRegistryPath,
        '/v',
        _trialRegistryValue,
      ]);

      if (result.exitCode != 0) {
        return null;
      }

      final String output = result.stdout.toString();
      final RegExp regex = RegExp(
        '${RegExp.escape(_trialRegistryValue)}\\s+REG_SZ\\s+(.+)',
      );
      final RegExpMatch? match = regex.firstMatch(output);
      if (match == null) {
        return null;
      }

      return _parseUtc(match.group(1));
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveTrialStartedAtToRegistry(String iso) async {
    if (!Platform.isWindows) {
      return;
    }

    try {
      await Process.run('reg', <String>[
        'add',
        _trialRegistryPath,
        '/v',
        _trialRegistryValue,
        '/t',
        'REG_SZ',
        '/d',
        iso,
        '/f',
      ]);
    } catch (_) {
      // Best effort only.
    }
  }

  Future<String?> _loadStringFromRegistry(String valueName) async {
    if (!Platform.isWindows) {
      return null;
    }

    try {
      final ProcessResult result = await Process.run('reg', <String>[
        'query',
        _trialRegistryPath,
        '/v',
        valueName,
      ]);

      if (result.exitCode != 0) {
        return null;
      }

      final String output = result.stdout.toString();
      final RegExp regex = RegExp(
        '${RegExp.escape(valueName)}\\s+REG_SZ\\s+(.+)',
      );
      final RegExpMatch? match = regex.firstMatch(output);
      if (match == null) {
        return null;
      }
      return _normalizeString(match.group(1));
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveStringToRegistry(String valueName, String value) async {
    if (!Platform.isWindows) {
      return;
    }

    try {
      await Process.run('reg', <String>[
        'add',
        _trialRegistryPath,
        '/v',
        valueName,
        '/t',
        'REG_SZ',
        '/d',
        value,
        '/f',
      ]);
    } catch (_) {
      // Best effort only.
    }
  }

  Future<String?> _loadStringFromAppDataFile(String fileName) async {
    try {
      final Directory appDataDir = await AppPaths.getAppDataDir();
      final File file = File(p.join(appDataDir.path, fileName));
      if (!await file.exists()) {
        return null;
      }
      final String raw = await file.readAsString();
      return _normalizeString(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveStringToAppDataFile(String fileName, String value) async {
    try {
      final Directory appDataDir = await AppPaths.getAppDataDir();
      final File file = File(p.join(appDataDir.path, fileName));
      final Directory parent = file.parent;
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }
      await file.writeAsString(value, flush: true);
    } catch (_) {
      // Best effort only.
    }
  }

  Future<void> _syncTrialStartAcrossStores(DateTime value) async {
    final String iso = value.toUtc().toIso8601String();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_trialStartedAtKey, iso);

    final File marker = await _trialMarkerFile();
    final Directory parent = marker.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    await marker.writeAsString(iso, flush: true);

    await _saveTrialStartedAtToRegistry(iso);
  }

  Future<File> _trialMarkerFile() async {
    final Directory appDataDir = await AppPaths.getAppDataDir();
    return File(p.join(appDataDir.path, _trialMarkerFileName));
  }

  DateTime? _parseUtc(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toUtc();
  }

  bool? _parseBool(String? raw) {
    final String? normalized = _normalizeString(raw)?.toLowerCase();
    if (normalized == null) {
      return null;
    }
    if (normalized == '1' || normalized == 'true') {
      return true;
    }
    if (normalized == '0' || normalized == 'false') {
      return false;
    }
    return null;
  }

  String? _normalizeString(String? value) {
    if (value == null) {
      return null;
    }
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
