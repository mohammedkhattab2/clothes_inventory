import 'package:delta_erp/features/invoices/domain/invoice_print_model.dart';
import 'package:delta_erp/services/pdf/thermal_invoice_pdf_document.dart';
import 'package:delta_erp/services/printing/esc_pos_print_service.dart';
import 'package:delta_erp/services/printing/esc_pos_raster_job_builder.dart';
import 'package:delta_erp/services/printing/invoice_printer.dart';
import 'package:delta_erp/services/printing/thermal_printer_preferences.dart';

/// Windows thermal invoices via one continuous ESC/POS raster RAW job.
class ThermalRasterInvoicePrinter implements InvoicePrinter {
  ThermalRasterInvoicePrinter({
    required this.paperWidthMm,
    required this.printerPrefs,
    EscPosPrintService? printService,
    EscPosRasterPdfJobBuilder? rasterJobBuilder,
  }) : _printService =
           printService ?? EscPosPrintService(printerPrefs: printerPrefs),
       _rasterJobBuilder =
           rasterJobBuilder ?? EscPosRasterJobBuilder.buildFromPdf;

  final double paperWidthMm;
  final ThermalPrinterPreferences printerPrefs;
  final EscPosPrintService _printService;
  final EscPosRasterPdfJobBuilder _rasterJobBuilder;

  @override
  Future<void> print(InvoicePrintModel invoice) async {
    final pdfBytes = await buildThermalInvoicePdfDocument(
      invoice: invoice,
      paperWidthMm: paperWidthMm,
    );
    if (pdfBytes.length < 32) {
      throw StateError('Invoice PDF payload is too small to print.');
    }

    final bytes = await _rasterJobBuilder(
      pdfBytes: pdfBytes,
      paperWidthMm: paperWidthMm,
      feedLines: 3,
      cut: true,
    );

    await _printService.printEscPosBytes(
      jobName: 'invoice_${invoice.invoiceNumber}',
      bytes: bytes,
    );
  }
}
