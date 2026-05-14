import 'dart:typed_data';

import 'package:clothes_inventory/services/printing/arabic_print_mode_resolver.dart';
import 'package:clothes_inventory/services/printing/printer_text_formatters.dart';
import 'package:clothes_inventory/services/printing/rtl_printer_formatter.dart';

class EscPosInvoiceLine {
  const EscPosInvoiceLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.discount,
    required this.lineTotal,
  });

  final String name;
  final String quantity;
  final String unitPrice;
  final String discount;
  final String lineTotal;
}

class EscPosInvoicePayload {
  const EscPosInvoicePayload({
    required this.companyName,
    required this.address,
    required this.phone,
    required this.title,
    required this.invoiceNumber,
    required this.createdAt,
    required this.partyLabel,
    required this.partyName,
    required this.lines,
    required this.total,
    this.currency = 'EGP',
  });

  final String companyName;
  final String address;
  final String phone;
  final String title;
  final String invoiceNumber;
  final String createdAt;
  final String partyLabel;
  final String partyName;
  final List<EscPosInvoiceLine> lines;
  final String total;
  final String currency;
}

abstract class EscPosGeneratorAdapter {
  void text(String value);
  void row(List<String> columns);
  void image(Uint8List bytes);
  void hr();
  void feed(int lines);
}

class EscPosArabicPrinterService {
  const EscPosArabicPrinterService({
    ThermalTextFormatter formatter = const ThermalTextFormatter(),
    ArabicPrintModeResolver modeResolver = const ArabicPrintModeResolver(),
    this.lineWidth = kThermal58mmLineWidth,
  }) : _formatter = formatter,
       _modeResolver = modeResolver;

  final ThermalTextFormatter _formatter;
  final ArabicPrintModeResolver _modeResolver;
  final int lineWidth;

  Future<void> printInvoice({
    required EscPosGeneratorAdapter generator,
    required EscPosInvoicePayload payload,
    required bool printerSupportsArabic,
    bool preferImageFallback = false,
    Future<Uint8List> Function()? buildInvoiceImage,
  }) async {
    final rtl = RtlPrinterFormatter(lineWidth, textFormatter: _formatter);

    final mode = _modeResolver.resolve(
      printerSupportsArabic: printerSupportsArabic,
      preferImageFallback: preferImageFallback,
    );

    if (mode == ArabicPrintMode.image) {
      if (buildInvoiceImage == null) {
        throw StateError(
          'Image fallback mode selected but buildInvoiceImage callback is null.',
        );
      }
      final imageBytes = await buildInvoiceImage();
      generator.image(imageBytes);
      generator.feed(2);
      return;
    }

    generator.text(rtl.center(payload.companyName));
    generator.text(rtl.right('العنوان: ${payload.address}'));
    generator.text(rtl.right('التليفون: ${payload.phone}'));
    generator.hr();

    generator.text(rtl.center(payload.title));
    generator.text(rtl.right('فاتورة: ${payload.invoiceNumber}'));
    generator.text(rtl.right('التاريخ: ${payload.createdAt}'));
    generator.text(rtl.right('${payload.partyLabel}: ${payload.partyName}'));
    generator.hr();

    generator.text(
      rtl.buildFiveColumnRow(
        name: 'البند',
        qty: 'الكمية',
        unitPrice: 'سعر',
        discount: 'خصم',
        total: 'الإجمالي',
      ),
    );

    for (final line in payload.lines) {
      generator.text(
        rtl.buildFiveColumnRow(
          name: line.name,
          qty: line.quantity,
          unitPrice: line.unitPrice,
          discount: line.discount,
          total: line.lineTotal,
        ),
      );
    }

    generator.hr();
    generator.text(
      rtl.totalLine(
        label: 'الإجمالي:',
        value: '${payload.total} ${payload.currency}',
      ),
    );
    generator.feed(2);
  }
}
