import 'package:delta_erp/features/invoices/domain/invoice_print_model.dart';
import 'package:delta_erp/services/printing/esc_pos_invoice_builder.dart';
import 'package:delta_erp/services/printing/esc_pos_print_service.dart';
import 'package:delta_erp/services/printing/invoice_print_preferences.dart';
import 'package:delta_erp/services/printing/invoice_printer.dart';
import 'package:delta_erp/services/printing/thermal_printer_preferences.dart';

/// Windows thermal invoices via native ESC/POS text → one RAW spooler job.
///
/// Used instead of PDF strips because the XP-350B driver truncates each PDF
/// job at ~109 mm; ESC/POS prints the full continuous 80 mm receipt.
class ThermalEscPosInvoicePrinter implements InvoicePrinter {
  ThermalEscPosInvoicePrinter({
    required this.paperWidthMm,
    required this.printerPrefs,
    EscPosPrintService? printService,
    InvoicePrintPreferences? invoicePrefs,
  })  : _printService =
            printService ?? EscPosPrintService(printerPrefs: printerPrefs),
        _invoicePrefs = invoicePrefs ?? const InvoicePrintPreferences();

  final double paperWidthMm;
  final ThermalPrinterPreferences printerPrefs;
  final EscPosPrintService _printService;
  final InvoicePrintPreferences _invoicePrefs;

  @override
  Future<void> print(InvoicePrintModel invoice) async {
    final config = await _invoicePrefs.load();
    final bytes = await EscPosInvoiceBuilder.build(
      invoice: invoice,
      paperWidthMm: paperWidthMm,
      printerSupportsArabic: config.printerSupportsArabic,
      preferImageFallback: false,
    );

    await _printService.printEscPosBytes(
      jobName: 'invoice_${invoice.invoiceNumber}',
      bytes: bytes,
    );
  }
}
