import 'dart:async';

class MaintenanceCoordinator {
  bool _isMaintenanceMode = false;
  String? _activeOperation;
  Completer<void>? _operationCompleter;

  bool get isMaintenanceMode => _isMaintenanceMode;
  String? get activeOperation => _activeOperation;

  bool get isOperationRunning => _activeOperation != null;

  Future<T> runExclusive<T>(
    String operation,
    Future<T> Function() action,
  ) async {
    if (_activeOperation != null) {
      throw StateError(
        'Another maintenance operation is running: $_activeOperation',
      );
    }

    _activeOperation = operation;
    _operationCompleter = Completer<void>();
    try {
      return await action();
    } finally {
      _activeOperation = null;
      _operationCompleter?.complete();
      _operationCompleter = null;
    }
  }

  Future<void> waitForActiveOperation() async {
    await _operationCompleter?.future;
  }

  void enterMaintenanceMode() {
    _isMaintenanceMode = true;
  }

  void exitMaintenanceMode() {
    _isMaintenanceMode = false;
  }
}
