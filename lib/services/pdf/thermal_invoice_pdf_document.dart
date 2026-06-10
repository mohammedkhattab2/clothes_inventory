import 'dart:typed_data';

import 'package:delta_erp/features/invoices/domain/invoice_print_model.dart';
import 'package:delta_erp/services/pdf/invoice_pdf_theme.dart';
import 'package:delta_erp/services/pdf/thermal_invoice_pdf_builder.dart';

/// Shared PDF bytes for thermal receipt layout (used by printer + preview).
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
