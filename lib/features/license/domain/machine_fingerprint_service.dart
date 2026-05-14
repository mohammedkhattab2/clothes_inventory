import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:clothes_inventory/core/utils/app_paths.dart';
import 'package:path/path.dart' as p;

class MachineFingerprintService {
  Future<String> getMachineHash() async {
    final String fingerprint = await _rawFingerprint();
    final Digest digest = sha256.convert(utf8.encode(fingerprint));
    return digest.toString();
  }

  Future<String> getMachineCode() async {
    final String hash = await getMachineHash();
    return hash.substring(0, 24).toUpperCase();
  }

  Future<String> _rawFingerprint() async {
    final String os = Platform.operatingSystem;
    final String osVersion = Platform.operatingSystemVersion;
    final String host = Platform.localHostname;
    final String processors = Platform.numberOfProcessors.toString();

    final String platformId = await _platformMachineId();

    return <String>[os, osVersion, host, processors, platformId].join('|');
  }

  Future<String> _platformMachineId() async {
    try {
      if (Platform.isWindows) {
        final String? cachedId = await _readCachedMachineId();

        final String? queriedId = await _queryWindowsMachineId();
        if (queriedId != null && queriedId.isNotEmpty) {
          await _writeCachedMachineId(queriedId);
          return queriedId;
        }

        if (cachedId != null && cachedId.isNotEmpty) {
          return cachedId;
        }
      }

      if (Platform.isLinux) {
        const String machineIdPath = '/etc/machine-id';
        final File f = File(machineIdPath);
        if (await f.exists()) {
          return (await f.readAsString()).trim();
        }
      }

      if (Platform.isMacOS) {
        final ProcessResult result = await Process.run('ioreg', <String>[
          '-rd1',
          '-c',
          'IOPlatformExpertDevice',
        ]);
        if (result.exitCode == 0) {
          final RegExpMatch? match = RegExp(
            r'IOPlatformUUID"\s*=\s*"([^"]+)"',
          ).firstMatch(result.stdout.toString());
          if (match != null) {
            return match.group(1) ?? '';
          }
        }
      }
    } catch (_) {
      // Fallback below keeps feature resilient in restricted environments.
    }

    return '${Platform.pathSeparator}${Platform.environment['USERNAME'] ?? ''}${Platform.environment['USER'] ?? ''}';
  }

  Future<String?> _queryWindowsMachineId() async {
    final String? wmic = await _queryWindowsMachineIdViaWmic();
    if (wmic != null && wmic.isNotEmpty) {
      return wmic;
    }

    final String? cim = await _queryWindowsMachineIdViaPowerShellCim();
    if (cim != null && cim.isNotEmpty) {
      return cim;
    }

    return null;
  }

  Future<String?> _queryWindowsMachineIdViaWmic() async {
    final ProcessResult result = await Process.run('wmic', <String>[
      'csproduct',
      'get',
      'uuid',
    ]);
    if (result.exitCode != 0) {
      return null;
    }

    final List<String> lines = result.stdout
        .toString()
        .split(RegExp(r'\r?\n'))
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty && e.toLowerCase() != 'uuid')
        .toList(growable: false);
    if (lines.isEmpty) {
      return null;
    }
    return lines.first;
  }

  Future<String?> _queryWindowsMachineIdViaPowerShellCim() async {
    final ProcessResult result = await Process.run('powershell', <String>[
      '-NoProfile',
      '-Command',
      '(Get-CimInstance Win32_ComputerSystemProduct).UUID',
    ]);

    if (result.exitCode != 0) {
      return null;
    }

    final String value = result.stdout.toString().trim();
    if (value.isEmpty || value.toLowerCase() == 'uuid') {
      return null;
    }
    return value;
  }

  Future<String?> _readCachedMachineId() async {
    try {
      final String appDataDir = (await AppPaths.getAppDataDir()).path;
      final File file = File(p.join(appDataDir, 'machine_id.cache'));
      if (!await file.exists()) {
        return null;
      }
      final String value = (await file.readAsString()).trim();
      return value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCachedMachineId(String value) async {
    try {
      final String appDataDir = (await AppPaths.getAppDataDir()).path;
      final File file = File(p.join(appDataDir, 'machine_id.cache'));
      await file.writeAsString(value.trim(), flush: true);
    } catch (_) {
      // Best effort cache write.
    }
  }
}
