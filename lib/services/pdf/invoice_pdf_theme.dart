import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
/// Shared visual constants for A4 and thermal invoice PDFs.
abstract final class InvoicePdfTheme {
  static const textColor = PdfColors.black;
  static const borderColor = PdfColors.black;
  static const headerBandColor = PdfColor.fromInt(0xFFF3F3F3);
  static const tableHeaderBg = PdfColor.fromInt(0xFFE8E8E8);
  static const tableTotalsBg = PdfColor.fromInt(0xFFF4F4F4);

  static const a4MarginMm = 12.0;
  static const a4BorderWidth = 1.0;
  static const a4CellFontSize = 10.0;
  static const a4HeaderFontSize = 10.5;
  static const a4MetaFontSize = 11.0;
  static const a4CompanyNameFontSize = 20.0;
  static const a4InvoiceNumberFontSize = 13.0;
  static const a4TotalFontSize = 12.0;
  static const a4FooterNoteFontSize = 9.0;
  static const a4DeveloperFontSize = 8.0;

  /// Vertical margins for thermal receipt pages.
  static const thermalMarginVerticalMm = 3.0;

  /// Physical left margin (mm) — wider whitespace on printed receipts.
  static const thermalMarginLeftMm = 2.0;

  /// Physical right margin (mm) — extra space for RTL header/table start edge.
  static const thermalMarginRightMm = 5.0;

  /// Backward-compatible alias for vertical margins.
  static const thermalMarginMm = thermalMarginVerticalMm;

  static PdfPageFormat thermalPageFormat({
    required double paperWidthMm,
    required double pageHeightMm,
  }) {
    final mm = PdfPageFormat.mm;
    return PdfPageFormat(
      paperWidthMm * mm,
      pageHeightMm * mm,
      marginLeft: thermalMarginLeftMm * mm,
      marginRight: thermalMarginRightMm * mm,
      marginTop: thermalMarginVerticalMm * mm,
      marginBottom: thermalMarginVerticalMm * mm,
    );
  }

  /// Lighter thermal-only backgrounds (A4 keeps [headerBandColor] / [tableHeaderBg]).
  static const thermalHeaderBandColor = PdfColors.white;
  static const thermalTableHeaderBg = PdfColors.white;
  static const thermalTableTotalsBg = PdfColor.fromInt(0xFFFAFAFA);

  static double thermalClassicBorderWidth(double paperWidthMm) =>
      paperWidthMm <= 58 ? 0.12 : 0.15;

  static double thermalCellFontSize(double paperWidthMm) =>
      paperWidthMm <= 58 ? 4.5 : 5.3;

  static double thermalHeaderFontSize(double paperWidthMm) =>
      paperWidthMm <= 58 ? 5.0 : 5.8;

  static double thermalMetaFontSize(double paperWidthMm) =>
      paperWidthMm <= 58 ? 7.5 : 8.3;

  static double thermalCompanyNameFontSize(double paperWidthMm) =>
      paperWidthMm <= 58 ? 14.0 : 16.0;

  static double thermalFooterMinFontSize(double paperWidthMm) =>
      paperWidthMm <= 58 ? 6.0 : 6.8;

  static pw.BorderSide thermalClassicBorderSide(double paperWidthMm) {
    return pw.BorderSide(
      color: borderColor,
      width: thermalClassicBorderWidth(paperWidthMm),
    );
  }

  static pw.TableBorder thermalClassicTableBorder({
    required double paperWidthMm,
  }) {
    final side = thermalClassicBorderSide(paperWidthMm);
    return pw.TableBorder.all(
      color: borderColor,
      width: side.width,
    );
  }

  /// Single-line grid for one [pw.Table] with header + body + totals rows.
  static pw.TableBorder thermalUnifiedTableBorder({
    required double paperWidthMm,
  }) {
    final side = thermalClassicBorderSide(paperWidthMm);
    return pw.TableBorder(
      top: side,
      left: side,
      right: side,
      bottom: side,
      horizontalInside: side,
      verticalInside: side,
    );
  }

  /// Header row: full box including top edge.
  static pw.TableBorder thermalClassicHeaderTableBorder({
    required double paperWidthMm,
  }) {
    final side = thermalClassicBorderSide(paperWidthMm);
    return pw.TableBorder(
      top: side,
      left: side,
      right: side,
      bottom: side,
      horizontalInside: side,
      verticalInside: side,
    );
  }

  /// Body/totals rows: no top edge to avoid doubling the line under the header/previous row.
  static pw.TableBorder thermalClassicBodyTableBorder({
    required double paperWidthMm,
  }) {
    final side = thermalClassicBorderSide(paperWidthMm);
    return pw.TableBorder(
      left: side,
      right: side,
      bottom: side,
      verticalInside: side,
    );
  }

  static pw.TableBorder fullTableBorder({required double width}) {
    return pw.TableBorder.all(
      color: borderColor,
      width: width,
    );
  }
}

Future<pw.Document> createInvoicePdfDocument() async {
  final baseFont = await PdfGoogleFonts.notoNaskhArabicRegular();
  final boldFont = await PdfGoogleFonts.notoNaskhArabicBold();
  return pw.Document(
    theme: pw.ThemeData.withFont(
      base: baseFont,
      bold: boldFont,
      italic: baseFont,
      boldItalic: boldFont,
    ),
  );
}

/// Thermal receipts use Arial (Windows system font) for cleaner receipt output.
Future<pw.Document> createThermalInvoicePdfDocument() async {
  final baseFont = await loadThermalInvoiceBaseFont();
  final boldFont = await loadThermalInvoiceBoldFont();
  return pw.Document(
    theme: pw.ThemeData.withFont(
      base: baseFont,
      bold: boldFont,
      italic: baseFont,
      boldItalic: boldFont,
    ),
  );
}

Future<pw.Font> loadThermalInvoiceBaseFont() async {
  final arial = await _tryLoadWindowsFont('arial.ttf');
  if (arial != null) return arial;
  return PdfGoogleFonts.notoNaskhArabicRegular();
}

Future<pw.Font> loadThermalInvoiceBoldFont() async {
  final arialBold = await _tryLoadWindowsFont('arialbd.ttf');
  if (arialBold != null) return arialBold;
  return PdfGoogleFonts.notoNaskhArabicBold();
}

Future<pw.Font?> _tryLoadWindowsFont(String fileName) async {
  if (!Platform.isWindows) return null;
  final windir = Platform.environment['WINDIR'] ?? r'C:\Windows';
  final file = File('$windir\\Fonts\\$fileName');
  if (!await file.exists()) return null;
  final bytes = await file.readAsBytes();
  return pw.Font.ttf(ByteData.sublistView(bytes));
}