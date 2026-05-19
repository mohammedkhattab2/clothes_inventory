import 'dart:typed_data';

import 'package:delta_erp/features/invoices/domain/invoice_print_model.dart';
import 'package:delta_erp/features/invoices/presentation/invoice_print_model_mapper.dart';
import 'package:delta_erp/services/pdf/a4_invoice_rtl_pdf_builder.dart';
import 'package:delta_erp/services/printing/invoice_printer.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class A4InvoicePrinter implements InvoicePrinter {
  const A4InvoicePrinter({
    InvoicePrintModelMapper mapper = const InvoicePrintModelMapper(),
    this.onPrint,
  }) : _mapper = mapper;

  final InvoicePrintModelMapper _mapper;
  final Future<void> Function(Uint8List bytes, String jobName)? onPrint;

  @override
  Future<void> print(InvoicePrintModel invoice) async {
    final data = _mapper.toA4ViewData(invoice);

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

    buildA4RtlInvoicePage(document: doc, data: data);
    final bytes = await doc.save();

    if (onPrint != null) {
      await onPrint!(bytes, 'invoice_${invoice.invoiceNumber}');
      return;
    }

    final ok = await Printing.layoutPdf(
      name: 'invoice_${invoice.invoiceNumber}',
      onLayout: (_) async => bytes,
    );
    if (ok == false) {
      throw StateError('Printing was cancelled.');
    }
  }
}
