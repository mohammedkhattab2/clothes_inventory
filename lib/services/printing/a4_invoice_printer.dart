import 'dart:typed_data';

import 'package:clothes_inventory/features/invoices/domain/a4_invoice_view_data.dart';
import 'package:clothes_inventory/features/invoices/domain/invoice_print_model.dart';
import 'package:clothes_inventory/services/pdf/a4_invoice_rtl_pdf_builder.dart';
import 'package:clothes_inventory/services/printing/invoice_printer.dart';
import 'package:clothes_inventory/services/printing/printer_text_formatters.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class A4InvoicePrinter implements InvoicePrinter {
  const A4InvoicePrinter({
    A4TextFormatter formatter = const A4TextFormatter(),
    this.onPrint,
  }) : _formatter = formatter;

  final A4TextFormatter _formatter;
  final Future<void> Function(Uint8List bytes, String jobName)? onPrint;

  @override
  Future<void> print(InvoicePrintModel invoice) async {
    final data = A4InvoiceViewData(
      companyName: _fmt(invoice.companyName),
      address: _fmt('العنوان: ${invoice.address}'),
      phone: _fmt('التليفون: ${invoice.phone}'),
      title: _fmt(invoice.title),
      invoiceNumber: _fmt(invoice.invoiceNumber),
      issuedAt: invoice.date,
      partyLabel: _fmt('العميل'),
      partyName: _fmt(invoice.customerName),
      lines: invoice.items
          .map(
            (item) => A4InvoiceLine(
              productName: _fmt(item.productName),
              quantity: item.quantity.toStringAsFixed(0),
              price: item.lineTotal.toStringAsFixed(2),
            ),
          )
          .toList(growable: false),
      total: invoice.total.toStringAsFixed(2),
      currency: invoice.currency,
      invoiceFooterNote: _fmt(invoice.invoiceFooterNote),
      invoiceFooterImageBytes: invoice.invoiceFooterImageBytes,
    );

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

  String _fmt(String value) => _formatter.format(value);
}
