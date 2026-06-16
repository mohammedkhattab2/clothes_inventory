import 'dart:io';

import 'package:delta_erp/services/printing/windows_print_job_monitor.dart';

/// Waits for each Windows driver PDF job to finish before the next one is sent.
abstract final class WindowsSequentialPrintCoordinator {
  static const spoolerRegisterDelay = Duration(milliseconds: 150);

  /// Waits until [documentName] appears in the spooler, completes, and the
  /// queue becomes idle again.
  static Future<void> waitForPdfJobCompletion({
    required String printerName,
    required Set<int> idsBefore,
    required String documentName,
    Duration timeout = WindowsPrintJobMonitor.defaultTimeout,
  }) async {
    if (!Platform.isWindows) return;

    await Future<void>.delayed(spoolerRegisterDelay);
    await WindowsPrintJobMonitor.waitForSubmittedJob(
      printerName: printerName,
      idsBefore: idsBefore,
      documentName: documentName,
      timeout: timeout,
    );
    await WindowsPrintJobMonitor.waitUntilQueueIdle(
      printerName: printerName,
      timeout: timeout,
    );
  }
}
