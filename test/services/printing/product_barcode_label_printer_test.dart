import 'dart:typed_data';

import 'package:delta_erp/services/printing/product_barcode_label_printer.dart';
import 'package:delta_erp/services/printing/thermal_printer_preferences.dart';
import 'package:delta_erp/services/printing/thermal_printer_presets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProductBarcodeLabelPrinter', () {
    final printer = ProductBarcodeLabelPrinter(
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
      expect(ThermalPrinterPresets.labelWidthMm, 38.0);
      expect(ThermalPrinterPresets.labelHeightMm, 25.0);
      expect(ThermalPrinterPresets.labelGapMm, 3.0);
    });

    test('label font sizes and feed presets', () {
      expect(ThermalPrinterPresets.labelCompanyNameFontSizePt, 8.5);
      expect(ThermalPrinterPresets.labelPrintLeadingMarginMm, 8.0);
      expect(ThermalPrinterPresets.labelPitchFeedLines, 9);
      expect(ThermalPrinterPresets.labelLeadingFeedLines, 1);
    });

    test('maxCopiesPerPrintJob matches 350B driver strip limit', () {
      expect(ProductBarcodeLabelPrinter.maxCopiesPerPrintJob(), 4);
      expect(
        ProductBarcodeLabelPrinter.stripHeightMm(4),
        closeTo(ThermalPrinterPresets.labelMaxStripHeightMm, 0.001),
      );
      expect(
        ProductBarcodeLabelPrinter.stripHeightMm(5),
        greaterThan(ThermalPrinterPresets.labelMaxStripHeightMm),
      );
    });

    test('batchCopyCounts splits large jobs without losing copies', () {
      expect(ProductBarcodeLabelPrinter.batchCopyCounts(1), [1]);
      expect(ProductBarcodeLabelPrinter.batchCopyCounts(4), [4]);
      expect(
        ProductBarcodeLabelPrinter.batchCopyCounts(10),
        List.filled(10, ThermalPrinterPresets.labelCopiesPerJob),
      );
      expect(
        ProductBarcodeLabelPrinter.batchCopyCounts(10).reduce((a, b) => a + b),
        10,
      );
    });

    test('stripHeightMm matches label pitch for multiple copies', () {
      expect(ProductBarcodeLabelPrinter.stripHeightMm(1), 25.0);
      expect(
        ProductBarcodeLabelPrinter.stripHeightMm(3),
        closeTo(3 * 25.0 + 2 * 3.0, 0.001),
      );
      expect(
        ProductBarcodeLabelPrinter.rollHeightMm(3, includeLeadingGap: false),
        ProductBarcodeLabelPrinter.stripHeightMm(3),
      );
    });

    test('rollHeightMm includes optional leading blank', () {
      expect(
        ProductBarcodeLabelPrinter.rollHeightMm(1),
        closeTo(
          ThermalPrinterPresets.labelLeadingGapMm +
              ThermalPrinterPresets.labelHeightMm,
          0.001,
        ),
      );
    });

    test('buildLabelPdfBytes embeds barcode digits and company', () async {
      const barcode = '2000';
      final bytes = await printer.buildLabelPdfBytes(
        productName: 'Jeans',
        barcodeValue: barcode,
        companyName: 'ZERO JEANS',
        copies: 1,
      );

      expect(bytes, isA<Uint8List>());
      expect(bytes.length, greaterThan(100));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('multi-copy PDF is larger than a single label', () async {
      final single = await printer.buildLabelPdfBytes(
        productName: 'Jeans',
        barcodeValue: '2000',
        copies: 1,
      );
      final triple = await printer.buildLabelPdfBytes(
        productName: 'Jeans',
        barcodeValue: '2000',
        copies: 3,
      );

      expect(triple.length, greaterThan(single.length));
    });
  });
}
