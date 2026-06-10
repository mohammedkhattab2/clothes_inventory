import 'dart:typed_data';

import 'package:delta_erp/services/printing/product_barcode_label_printer.dart';
import 'package:delta_erp/services/printing/thermal_printer_preferences.dart';
import 'package:delta_erp/services/printing/thermal_printer_presets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

void main() {
  int countPdfPages(Uint8List bytes) {
    final text = String.fromCharCodes(bytes);
    return RegExp(r'/Type\s*/Page\b').allMatches(text).length;
  }

  group('ProductBarcodeLabelPrinter', () {
    const printer = ProductBarcodeLabelPrinter(
      printerPrefs: ThermalPrinterPreferences(),
    );

    test('label dimensions match 350B preset', () {
      expect(
        ProductBarcodeLabelPrinter.labelWidthMm,
        ThermalPrinterPresets.labelWidthMm,
      );
      expect(
        ProductBarcodeLabelPrinter.labelHeightMm,
        ThermalPrinterPresets.labelHeightMm,
      );
      expect(ProductBarcodeLabelPrinter.gapMm, ThermalPrinterPresets.labelGapMm);
    });

    test('labelPageHeightMm includes gap between stickers', () {
      expect(
        ProductBarcodeLabelPrinter.labelPageHeightMm(includeGap: true),
        ThermalPrinterPresets.labelHeightMm + ThermalPrinterPresets.labelGapMm,
      );
      expect(
        ProductBarcodeLabelPrinter.labelPageHeightMm(includeGap: false),
        ThermalPrinterPresets.labelHeightMm,
      );
    });

    test('rollHeightMm totals label stack for multiple copies', () {
      expect(ProductBarcodeLabelPrinter.rollHeightMm(1), 22);
      expect(ProductBarcodeLabelPrinter.rollHeightMm(4), 22 * 4 + 2 * 3);
    });

    test('buildLabelPdfBytes creates one PDF page per copy', () async {
      const copies = 4;
      final bytes = await printer.buildLabelPdfBytes(
        productName: 'جينز',
        barcodeValue: '2000',
        companyName: 'ZERO JEANS',
        amount: 200,
        copies: copies,
      );

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      expect(countPdfPages(bytes), copies);
    });

    test('single-copy PDF page height matches label only', () async {
      final bytes = await printer.buildLabelPdfBytes(
        productName: 'جينز',
        barcodeValue: '2000',
        copies: 1,
      );
      final text = String.fromCharCodes(bytes);
      final match =
          RegExp(r'/MediaBox\[0 0 ([\d.]+) ([\d.]+)\]').firstMatch(text);
      expect(match, isNotNull);
      expect(
        double.parse(match!.group(1)!),
        closeTo(ThermalPrinterPresets.labelWidthMm * PdfPageFormat.mm, 0.01),
      );
      expect(
        double.parse(match.group(2)!),
        closeTo(ThermalPrinterPresets.labelHeightMm * PdfPageFormat.mm, 0.01),
      );
    });
  });
}
