import 'dart:typed_data';

import 'package:barcode/barcode.dart' as bc;
import 'package:delta_erp/services/printing/thermal_printer_preferences.dart';
import 'package:delta_erp/services/printing/thermal_printer_presets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ProductBarcodeLabelPrinter {
  const ProductBarcodeLabelPrinter({
    required this.printerPrefs,
  });

  static const double labelWidthMm = ThermalPrinterPresets.labelWidthMm;
  static const double labelHeightMm = ThermalPrinterPresets.labelHeightMm;
  static const double gapMm = ThermalPrinterPresets.labelGapMm;
  static const double innerMarginMm = ThermalPrinterPresets.labelInnerMarginMm;
  static const double topMarginMm = ThermalPrinterPresets.labelTopMarginMm;

  final ThermalPrinterPreferences printerPrefs;

  /// Page height for one sticker slot (label + physical gap), in mm.
  static double labelPageHeightMm({required bool includeGap}) {
    return includeGap ? labelHeightMm + gapMm : labelHeightMm;
  }

  Future<Uint8List> buildLabelPdfBytes({
    required String productName,
    required String barcodeValue,
    String? companyName,
    double? amount,
    int copies = 1,
  }) {
    if (barcodeValue.trim().isEmpty) {
      throw ArgumentError('Barcode cannot be empty.');
    }
    if (copies < 1) {
      throw ArgumentError('Copies must be at least 1.');
    }
    return _buildPdf(
      productName: productName.trim(),
      barcodeValue: barcodeValue.trim(),
      companyName: companyName?.trim() ?? '',
      amountText: amount == null ? '' : '${amount.toStringAsFixed(2)} L.E',
      copies: copies,
    );
  }

  Future<void> printLabel({
    required String productName,
    required String barcodeValue,
    String? companyName,
    double? amount,
    int copies = 1,
  }) async {
    if (barcodeValue.trim().isEmpty) {
      throw ArgumentError('Barcode cannot be empty.');
    }
    if (copies < 1) {
      throw ArgumentError('Copies must be at least 1.');
    }

    final bytes = await buildLabelPdfBytes(
      productName: productName.trim(),
      barcodeValue: barcodeValue.trim(),
      companyName: companyName,
      amount: amount,
      copies: copies,
    );
    final jobName = 'barcode_${barcodeValue.trim()}';
    final pageFormat = _pageFormatForCopies(copies);

    final savedPrinter = await printerPrefs.resolveCurrentPrinter();
    if (savedPrinter != null) {
      await Printing.directPrintPdf(
        printer: savedPrinter,
        onLayout: (_) async => bytes,
        format: pageFormat,
        name: jobName,
      );
      return;
    }

    final ok = await Printing.layoutPdf(
      name: jobName,
      onLayout: (_) async => bytes,
      format: pageFormat,
    );
    if (ok == false) {
      throw StateError('Printing was cancelled.');
    }
  }

  /// Total roll length when all label slots are stacked (mm).
  static double rollHeightMm(int copies) {
    if (copies <= 0) return labelHeightMm;
    if (copies == 1) return labelHeightMm;
    return copies * labelHeightMm + (copies - 1) * gapMm;
  }

  static PdfPageFormat _pageFormatForCopies(int copies) {
    final pageWidthPt = labelWidthMm * PdfPageFormat.mm;
    final includeGap = copies > 1;
    final pageHeightPt =
        labelPageHeightMm(includeGap: includeGap) * PdfPageFormat.mm;
    return PdfPageFormat(pageWidthPt, pageHeightPt, marginAll: 0);
  }

  static pw.Widget buildLabelContent({
    required String productName,
    required String barcodeValue,
    required String companyName,
    required String amountText,
    required double labelHeightPt,
    required double innerPaddingPt,
    required double topPaddingPt,
  }) {
    final showProductRow = productName.isNotEmpty || amountText.isNotEmpty;

    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.SizedBox(
        height: labelHeightPt,
        child: pw.Padding(
          padding: pw.EdgeInsets.only(
            left: innerPaddingPt,
            right: innerPaddingPt,
            bottom: innerPaddingPt,
            top: topPaddingPt + innerPaddingPt,
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            mainAxisAlignment: pw.MainAxisAlignment.start,
            children: [
              if (companyName.isNotEmpty)
                pw.Text(
                  companyName,
                  textAlign: pw.TextAlign.center,
                  maxLines: 1,
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              if (companyName.isNotEmpty) pw.SizedBox(height: 1.5),
              if (showProductRow)
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (amountText.isNotEmpty)
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          amountText,
                          textAlign: pw.TextAlign.right,
                          maxLines: 1,
                          style: pw.TextStyle(
                            fontSize: 7.5,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    if (amountText.isNotEmpty && productName.isNotEmpty)
                      pw.SizedBox(width: 2),
                    if (productName.isNotEmpty)
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text(
                          productName,
                          textAlign: pw.TextAlign.left,
                          maxLines: 2,
                          style: const pw.TextStyle(fontSize: 7),
                        ),
                      ),
                  ],
                ),
              if (showProductRow) pw.SizedBox(height: 1.5),
              pw.Expanded(
                child: pw.BarcodeWidget(
                  barcode: bc.Barcode.code128(),
                  data: barcodeValue,
                  height: 6.0 * PdfPageFormat.mm,
                  drawText: false,
                ),
              ),
              pw.Text(
                barcodeValue,
                textAlign: pw.TextAlign.center,
                maxLines: 1,
                style: const pw.TextStyle(fontSize: 7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Uint8List> _buildPdf({
    required String productName,
    required String barcodeValue,
    required String companyName,
    required String amountText,
    required int copies,
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

    final pageWidthPt = labelWidthMm * PdfPageFormat.mm;
    final labelHeightPt = labelHeightMm * PdfPageFormat.mm;
    final gapPt = gapMm * PdfPageFormat.mm;
    final innerPaddingPt = innerMarginMm * PdfPageFormat.mm;
    final topPaddingPt = topMarginMm * PdfPageFormat.mm;

    for (var i = 0; i < copies; i++) {
      final isLast = i == copies - 1;
      final includeGap = !isLast;
      final pageHeightPt =
          labelPageHeightMm(includeGap: includeGap) * PdfPageFormat.mm;
      final pageFormat = PdfPageFormat(pageWidthPt, pageHeightPt, marginAll: 0);

      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              buildLabelContent(
                productName: productName,
                barcodeValue: barcodeValue,
                companyName: companyName,
                amountText: amountText,
                labelHeightPt: labelHeightPt,
                innerPaddingPt: innerPaddingPt,
                topPaddingPt: topPaddingPt,
              ),
              if (includeGap) pw.SizedBox(height: gapPt),
            ],
          ),
        ),
      );
    }

    return doc.save();
  }
}
