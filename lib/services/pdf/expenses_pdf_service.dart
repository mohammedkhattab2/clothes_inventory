import 'dart:developer' as dev;
import 'dart:io';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:clothes_inventory/core/config/company_settings_service.dart';
import 'package:clothes_inventory/features/expenses/data/expenses_repository.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ExpensesPdfService {
  const ExpensesPdfService(this._companySettingsService);

  final CompanySettingsService _companySettingsService;

  Future<String> exportToPdf({
    required List<ExpenseRecord> rows,
    required double grossExpenses,
    required double netExpenses,
    required bool includeReversals,
    DateTime? fromDate,
    DateTime? toDate,
    int? accountId,
  }) async {
    try {
      final bytes = await _buildPdfBytes(
        rows: rows,
        grossExpenses: grossExpenses,
        netExpenses: netExpenses,
        includeReversals: includeReversals,
        fromDate: fromDate,
        toDate: toDate,
        accountId: accountId,
      );

      final docsDir = await getApplicationDocumentsDirectory();
      final exportDir = Directory(p.join(docsDir.path, 'exports'));
      await exportDir.create(recursive: true);

      final fileName = 'expenses_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(p.join(exportDir.path, fileName));
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (e, st) {
      dev.log(
        'Failed exporting expenses PDF',
        name: 'ExpensesPdfService',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> printReport({
    required List<ExpenseRecord> rows,
    required double grossExpenses,
    required double netExpenses,
    required bool includeReversals,
    DateTime? fromDate,
    DateTime? toDate,
    int? accountId,
  }) async {
    final bytes = await _buildPdfBytes(
      rows: rows,
      grossExpenses: grossExpenses,
      netExpenses: netExpenses,
      includeReversals: includeReversals,
      fromDate: fromDate,
      toDate: toDate,
      accountId: accountId,
    );

    final ok = await Printing.layoutPdf(
      name: 'expenses_${DateTime.now().millisecondsSinceEpoch}',
      onLayout: (format) async => bytes,
    );

    if (ok == false) {
      throw StateError('Printing was cancelled.'.tr());
    }
  }

  Future<Uint8List> _buildPdfBytes({
    required List<ExpenseRecord> rows,
    required double grossExpenses,
    required double netExpenses,
    required bool includeReversals,
    DateTime? fromDate,
    DateTime? toDate,
    int? accountId,
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

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final dayFormat = DateFormat('yyyy-MM-dd');
    final valueFormat = NumberFormat('0.00');
    final logo = await _loadCompanyLogo();
    final company = _companySettingsService.settings;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logo != null)
                  pw.Container(
                    width: 40,
                    height: 40,
                    margin: const pw.EdgeInsets.only(right: 8),
                    child: pw.Image(logo, fit: pw.BoxFit.contain),
                  ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        company.name,
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        '${'Address'.tr()}: ${company.address}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        '${'Phone'.tr()}: ${company.phonesText}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
                pw.Text(
                  '${'Generated'.tr()}: ${dateFormat.format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(color: PdfColors.grey400),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${'Page'.tr()} ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
        build: (_) => [
          pw.Text(
            'Expenses'.tr(),
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            '${'From'.tr()}: ${fromDate == null ? '-' : dayFormat.format(fromDate)}  |  ${'To'.tr()}: ${toDate == null ? '-' : dayFormat.format(toDate)}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Text(
            'Account Id: ${accountId ?? '-'}  |  ${'Show reversals'.tr()}: ${includeReversals ? 'Yes' : 'No'}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 10),
          pw.Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              pw.Text(
                '${'Gross Expenses'.tr()}: ${valueFormat.format(grossExpenses)}',
              ),
              pw.Text(
                '${'Net Expenses'.tr()}: ${valueFormat.format(netExpenses)}',
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: [
              'Date'.tr(),
              'Expense Category'.tr(),
              'Amount'.tr(),
              'Method'.tr(),
              'Notes (optional)'.tr(),
              'Type'.tr(),
            ],
            data: rows
                .map(
                  (row) => [
                    dateFormat.format(row.createdAt),
                    row.accountName,
                    valueFormat.format(row.amount),
                    row.paymentMethod == 'cash'
                        ? 'Cash'.tr()
                        : 'Vodafone Cash'.tr(),
                    row.notes?.trim().isNotEmpty == true
                        ? row.notes!.trim()
                        : 'No notes'.tr(),
                    row.amount >= 0 ? 'Expense'.tr() : 'Reversal'.tr(),
                  ],
                )
                .toList(growable: false),
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 6,
            ),
            cellAlignments: {2: pw.Alignment.centerRight},
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<pw.MemoryImage?> _loadCompanyLogo() async {
    final bytes = await _companySettingsService.loadLogoBytes();
    if (bytes == null) return null;
    return pw.MemoryImage(bytes);
  }
}
