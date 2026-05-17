import 'dart:developer' as dev;
import 'dart:io';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:delta_erp/features/accounts/data/accounts_repository.dart';
class ContactsDirectoryPdfService {
  const ContactsDirectoryPdfService();

  Future<String> exportToPdf({
    required List<AccountLookup> accounts,
    required String title,
    required String targetPath,
  }) async {
    try {
      final bytes = await _buildPdf(accounts: accounts, title: title);

      final file = File(targetPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (e, st) {
      dev.log(
        'Failed exporting contacts PDF',
        name: 'ContactsDirectoryPdfService',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<Uint8List> _buildPdf({
    required List<AccountLookup> accounts,
    required String title,
  }) async {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
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
        textDirection: pw.TextDirection.rtl,
        build: (context) {
          return [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              '${'Generated'.tr()}: ${dateFormat.format(DateTime.now())}',
            ),
            pw.Text('${'Total rows'.tr()}: ${accounts.length}'),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                font: boldFont,
              ),
              cellStyle: pw.TextStyle(font: baseFont),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellAlignment: pw.Alignment.centerRight,
              headerAlignment: pw.Alignment.centerRight,
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 4,
              ),
              headers: [
                'contacts.export_col_id'.tr(),
                'contacts.export_col_name'.tr(),
                'contacts.export_col_phone'.tr(),
                'contacts.export_col_type'.tr(),
              ],
              data: accounts
                  .map(
                    (a) => [
                      '${a.id}',
                      a.name,
                      (a.phone ?? '').trim().isEmpty ? '—' : a.phone!.trim(),
                      a.accountType,
                    ],
                  )
                  .toList(),
            ),
          ];
        },
      ),
    );

    return doc.save();
  }
}
