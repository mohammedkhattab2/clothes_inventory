import 'dart:typed_data';

import 'package:delta_erp/features/invoices/domain/invoice_print_model.dart';
import 'package:delta_erp/services/pdf/invoice_pdf_theme.dart';
import 'package:delta_erp/services/pdf/thermal_invoice_pdf_builder.dart';
import 'package:delta_erp/services/pdf/thermal_invoice_pdf_document.dart';
import 'package:delta_erp/services/printing/invoice_printer.dart';
import 'package:delta_erp/services/printing/print_batch_failure.dart';
import 'package:delta_erp/services/printing/thermal_printer_preferences.dart';
import 'package:delta_erp/services/printing/thermal_printer_presets.dart';
import 'package:delta_erp/services/printing/windows_driver_pdf_print_service.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

/// Sends narrow thermal receipt PDFs through the Windows printer driver.
///
/// Long receipts are split into consecutive ~109 mm strips so the XP-350B
/// driver prints the full invoice without truncating at ~10 cm.
class ThermalPdfInvoicePrinter implements InvoicePrinter {
  ThermalPdfInvoicePrinter({
    required this.paperWidthMm,
    required this.printerPrefs,
    WindowsDriverPdfPrintService? pdfPrintService,
  }) : _pdfPrintService =
            pdfPrintService ?? const WindowsDriverPdfPrintService();

  final double paperWidthMm;
  final ThermalPrinterPreferences printerPrefs;
  final WindowsDriverPdfPrintService _pdfPrintService;

  @override
  Future<void> print(InvoicePrintModel invoice) async {
    final strips = planThermalInvoicePrintStrips(
      invoice: invoice,
      paperWidthMm: paperWidthMm,
    );

    for (var stripIndex = 0; stripIndex < strips.length; stripIndex++) {
      final strip = strips[stripIndex];
      try {
        final pdfBytes = await buildThermalInvoiceStripPdfDocument(
          widgets: strip.widgets,
          paperWidthMm: paperWidthMm,
          pageHeightMm: strip.pageHeightMm,
        );

        if (pdfBytes.length < 32) {
          throw StateError('Invoice PDF payload is too small to print.');
        }

        final suffix = strips.length > 1
            ? '_${stripIndex + 1}of${strips.length}'
            : '';
        final jobName = 'invoice_${invoice.invoiceNumber}$suffix';
        final pageFormat = InvoicePdfTheme.thermalPageFormat(
          paperWidthMm: paperWidthMm,
          pageHeightMm: strip.pageHeightMm,
        );

        await _sendPdfToPrinter(
          bytes: pdfBytes,
          pageFormat: pageFormat,
          jobName: jobName,
        );
      } catch (error) {
        throw PrintBatchFailure(
          completedCopies: stripIndex,
          requestedCopies: strips.length,
          batchIndex: stripIndex + 1,
          batchCount: strips.length,
          cause: error,
        );
      }

      if (stripIndex < strips.length - 1) {
        await Future<void>.delayed(
          Duration(
            milliseconds: ThermalPrinterPresets.invoiceInterBatchDelayMs,
          ),
        );
      }
    }
  }

  Future<void> _sendPdfToPrinter({
    required Uint8List bytes,
    required PdfPageFormat pageFormat,
    required String jobName,
  }) async {
    final savedPrinter = await printerPrefs.resolveCurrentPrinter();
    if (savedPrinter != null) {
      await _pdfPrintService.printDirectPdf(
        printer: savedPrinter,
        printerName: savedPrinter.name,
        jobName: jobName,
        format: pageFormat,
        onLayout: (_) async => bytes,
      );
      return;
    }

    final ok = await Printing.layoutPdf(
      name: jobName,
      onLayout: (_) async => bytes,
      format: pageFormat,
    );
    if (ok != true) {
      throw StateError('Printing was cancelled.');
    }
  }
}
