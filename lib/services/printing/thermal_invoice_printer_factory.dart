import 'dart:io';

import 'package:delta_erp/services/printing/a4_invoice_printer.dart';
import 'package:delta_erp/services/printing/invoice_print_manager.dart';
import 'package:delta_erp/services/printing/invoice_printer.dart';
import 'package:delta_erp/services/printing/thermal_pdf_invoice_printer.dart';
import 'package:delta_erp/services/printing/thermal_printer_preferences.dart';
import 'package:delta_erp/services/printing/unsupported_invoice_printer.dart';

/// Creates thermal invoice printers — PDF via Windows driver (strip batching).
abstract final class ThermalInvoicePrinterFactory {
  static const _prefs = ThermalPrinterPreferences();

  static InvoicePrinter create({required double paperWidthMm}) {
    if (Platform.isWindows) {
      return ThermalPdfInvoicePrinter(
        paperWidthMm: paperWidthMm,
        printerPrefs: _prefs,
      );
    }
    return UnsupportedInvoicePrinter(
      'Thermal PDF printing is only supported on Windows.',
    );
  }

  static InvoicePrintManager createPrintManager() {
    return InvoicePrintManager(
      a4Printer: const A4InvoicePrinter(),
      thermal58Printer: create(paperWidthMm: 58),
      thermal80Printer: create(paperWidthMm: 80),
    );
  }
}
