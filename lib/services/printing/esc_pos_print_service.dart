import 'dart:developer' as dev;
import 'dart:io';
import 'dart:typed_data';

import 'package:delta_erp/services/printing/thermal_printer_preferences.dart';
import 'package:delta_erp/services/printing/windows_raw_printer_service.dart';

/// Sends native ESC/POS bytes to the saved Windows thermal printer queue (RAW).
class EscPosPrintService {
  const EscPosPrintService({
    this.printerPrefs = const ThermalPrinterPreferences(),
    WindowsRawPrinterService? rawPrinter,
  }) : _rawPrinter = rawPrinter ?? const WindowsRawPrinterService();

  final ThermalPrinterPreferences printerPrefs;
  final WindowsRawPrinterService _rawPrinter;

  Future<void> printEscPosBytes({
    required String jobName,
    required Uint8List bytes,
  }) async {
    if (!Platform.isWindows) {
      throw UnsupportedError(
        'ESC/POS RAW printing is only supported on Windows.',
      );
    }
    if (bytes.isEmpty) {
      throw StateError('Print payload is empty.');
    }

    final printerName = await printerPrefs.loadPrinterName();
    if (printerName == null || printerName.isEmpty) {
      throw StateError(
        'No thermal printer configured. Select a printer in Settings.',
      );
    }

    final savedPrinter = await printerPrefs.resolveCurrentPrinter();
    if (savedPrinter == null) {
      throw StateError(
        'Saved thermal printer "$printerName" is not available on this system.',
      );
    }

    if (bytes.length < 16) {
      throw StateError('Print payload is too small to send to the printer.');
    }

    dev.log(
      'ESC/POS payload ready ($jobName, ${bytes.length} bytes)',
      name: 'EscPosPrintService',
    );

    dev.log(
      'Sending ESC/POS RAW job → $printerName',
      name: 'EscPosPrintService',
    );

    await _rawPrinter.printRaw(
      printerName: printerName,
      bytes: bytes,
      documentName: jobName,
    );

    dev.log(
      'Print job completed ($jobName → $printerName)',
      name: 'EscPosPrintService',
    );
  }
}
