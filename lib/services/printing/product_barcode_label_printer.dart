import 'dart:typed_data';

import 'package:barcode/barcode.dart' as bc;
import 'package:delta_erp/services/printing/thermal_printer_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ProductBarcodeLabelPrinter {
  const ProductBarcodeLabelPrinter({
    required this.paperWidthMm,
    required this.printerPrefs,
  });

  final double paperWidthMm;
  final ThermalPrinterPreferences printerPrefs;

  Future<Uint8List> buildLabelPdfBytes({
    required String productName,
    required String barcodeValue,
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
      copies: copies,
    );
  }

  Future<void> printLabel({
    required String productName,
    required String barcodeValue,
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
      copies: copies,
    );
    final jobName = 'barcode_${barcodeValue.trim()}';

    final savedPrinter = await printerPrefs.resolveCurrentPrinter();
    if (savedPrinter != null) {
      await Printing.directPrintPdf(
        printer: savedPrinter,
        onLayout: (_) async => bytes,
        name: jobName,
      );
      return;
    }

    final ok = await Printing.layoutPdf(
      name: jobName,
      onLayout: (_) async => bytes,
    );
    if (ok == false) {
      throw StateError('Printing was cancelled.');
    }
  }

  Future<Uint8List> _buildPdf({
    required String productName,
    required String barcodeValue,
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

    final pageWidthPt = paperWidthMm * PdfPageFormat.mm;
    final pageFormat = PdfPageFormat(
      pageWidthPt,
      54 * PdfPageFormat.mm,
      marginAll: 2.5 * PdfPageFormat.mm,
    );

    for (var i = 0; i < copies; i++) {
      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  if (productName.isNotEmpty)
                    pw.Text(
                      productName,
                      textAlign: pw.TextAlign.center,
                      maxLines: 1,
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  if (productName.isNotEmpty) pw.SizedBox(height: 3),
                  pw.BarcodeWidget(
                    barcode: bc.Barcode.code128(),
                    data: barcodeValue,
                    height: 18 * PdfPageFormat.mm,
                    drawText: false,
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    barcodeValue,
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    return doc.save();
  }
}
