import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:clothes_inventory/core/config/company_profile.dart';
import 'package:clothes_inventory/core/config/company_settings.dart';
import 'package:clothes_inventory/services/database/app_database.dart';
import 'package:clothes_inventory/services/database/maintenance_coordinator.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class CompanySettingsService {
  CompanySettingsService(this._appDatabase, this._maintenanceCoordinator);

  final AppDatabase _appDatabase;
  final MaintenanceCoordinator _maintenanceCoordinator;

  static const String _nameKey = 'company_name';
  static const String _addressKey = 'company_address';
  static const String _phonesKey = 'company_phones_json';
  static const String _logoPathKey = 'company_logo_path';

  final ValueNotifier<CompanySettings> _settingsNotifier =
      ValueNotifier<CompanySettings>(_defaults);

  ValueListenable<CompanySettings> get settingsListenable => _settingsNotifier;

  CompanySettings get settings => _settingsNotifier.value;

  static CompanySettings get _defaults => CompanySettings(
    name: CompanyProfile.name,
    address: CompanyProfile.address,
    phoneNumbers: CompanyProfile.phoneNumbers,
  );

  Future<void> initialize() async {
    await _ensureSettingsTable();
    await reload();
  }

  Future<void> reload() async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      'app_settings',
      where: 'key IN (?, ?, ?, ?)',
      whereArgs: const <String>[
        _nameKey,
        _addressKey,
        _phonesKey,
        _logoPathKey,
      ],
    );

    final values = <String, String>{
      for (final row in rows)
        (row['key'] as String): (row['value'] as String?) ?? '',
    };

    final phones = _decodePhones(values[_phonesKey]);

    _settingsNotifier.value = CompanySettings(
      name: _clean(values[_nameKey], fallback: _defaults.name),
      address: _clean(values[_addressKey], fallback: _defaults.address),
      phoneNumbers: phones.isEmpty ? _defaults.phoneNumbers : phones,
      logoPath: _cleanOptional(values[_logoPathKey]),
    );
  }

  Future<void> save({
    required String name,
    required String address,
    required List<String> phoneNumbers,
  }) async {
    _ensureWriteAllowed();
    final cleanedPhones = phoneNumbers
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);

    final effective = CompanySettings(
      name: _clean(name, fallback: _defaults.name),
      address: _clean(address, fallback: _defaults.address),
      phoneNumbers: cleanedPhones.isEmpty
          ? _defaults.phoneNumbers
          : cleanedPhones,
      logoPath: _settingsNotifier.value.logoPath,
    );

    final db = await _appDatabase.database;
    final batch = db.batch();
    batch.insert('app_settings', <String, String>{
      'key': _nameKey,
      'value': effective.name,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert('app_settings', <String, String>{
      'key': _addressKey,
      'value': effective.address,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert('app_settings', <String, String>{
      'key': _phonesKey,
      'value': jsonEncode(effective.phoneNumbers),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    if (effective.logoPath != null && effective.logoPath!.isNotEmpty) {
      batch.insert('app_settings', <String, String>{
        'key': _logoPathKey,
        'value': effective.logoPath!,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);

    _settingsNotifier.value = effective;
  }

  Future<void> setLogoFromPath(String sourcePath) async {
    _ensureWriteAllowed();
    final file = File(sourcePath);
    if (!await file.exists()) {
      throw StateError('Logo file not found.'.toString());
    }

    final dir = await _ensureCompanyAssetsDir();
    final extension = p.extension(file.path).trim();
    final targetPath = p.join(
      dir.path,
      'company_logo${extension.isEmpty ? '.png' : extension}',
    );
    final targetFile = File(targetPath);
    final normalizedSource = p.normalize(file.absolute.path);
    final normalizedTarget = p.normalize(targetFile.absolute.path);
    final isSamePath = normalizedSource == normalizedTarget;

    // Overwrite bytes directly to avoid Windows delete/rename locks.
    if (!isSamePath) {
      final bytes = await file.readAsBytes();
      await targetFile.writeAsBytes(bytes, flush: true);
    }

    final db = await _appDatabase.database;
    await db.insert('app_settings', <String, String>{
      'key': _logoPathKey,
      'value': targetPath,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    _settingsNotifier.value = _settingsNotifier.value.copyWith(
      logoPath: targetPath,
    );
  }

  Future<void> clearLogo() async {
    _ensureWriteAllowed();
    final existing = _settingsNotifier.value.logoPath;
    if (existing != null && existing.trim().isNotEmpty) {
      final file = File(existing);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {
          // Keep clearing DB setting even if file removal is blocked by OS lock.
        }
      }
    }

    final db = await _appDatabase.database;
    await db.delete(
      'app_settings',
      where: 'key = ?',
      whereArgs: [_logoPathKey],
    );

    _settingsNotifier.value = _settingsNotifier.value.copyWith(logoPath: null);
  }

  Future<Uint8List?> loadLogoBytes({bool includeFallbackAsset = true}) async {
    final logoPath = _settingsNotifier.value.logoPath;
    if (logoPath != null && logoPath.trim().isNotEmpty) {
      final file = File(logoPath);
      if (await file.exists()) {
        return file.readAsBytes();
      }
    }

    if (!includeFallbackAsset) return null;

    try {
      final data = await rootBundle.load('assets/icon/app_icon.png');
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<Directory> _ensureCompanyAssetsDir() async {
    final baseDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(baseDir.path, 'company_assets'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> _ensureSettingsTable() async {
    final db = await _appDatabase.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  List<String> _decodePhones(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return const <String>[];
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is List) {
        return decoded
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      }
    } catch (_) {
      // Keep compatibility with older plain-text values.
      return rawValue
          .split(RegExp(r'\s*[-,\n]\s*'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    return const <String>[];
  }

  String _clean(String? input, {required String fallback}) {
    final value = (input ?? '').trim();
    return value.isEmpty ? fallback : value;
  }

  String? _cleanOptional(String? input) {
    final value = (input ?? '').trim();
    return value.isEmpty ? null : value;
  }

  void _ensureWriteAllowed() {
    if (_maintenanceCoordinator.isMaintenanceMode) {
      throw StateError('Database write is blocked during maintenance mode.');
    }
  }
}
