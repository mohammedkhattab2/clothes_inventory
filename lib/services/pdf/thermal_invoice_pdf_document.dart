import 'dart:typed_data';

import 'package:clothes_inventory/features/invoices/domain/invoice_print_model.dart';
import 'package:clothes_inventory/services/pdf/thermal_invoice_pdf_builder.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Shared PDF bytes for thermal receipt layout (used by printer + preview).
Future<Uint8List> buildThermalInvoicePdfDocument({
  required InvoicePrintModel invoice,
  required double paperWidthMm,
}) async {
  final baseFont = await PdfGoogleFonts.notoNaskhArabicRegular();
  final boldFont = await PdfGoogleFonts.notoNaskhArabicBold();

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(
      base: baseFont,
      bold: boldFont,
      italic: baseFont,
      boldItalic: boldFont,
    ),
  );

  buildThermalRtlInvoicePage(
    document: doc,
    invoice: invoice,
    paperWidthMm: paperWidthMm,
  );

  return doc.save();
}
