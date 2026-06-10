import 'dart:typed_data';

import 'package:delta_erp/features/invoices/domain/a4_invoice_view_data.dart';
import 'package:delta_erp/services/pdf/a4_invoice_rtl_pdf_builder.dart';
import 'package:delta_erp/services/pdf/invoice_pdf_theme.dart';
import 'package:pdf/widgets.dart' as pw;

/// Shared PDF bytes for A4 invoice layout (used by printer + preview).
Future<Uint8List> buildA4InvoicePdfDocument({
  required A4InvoiceViewData data,
  Uint8List? logoBytes,
}) async {
  final doc = await createInvoicePdfDocument();
  pw.MemoryImage? logo;
  if (logoBytes != null && logoBytes.isNotEmpty) {
    logo = pw.MemoryImage(logoBytes);
  }

  buildA4RtlInvoicePage(document: doc, data: data, logo: logo);
  return doc.save();
}
