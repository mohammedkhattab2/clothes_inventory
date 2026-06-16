import 'dart:typed_data';

import 'package:delta_erp/features/invoices/domain/invoice_print_model.dart';
import 'package:delta_erp/services/pdf/invoice_pdf_theme.dart';
import 'package:delta_erp/services/pdf/thermal_invoice_pdf_builder.dart';
import 'package:pdf/widgets.dart' as pw;

/// Shared PDF bytes for thermal receipt layout (used by printer preview).
Future<Uint8List> buildThermalInvoicePdfDocument({
  required InvoicePrintModel invoice,
  required double paperWidthMm,
}) async {
  final doc = await createThermalInvoicePdfDocument();

  buildThermalRtlInvoicePage(
    document: doc,
    invoice: invoice,
    paperWidthMm: paperWidthMm,
  );

  return doc.save();
}

/// One driver-safe strip for sequential thermal printing on 350B (~109 mm).
Future<Uint8List> buildThermalInvoiceStripPdfDocument({
  required List<pw.Widget> widgets,
  required double paperWidthMm,
  required double pageHeightMm,
}) async {
  final doc = await createThermalInvoicePdfDocument();

  doc.addPage(
    pw.Page(
      pageFormat: InvoicePdfTheme.thermalPageFormat(
        paperWidthMm: paperWidthMm,
        pageHeightMm: pageHeightMm,
      ),
      textDirection: pw.TextDirection.rtl,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: widgets,
      ),
    ),
  );

  return doc.save();
}
