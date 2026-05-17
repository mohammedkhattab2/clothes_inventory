part of 'backup_cubit.dart';

enum BackupStatus { idle, loading, success, error }

class BackupState extends Equatable {
  const BackupState({
    this.status = BackupStatus.idle,
    this.message,
    this.errorCode,
    this.operationMeta,
    this.lastBackupPath,
    this.lastBackupAt,
    this.lastBackupSizeBytes,
    this.isHealthy = false,
    this.autoBackupEnabled = true,
    this.debounceThresholdMinutes = 60,
    this.retentionCount = 5,
    this.isNetworkMode = false,
    this.backupDirectory,
    this.backupHistory = const <BackupSummary>[],
    this.lastAutoBackupResult,
  });

  final BackupStatus status;
  final String? message;
  final String? errorCode;
  final Map<String, dynamic>? operationMeta;
  final String? lastBackupPath;
  final DateTime? lastBackupAt;
  final int? lastBackupSizeBytes;
  final bool isHealthy;
  final bool autoBackupEnabled;
  final int debounceThresholdMinutes;
  final int retentionCount;
  final bool isNetworkMode;
  final String? backupDirectory;
  final List<BackupSummary> backupHistory;
  final AutoBackupLastResult? lastAutoBackupResult;

  BackupState copyWith({
    BackupStatus? status,
    String? message,
    String? errorCode,
    Map<String, dynamic>? operationMeta,
    String? lastBackupPath,
    DateTime? lastBackupAt,
    int? lastBackupSizeBytes,
    bool? isHealthy,
    bool? autoBackupEnabled,
    int? debounceThresholdMinutes,
    int? retentionCount,
    bool? isNetworkMode,
    String? backupDirectory,
    List<BackupSummary>? backupHistory,
    AutoBackupLastResult? lastAutoBackupResult,
    bool clearMeta = false,
  }) {
    return BackupState(
      status: status ?? this.status,
      message: message,
      errorCode: errorCode,
      operationMeta: clearMeta ? null : (operationMeta ?? this.operationMeta),
      lastBackupPath: lastBackupPath ?? this.lastBackupPath,
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
      lastBackupSizeBytes: lastBackupSizeBytes ?? this.lastBackupSizeBytes,
      isHealthy: isHealthy ?? this.isHealthy,
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      debounceThresholdMinutes:
          debounceThresholdMinutes ?? this.debounceThresholdMinutes,
      retentionCount: retentionCount ?? this.retentionCount,
      isNetworkMode: isNetworkMode ?? this.isNetworkMode,
      backupDirectory: backupDirectory ?? this.backupDirectory,
      backupHistory: backupHistory ?? this.backupHistory,
      lastAutoBackupResult:
          lastAutoBackupResult ?? this.lastAutoBackupResult,
    );
  }

  @override
  List<Object?> get props => [
    status,
    message,
    errorCode,
    operationMeta,
    lastBackupPath,
    lastBackupAt,
    lastBackupSizeBytes,
    isHealthy,
    autoBackupEnabled,
    debounceThresholdMinutes,
    retentionCount,
    isNetworkMode,
    backupDirectory,
    backupHistory,
    lastAutoBackupResult,
  ];
}
