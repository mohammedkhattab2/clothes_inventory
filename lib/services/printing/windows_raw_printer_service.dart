import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:delta_erp/services/printing/windows_print_job_monitor.dart';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Sends ESC/POS (or other) bytes directly to a Windows printer queue as RAW.
///
/// Waits for the spooler job to finish so callers only succeed after the OS
/// accepts and completes handoff to the printer driver.
class WindowsRawPrinterService {
  const WindowsRawPrinterService({
    this.waitForCompletion = true,
    this.jobTimeout = WindowsPrintJobMonitor.defaultTimeout,
  });

  final bool waitForCompletion;
  final Duration jobTimeout;

  Future<void> printRaw({
    required String printerName,
    required Uint8List bytes,
    String documentName = 'DeltaERP Receipt',
  }) async {    if (!Platform.isWindows) {
      throw UnsupportedError('RAW printing is only supported on Windows.');
    }
    if (bytes.isEmpty) {
      throw ArgumentError('Print payload is empty.');
    }

    final printerNamePtr = printerName.toNativeUtf16();
    final printerHandlePtr = calloc<IntPtr>();

    try {
      if (OpenPrinter(printerNamePtr, printerHandlePtr, nullptr) == 0) {
        throw StateError(
          'OpenPrinter failed (error ${GetLastError()}) for "$printerName".',
        );
      }

      final hPrinter = printerHandlePtr.value;
      final docNamePtr = documentName.toNativeUtf16();
      final dataTypePtr = 'RAW'.toNativeUtf16();
      final docInfo = calloc<DOC_INFO_1>();
      docInfo.ref
        ..pDocName = docNamePtr
        ..pOutputFile = nullptr
        ..pDatatype = dataTypePtr;

      try {
        final jobId = StartDocPrinter(hPrinter, 1, docInfo);
        if (jobId == 0) {
          throw StateError('StartDocPrinter failed (error ${GetLastError()}).');
        }

        try {
          if (StartPagePrinter(hPrinter) == 0) {
            throw StateError(
              'StartPagePrinter failed (error ${GetLastError()}).',
            );
          }

          try {
            _writeBytes(hPrinter, bytes);
          } finally {
            EndPagePrinter(hPrinter);
          }
        } finally {
          EndDocPrinter(hPrinter);
        }

        if (waitForCompletion) {
          await WindowsPrintJobMonitor.waitForCompletion(
            printerName: printerName,
            jobId: jobId,
            timeout: jobTimeout,
          );
        }
      } finally {        calloc.free(docInfo);
        calloc.free(docNamePtr);
        calloc.free(dataTypePtr);
      }
    } finally {
      if (printerHandlePtr.value != 0) {
        ClosePrinter(printerHandlePtr.value);
      }
      calloc.free(printerHandlePtr);
      calloc.free(printerNamePtr);
    }
  }

  void _writeBytes(int hPrinter, Uint8List bytes) {
    final buffer = calloc<Uint8>(bytes.length);
    final written = calloc<Uint32>();
    try {
      buffer.asTypedList(bytes.length).setAll(0, bytes);
      final ok = WritePrinter(
        hPrinter,
        buffer.cast(),
        bytes.length,
        written,
      );
      if (ok == 0 || written.value != bytes.length) {
        throw StateError(
          'WritePrinter failed (error ${GetLastError()}, '
          'wrote ${written.value}/${bytes.length}).',
        );
      }
    } finally {
      calloc.free(buffer);
      calloc.free(written);
    }
  }
}
