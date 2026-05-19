import 'dart:typed_data';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:delta_erp/features/invoices/data/sale_invoice_print_data_builder.dart';
import 'package:delta_erp/services/pdf/a4_invoice_rtl_pdf_builder.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class SalesInvoicePdfService {
  SalesInvoicePdfService(this._salePrintBuilder);

  final SaleInvoicePrintDataBuilder _salePrintBuilder;

  Future<Uint8List> generateA4Invoice(int saleId) async {
    final invoiceData = await _salePrintBuilder.buildA4ViewData(saleId);
    if (invoiceData == null) {
      throw StateError('Sale not found for PDF generation.'.tr());
    }

    final doc = await _createDocumentWithSafeFonts();
    buildA4RtlInvoicePage(document: doc, data: invoiceData);
    return doc.save();
  }

  Future<void> printInvoice(int saleId) async {
    if (saleId <= 0) {
      throw ArgumentError('saleId must be greater than zero.'.tr());
    }

    final bytes = await generateA4Invoice(saleId);
    try {
      final ok = await Printing.layoutPdf(
        name: 'sales_invoice_$saleId',
        onLayout: (format) async => bytes,
      );
      if (ok == false) {
        throw StateError('Printing was cancelled.'.tr());
      }
      return;
    } catch (_) {
      await _printViaShellFallback(
        bytes,
        fileNamePrefix: 'sales_invoice_$saleId',
      );
    }
  }

  Future<void> _printViaShellFallback(
    Uint8List bytes, {
    required String fileNamePrefix,
  }) async {
    final file = await _saveTempPdf(bytes, fileNamePrefix: fileNamePrefix);

    if (Platform.isWindows) {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        r'$ErrorActionPreference = "Stop"; Start-Process -FilePath "' +
            file.path.replaceAll('"', '""') +
            r'" -Verb Print',
      ]);
      if (result.exitCode == 0) {
        return;
      }

      final openResult = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        r'$ErrorActionPreference = "Stop"; Start-Process -FilePath "' +
            file.path.replaceAll('"', '""') +
            r'"',
      ]);
      if (openResult.exitCode == 0) {
        return;
      }

      throw StateError(
        '${'Failed to send invoice to printer.'.tr()} ${result.stderr}'.trim(),
      );
    }

    throw StateError('Printing is not supported on this platform.'.tr());
  }

  Future<File> _saveTempPdf(
    Uint8List bytes, {
    required String fileNamePrefix,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      p.join(dir.path, '${fileNamePrefix}_${DateTime.now().millisecondsSinceEpoch}.pdf'),
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<pw.Document> _createDocumentWithSafeFonts() async {
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
}
