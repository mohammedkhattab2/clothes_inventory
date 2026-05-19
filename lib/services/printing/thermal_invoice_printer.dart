import 'dart:typed_data';

import 'package:delta_erp/features/invoices/domain/invoice_print_model.dart';
import 'package:delta_erp/services/printing/arabic_print_mode_resolver.dart';
import 'package:delta_erp/services/printing/escpos_arabic_printer_service.dart';
import 'package:delta_erp/services/printing/invoice_printer.dart';
import 'package:delta_erp/services/printing/printer_text_formatters.dart';
import 'package:delta_erp/services/printing/rtl_printer_formatter.dart';

class ThermalInvoicePrinter implements InvoicePrinter {
  ThermalInvoicePrinter({
    required this.generator,
    required this.lineWidth,
    required this.printerSupportsArabic,
    this.useImageFallback = false,
    this.buildInvoiceImage,
    ArabicPrintModeResolver? modeResolver,
    ThermalTextFormatter? formatter,
  }) : _modeResolver = modeResolver ?? const ArabicPrintModeResolver(),
       _formatter = formatter ?? const ThermalTextFormatter();

  final EscPosGeneratorAdapter generator;
  final int lineWidth;
  final bool printerSupportsArabic;
  final bool useImageFallback;
  final Future<Uint8List> Function(InvoicePrintModel invoice)?
  buildInvoiceImage;
  final ArabicPrintModeResolver _modeResolver;
  final ThermalTextFormatter _formatter;

  @override
  Future<void> print(InvoicePrintModel invoice) async {
    final mode = _modeResolver.resolve(
      printerSupportsArabic: printerSupportsArabic,
      preferImageFallback: useImageFallback,
    );

    if (mode == ArabicPrintMode.image) {
      if (buildInvoiceImage == null) {
        throw StateError(
          'Image fallback selected but no image builder provided.',
        );
      }
      final imageBytes = await buildInvoiceImage!(invoice);
      generator.image(imageBytes);
      generator.feed(2);
      return;
    }

    final rtl = RtlPrinterFormatter(lineWidth, textFormatter: _formatter);

    generator.text(rtl.center(invoice.title));
    generator.text(rtl.right(invoice.companyName));
    generator.text(rtl.right('العنوان: ${invoice.address}'));
    generator.text(rtl.right('التليفون: ${invoice.phone}'));
    generator.hr();

    generator.text(rtl.right('رقم الفاتورة: ${invoice.invoiceNumber}'));
    generator.text(rtl.right('التاريخ: ${_formatDateTime(invoice.date)}'));
    generator.text(rtl.right('العميل: ${invoice.customerName}'));
    generator.hr();

    generator.text(
      rtl.buildInvoiceRow(name: 'المنتج', qty: 'الكمية', price: 'السعر'),
    );

    for (final item in invoice.items) {
      generator.text(
        rtl.buildInvoiceRow(
          name: item.productName,
          qty: item.quantity.toStringAsFixed(0),
          price: item.effectiveLineTotal.toStringAsFixed(2),
        ),
      );
    }

    generator.hr();
    generator.text(
      rtl.totalLine(
        label: 'الإجمالي:',
        value: '${invoice.total.toStringAsFixed(2)} ${invoice.currency}',
      ),
    );
    generator.feed(2);
  }

  String _formatDateTime(DateTime value) {
    final yyyy = value.year.toString().padLeft(4, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd $hh:$min';
  }
}
