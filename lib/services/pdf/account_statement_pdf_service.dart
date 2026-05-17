import 'dart:io';
import 'dart:typed_data';
import 'dart:developer' as dev;

import 'package:easy_localization/easy_localization.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:delta_erp/features/accounts/data/account_statement_repository.dart';

class AccountStatementPdfService {
  const AccountStatementPdfService();

  Future<String> exportToPdf({
    required String accountName,
    required String accountType,
    required List<AccountStatementTransaction> transactions,
    required double finalBalance,
    required String targetPath,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final bytes = await _buildPdf(
        accountName: accountName,
        accountType: accountType,
        transactions: transactions,
        finalBalance: finalBalance,
        fromDate: fromDate,
        toDate: toDate,
      );

      final file = File(targetPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (e, st) {
      dev.log(
        'Failed exporting account statement PDF',
        name: 'AccountStatementPdfService',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<Uint8List> _buildPdf({
    required String accountName,
    required String accountType,
    required List<AccountStatementTransaction> transactions,
    required double finalBalance,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final valueFormat = NumberFormat('0.00');
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

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(width: 0.8, color: PdfColors.grey400),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Account Statement'.tr(),
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                '${'Generated'.tr()}: ${dateFormat.format(DateTime.now())}',
              ),
            ],
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${'Page'.tr()} ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 8),
          pw.Text('${'Account Name'.tr()}: $accountName'),
          pw.Text('${'Account Type'.tr()}: $accountType'),
          pw.Text(
            '${'Date Range'.tr()}: '
            '${fromDate == null ? '-' : DateFormat('yyyy-MM-dd').format(fromDate)} '
            '${'to'.tr()} '
            '${toDate == null ? '-' : DateFormat('yyyy-MM-dd').format(toDate)}',
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: [
              'Date'.tr(),
              'Type'.tr(),
              'Reference'.tr(),
              'Debit'.tr(),
              'Credit'.tr(),
              'Running Balance'.tr(),
            ],
            data: transactions
                .map(
                  (tx) => [
                    dateFormat.format(tx.createdAt),
                    tx.typeLabel,
                    tx.referenceLabel,
                    tx.debit == 0 ? '-' : valueFormat.format(tx.debit),
                    tx.credit == 0 ? '-' : valueFormat.format(tx.credit),
                    valueFormat.format(tx.runningBalance),
                  ],
                )
                .toList(),
            cellAlignments: {
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
            },
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            cellPadding: const pw.EdgeInsets.symmetric(
              vertical: 6,
              horizontal: 4,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              '${'Final Balance'.tr()}: ${valueFormat.format(finalBalance)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }
}
