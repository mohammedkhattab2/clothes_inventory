import 'dart:typed_data';

import 'package:barcode/barcode.dart' as bc;
import 'package:delta_erp/services/printing/print_batch_failure.dart';
import 'package:delta_erp/services/printing/thermal_printer_preferences.dart';
import 'package:delta_erp/services/printing/windows_driver_pdf_print_service.dart';
import 'package:delta_erp/services/printing/thermal_printer_presets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Prints 350B gap-sensor barcode labels through the Windows printer driver.
///
/// XP-350B label mode speaks TSPL. One PDF page spans the full strip so the
/// driver feeds once per job instead of re-detecting the gap after every copy.
/// Content inside each 25 mm slot is laid out for bottom-to-top 350B feeds.
class ProductBarcodeLabelPrinter {
  ProductBarcodeLabelPrinter({
    required this.printerPrefs,
    WindowsDriverPdfPrintService? pdfPrintService,
  }) : _pdfPrintService =
            pdfPrintService ?? const WindowsDriverPdfPrintService();

  static const double labelWidthMm = ThermalPrinterPresets.labelWidthMm;
  static const double labelHeightMm = ThermalPrinterPresets.labelHeightMm;
  static const double gapMm = ThermalPrinterPresets.labelInterGapMm;
  static const double innerMarginMm = ThermalPrinterPresets.labelHorizontalMarginMm;
  static const double topMarginMm = ThermalPrinterPresets.labelVerticalPaddingTopMm;
  static const double printLeadingMarginMm =
      ThermalPrinterPresets.labelPrintLeadingMarginMm;

  final ThermalPrinterPreferences printerPrefs;
  final WindowsDriverPdfPrintService _pdfPrintService;

  /// Total PDF/print strip height for [copies] labels (mm).
  static double stripHeightMm(int copies) {
    if (copies <= 0) return labelHeightMm;
    return copies * labelHeightMm + (copies - 1) * gapMm;
  }

  /// Largest copy count that fits one driver PDF job on 350B (~109 mm).
  static int maxCopiesPerPrintJob({
    double maxStripHeightMm = ThermalPrinterPresets.labelMaxStripHeightMm,
  }) {
    var copies = 1;
    while (stripHeightMm(copies + 1) <= maxStripHeightMm + 0.001) {
      copies++;
    }
    return copies;
  }

  /// Splits [totalCopies] into consecutive driver-safe batches.
  ///
  /// When [totalCopies] exceeds [maxCopiesPerPrintJob], each label is sent as
  /// its own PDF job so the 350B gap sensor can sync between jobs.
  static List<int> batchCopyCounts(int totalCopies) {
    if (totalCopies < 1) {
      throw ArgumentError('Copies must be at least 1.');
    }
    final maxPerJob = maxCopiesPerPrintJob();
    if (totalCopies > maxPerJob) {
      return List.filled(
        totalCopies,
        ThermalPrinterPresets.labelCopiesPerJob,
      );
    }
    return [totalCopies];
  }

  /// Backward-compatible alias — one label slot height with optional gap.
  static double labelPageHeightMm({required bool includeGap}) {
    return includeGap ? labelHeightMm + gapMm : labelHeightMm;
  }

  /// Estimated physical roll length including optional leading blank (mm).
  static double rollHeightMm(int copies, {bool includeLeadingGap = true}) {
    if (copies <= 0) return labelHeightMm;
    final leading = includeLeadingGap
        ? ThermalPrinterPresets.labelLeadingGapMm +
            ThermalPrinterPresets.labelLeadingAdjustMm
        : 0.0;
    return leading + stripHeightMm(copies);
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

    final trimmedBarcode = barcodeValue.trim();
    final batches = batchCopyCounts(copies);
    var completedCopies = 0;

    for (var batchIndex = 0; batchIndex < batches.length; batchIndex++) {
      final batchCopies = batches[batchIndex];
      try {
        final bytes = await buildLabelPdfBytes(
          productName: productName,
          barcodeValue: trimmedBarcode,
          companyName: companyName,
          amount: amount,
          copies: batchCopies,
        );

        if (bytes.length < 32) {
          throw StateError('Barcode PDF payload is too small to print.');
        }

        final batchSuffix =
            batches.length > 1 ? '_${batchIndex + 1}of${batches.length}' : '';
        final jobName = 'barcode_$trimmedBarcode$batchSuffix';
        final pageFormat = _pageFormatForCopies(batchCopies);

        await _sendPdfToPrinter(
          bytes: bytes,
          pageFormat: pageFormat,
          jobName: jobName,
        );
        completedCopies += batchCopies;
      } catch (error) {
        throw PrintBatchFailure(
          completedCopies: completedCopies,
          requestedCopies: copies,
          batchIndex: batchIndex + 1,
          batchCount: batches.length,
          cause: error,
        );
      }

      if (batchIndex < batches.length - 1) {
        await Future<void>.delayed(
          Duration(
            milliseconds: ThermalPrinterPresets.labelInterBatchDelayMs,
          ),
        );
      }
    }
  }

  Future<void> _sendPdfToPrinter({
    required Uint8List bytes,
    required PdfPageFormat pageFormat,
    required String jobName,
  }) async {
    final savedPrinter = await printerPrefs.resolveCurrentPrinter();

    if (savedPrinter != null) {
      await _pdfPrintService.printDirectPdf(
        printer: savedPrinter,
        printerName: savedPrinter.name,
        jobName: jobName,
        format: pageFormat,
        onLayout: (_) async => bytes,
      );
      return;
    }

    final ok = await Printing.layoutPdf(
      name: jobName,
      onLayout: (_) async => bytes,
      format: pageFormat,
    );
    if (ok != true) {
      throw StateError('Printing was cancelled.');
    }
  }

  static PdfPageFormat _pageFormatForCopies(int copies) {
    final pageWidthPt = labelWidthMm * PdfPageFormat.mm;
    final pageHeightPt = stripHeightMm(copies) * PdfPageFormat.mm;
    return PdfPageFormat(pageWidthPt, pageHeightPt, marginAll: 0);
  }

  /// One 25 mm sticker slot laid out for bottom-to-top 350B feeds.
  static pw.Widget buildLabelSlot({
    required String productName,
    required String barcodeValue,
    required String companyName,
    required String amountText,
    required double labelHeightPt,
    required double innerPaddingPt,
    required double topPaddingPt,
    required double printLeadingPaddingPt,
  }) {
    final showProductRow = productName.isNotEmpty || amountText.isNotEmpty;

    return pw.SizedBox(
      height: labelHeightPt,
      child: pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Padding(
          padding: pw.EdgeInsets.only(
            left: innerPaddingPt,
            right: innerPaddingPt,
            top: topPaddingPt + innerPaddingPt,
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              if (companyName.isNotEmpty)
                pw.Text(
                  companyName,
                  textAlign: pw.TextAlign.center,
                  maxLines: 1,
                  style: pw.TextStyle(
                    fontSize: ThermalPrinterPresets.labelCompanyNameFontSizePt,
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
                            fontSize: ThermalPrinterPresets.labelPriceFontSizePt,
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
                          style: pw.TextStyle(
                            fontSize: ThermalPrinterPresets.labelProductFontSizePt,
                          ),
                        ),
                      ),
                  ],
                ),
              if (showProductRow) pw.SizedBox(height: 1.5),
              pw.Expanded(
                child: pw.BarcodeWidget(
                  barcode: bc.Barcode.code128(),
                  data: barcodeValue,
                  height: ThermalPrinterPresets.labelBarcodeHeightMm * PdfPageFormat.mm,
                  drawText: false,
                ),
              ),
              pw.Text(
                barcodeValue,
                textAlign: pw.TextAlign.center,
                maxLines: 1,
                style: pw.TextStyle(
                  fontSize: ThermalPrinterPresets.labelBarcodeTextFontSizePt,
                ),
              ),
              pw.SizedBox(height: printLeadingPaddingPt),
            ],
          ),
        ),
      ),
    );
  }

  /// Backward-compatible alias used by preview helpers.
  static pw.Widget buildLabelContent({
    required String productName,
    required String barcodeValue,
    required String companyName,
    required String amountText,
    required double labelHeightPt,
    required double innerPaddingPt,
    required double topPaddingPt,
  }) {
    return buildLabelSlot(
      productName: productName,
      barcodeValue: barcodeValue,
      companyName: companyName,
      amountText: amountText,
      labelHeightPt: labelHeightPt,
      innerPaddingPt: innerPaddingPt,
      topPaddingPt: topPaddingPt,
      printLeadingPaddingPt: printLeadingMarginMm * PdfPageFormat.mm,
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
    final stripHeightPt = stripHeightMm(copies) * PdfPageFormat.mm;
    final labelHeightPt = labelHeightMm * PdfPageFormat.mm;
    final gapPt = gapMm * PdfPageFormat.mm;
    final innerPaddingPt = innerMarginMm * PdfPageFormat.mm;
    final topPaddingPt = topMarginMm * PdfPageFormat.mm;
    final printLeadingPaddingPt = printLeadingMarginMm * PdfPageFormat.mm;
    final pageFormat = PdfPageFormat(pageWidthPt, stripHeightPt, marginAll: 0);

    final stripChildren = <pw.Widget>[];
    for (var copy = copies; copy >= 1; copy--) {
      if (stripChildren.isNotEmpty) {
        stripChildren.add(pw.SizedBox(height: gapPt));
      }
      stripChildren.add(
        buildLabelSlot(
          productName: productName,
          barcodeValue: barcodeValue,
          companyName: companyName,
          amountText: amountText,
          labelHeightPt: labelHeightPt,
          innerPaddingPt: innerPaddingPt,
          topPaddingPt: topPaddingPt,
          printLeadingPaddingPt: printLeadingPaddingPt,
        ),
      );
    }

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: stripChildren,
        ),
      ),
    );

    return doc.save();
  }
}
