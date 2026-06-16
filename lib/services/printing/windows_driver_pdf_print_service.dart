import 'dart:io';
import 'dart:typed_data';

import 'package:delta_erp/services/printing/thermal_printer_preferences.dart';
import 'package:delta_erp/services/printing/windows_print_job_monitor.dart';
import 'package:delta_erp/services/printing/windows_sequential_print_coordinator.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

/// Sends PDF pages through the Windows driver and waits for spooler completion.
class WindowsDriverPdfPrintService {
  const WindowsDriverPdfPrintService({
    this.waitForCompletion = true,
    this.jobTimeout = WindowsPrintJobMonitor.defaultTimeout,
  });

  final bool waitForCompletion;
  final Duration jobTimeout;

  Future<void> printDirectPdf({
    required Printer printer,
    required String printerName,
    required String jobName,
    required PdfPageFormat format,
    required Future<Uint8List> Function(PdfPageFormat format) onLayout,
    bool usePrinterSettings = false,
    bool forceCustomPrintPaper = true,
  }) async {
    final idsBefore = waitForCompletion && Platform.isWindows
        ? await WindowsPrintJobMonitor.snapshotJobIds(printerName)
        : const <int>{};

    final ok = await Printing.directPrintPdf(
      printer: printer,
      onLayout: onLayout,
      format: format,
      name: jobName,
      usePrinterSettings: usePrinterSettings,
      forceCustomPrintPaper: forceCustomPrintPaper,
    );
    if (ok != true) {
      throw StateError('Printing was cancelled or rejected by the driver.');
    }

    if (waitForCompletion && Platform.isWindows) {
      await WindowsSequentialPrintCoordinator.waitForPdfJobCompletion(
        printerName: printerName,
        idsBefore: idsBefore,
        documentName: jobName,
        timeout: jobTimeout,
      );
    }
  }

  Future<void> printDirectPdfBytes({
    required ThermalPrinterPreferences printerPrefs,
    required String jobName,
    required PdfPageFormat format,
    required Uint8List bytes,
  }) async {
    final savedPrinter = await printerPrefs.resolveCurrentPrinter();
    if (savedPrinter == null) {
      throw StateError(
        'No thermal printer configured. Select a printer in Settings.',
      );
    }

    final printerName = savedPrinter.name;
    if (printerName.isEmpty) {
      throw StateError('Saved thermal printer name is empty.');
    }

    await printDirectPdf(
      printer: savedPrinter,
      printerName: printerName,
      jobName: jobName,
      format: format,
      onLayout: (_) async => bytes,
    );
  }
}
