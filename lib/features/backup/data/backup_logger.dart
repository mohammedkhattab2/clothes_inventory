import 'dart:developer' as dev;

class BackupLogger {
  const BackupLogger();

  void info(String event, Map<String, Object?> payload) {
    dev.log('$event | $payload', name: 'BackupRestore');
  }

  void warn(String event, Map<String, Object?> payload) {
    dev.log('$event | $payload', name: 'BackupRestoreWarning');
  }

  void error(
    String event,
    Object error,
    StackTrace stackTrace,
    Map<String, Object?> payload,
  ) {
    dev.log(
      '$event | $payload',
      name: 'BackupRestoreError',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
