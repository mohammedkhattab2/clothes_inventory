class OperationResult {
  const OperationResult({
    required this.success,
    required this.message,
    this.errorCode,
    this.meta,
  });

  final bool success;
  final String message;
  final String? errorCode;
  final Map<String, dynamic>? meta;

  factory OperationResult.ok(String message, {Map<String, dynamic>? meta}) {
    return OperationResult(success: true, message: message, meta: meta);
  }

  factory OperationResult.fail(
    String message, {
    String? errorCode,
    Map<String, dynamic>? meta,
  }) {
    return OperationResult(
      success: false,
      message: message,
      errorCode: errorCode,
      meta: meta,
    );
  }
}

abstract final class BackupErrorCodes {
  static const String fileNotFound = 'file_not_found';
  static const String permissionDenied = 'permission_denied';
  static const String diskFull = 'disk_full';
  static const String dbLocked = 'db_locked';
  static const String invalidBackup = 'invalid_backup';
  static const String integrityFailed = 'integrity_failed';
  static const String rollbackFailed = 'rollback_failed';
  static const String incompatibleVersion = 'incompatible_version';
  static const String fileLocked = 'file_locked';
  static const String unknownError = 'unknown_error';
}

class BackupMetadata {
  const BackupMetadata({
    required this.appVersion,
    required this.dbVersion,
    required this.createdAt,
    required this.checksum,
    required this.device,
    this.lastSyncAt,
    this.isFullBackup = true,
    this.isNetworkMode = false,
    this.signature,
    this.signatureAlgorithm,
  });

  final String appVersion;
  final int dbVersion;
  final DateTime createdAt;
  final String checksum;
  final String device;
  final DateTime? lastSyncAt;
  final bool isFullBackup;
  final bool isNetworkMode;
  final String? signature;
  final String? signatureAlgorithm;

  Map<String, dynamic> toJson() {
    return {
      'appVersion': appVersion,
      'dbVersion': dbVersion,
      'createdAt': createdAt.toIso8601String(),
      'checksum': checksum,
      'device': device,
      'lastSyncAt': lastSyncAt?.toIso8601String(),
      'isFullBackup': isFullBackup,
      'isNetworkMode': isNetworkMode,
      'signature': signature,
      'signatureAlgorithm': signatureAlgorithm,
    };
  }

  factory BackupMetadata.fromJson(Map<String, dynamic> json) {
    return BackupMetadata(
      appVersion: (json['appVersion'] as String?) ?? 'unknown',
      dbVersion: (json['dbVersion'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      checksum: (json['checksum'] as String?) ?? '',
      device: (json['device'] as String?) ?? 'unknown',
      lastSyncAt: DateTime.tryParse((json['lastSyncAt'] as String?) ?? ''),
      isFullBackup: (json['isFullBackup'] as bool?) ?? true,
      isNetworkMode: (json['isNetworkMode'] as bool?) ?? false,
      signature: json['signature'] as String?,
      signatureAlgorithm: json['signatureAlgorithm'] as String?,
    );
  }
}

class BackupValidationReport {
  const BackupValidationReport({
    required this.fileExists,
    required this.fileSizeBytes,
    required this.zipReadable,
    required this.metadataReadable,
    required this.containsDatabaseFile,
    required this.checksumValid,
    required this.integrityOk,
    this.error,
  });

  final bool fileExists;
  final int fileSizeBytes;
  final bool zipReadable;
  final bool metadataReadable;
  final bool containsDatabaseFile;
  final bool checksumValid;
  final bool integrityOk;
  final String? error;

  bool get isValid {
    return fileExists &&
        fileSizeBytes > 0 &&
        zipReadable &&
        metadataReadable &&
        containsDatabaseFile &&
        checksumValid &&
        integrityOk;
  }

  Map<String, dynamic> toJson() {
    return {
      'fileExists': fileExists,
      'fileSizeBytes': fileSizeBytes,
      'zipReadable': zipReadable,
      'metadataReadable': metadataReadable,
      'containsDatabaseFile': containsDatabaseFile,
      'checksumValid': checksumValid,
      'integrityOk': integrityOk,
      'error': error,
    };
  }
}

class RestoreReport {
  const RestoreReport({
    required this.restoreSucceeded,
    required this.rollbackAttempted,
    required this.rollbackSucceeded,
    required this.requiresRestart,
    this.details,
  });

  final bool restoreSucceeded;
  final bool rollbackAttempted;
  final bool rollbackSucceeded;
  final bool requiresRestart;
  final String? details;

  Map<String, dynamic> toJson() {
    return {
      'restoreSucceeded': restoreSucceeded,
      'rollbackAttempted': rollbackAttempted,
      'rollbackSucceeded': rollbackSucceeded,
      'requiresRestart': requiresRestart,
      'details': details,
    };
  }
}

class BackupSummary {
  const BackupSummary({
    required this.path,
    required this.createdAt,
    required this.sizeBytes,
  });

  final String path;
  final DateTime createdAt;
  final int sizeBytes;

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'createdAt': createdAt.toIso8601String(),
      'sizeBytes': sizeBytes,
    };
  }

  factory BackupSummary.fromJson(Map<String, dynamic> json) {
    return BackupSummary(
      path: (json['path'] as String?) ?? '',
      createdAt:
          DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }
}

class BackupSettings {
  const BackupSettings({
    required this.autoBackupEnabled,
    required this.debounceThresholdMinutes,
    required this.retentionCount,
    required this.isNetworkMode,
    this.backupDirectory,
  });

  final bool autoBackupEnabled;
  final int debounceThresholdMinutes;
  final int retentionCount;
  final bool isNetworkMode;
  final String? backupDirectory;

  BackupSettings copyWith({
    bool? autoBackupEnabled,
    int? debounceThresholdMinutes,
    int? retentionCount,
    bool? isNetworkMode,
    String? backupDirectory,
  }) {
    return BackupSettings(
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      debounceThresholdMinutes:
          debounceThresholdMinutes ?? this.debounceThresholdMinutes,
      retentionCount: retentionCount ?? this.retentionCount,
      isNetworkMode: isNetworkMode ?? this.isNetworkMode,
      backupDirectory: backupDirectory ?? this.backupDirectory,
    );
  }
}
