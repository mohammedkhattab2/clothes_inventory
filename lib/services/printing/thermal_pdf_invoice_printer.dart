import 'dart:typed_data';

import 'package:delta_erp/features/invoices/domain/invoice_print_model.dart';
import 'package:delta_erp/services/pdf/thermal_invoice_pdf_document.dart';
import 'package:delta_erp/services/printing/invoice_printer.dart';
import 'package:delta_erp/services/printing/thermal_printer_preferences.dart';
import 'package:printing/printing.dart';

/// Concrete thermal printer that generates a narrow receipt-style PDF
/// and sends it to a Windows printer (USB or Bluetooth-paired).
///
/// On first use (or when the saved printer disappears), it falls back to
/// the system print dialog so the user can pick a printer. The selection
/// can be persisted via [ThermalPrinterPreferences] from the settings UI.
class ThermalPdfInvoicePrinter implements InvoicePrinter {
  const ThermalPdfInvoicePrinter({
    required this.paperWidthMm,
    required this.printerPrefs,
  });

  /// 58 or 80 mm paper roll width.
  final double paperWidthMm;

  /// Persistent preferences used to look up the saved printer name.
  final ThermalPrinterPreferences printerPrefs;

  @override
  Future<void> print(InvoicePrintModel invoice) async {
    final pdfBytes = await _buildPdf(invoice);
    final jobName = 'invoice_${invoice.invoiceNumber}';

    // Try to resolve the previously-saved printer first.
    final savedPrinter = await printerPrefs.resolveCurrentPrinter();
    if (savedPrinter != null) {
      await Printing.directPrintPdf(
        printer: savedPrinter,
        onLayout: (_) async => pdfBytes,
        name: jobName,
      );
      return;
    }

    // No saved printer – show the system print dialog as a fallback.
    // The user can later lock a printer in Settings → Thermal Printer.
    final ok = await Printing.layoutPdf(
      name: jobName,
      onLayout: (_) async => pdfBytes,
    );
    if (ok == false) {
      throw StateError('Printing was cancelled.');
    }
  }

  Future<Uint8List> _buildPdf(InvoicePrintModel invoice) async {
    return buildThermalInvoicePdfDocument(
      invoice: invoice,
      paperWidthMm: paperWidthMm,
    );
  }
}
