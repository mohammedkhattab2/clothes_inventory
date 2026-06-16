import 'package:delta_erp/features/invoices/domain/invoice_print_model.dart';
import 'package:delta_erp/services/printing/invoice_print_manager.dart';
import 'package:delta_erp/services/printing/invoice_print_preferences.dart';
import 'package:delta_erp/services/printing/invoice_printer.dart';
import 'package:delta_erp/services/printing/thermal_printer_preferences.dart';

/// Sends an invoice to the saved Windows thermal printer via driver PDF.
Future<void> printInvoiceToSavedPrinter({
  required InvoicePrintManager printManager,
  required InvoicePrintModel invoice,
}) async {
  const thermalPrefs = ThermalPrinterPreferences();
  final savedPrinter = await thermalPrefs.resolveCurrentPrinter();
  if (savedPrinter == null) {
    throw StateError(
      'No thermal printer configured. Select a printer in Settings.',
    );
  }

  const preferences = InvoicePrintPreferences();
  final config = await preferences.load();
  final thermalName = await thermalPrefs.loadPrinterName();
  final effectiveConfig = thermalName != null && thermalName.isNotEmpty
      ? InvoicePrintConfiguration(
          printerType: PrinterType.thermal80,
          printerSupportsArabic: config.printerSupportsArabic,
          useImageFallback: false,
        )
      : config;

  await printManager.printInvoice(invoice, effectiveConfig);
}
