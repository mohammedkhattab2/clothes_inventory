import 'dart:typed_data';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:delta_erp/core/config/company_settings_service.dart';
import 'package:delta_erp/features/invoices/domain/a4_invoice_view_data.dart';
import 'package:delta_erp/services/database/app_database.dart';
import 'package:delta_erp/services/pdf/a4_invoice_rtl_pdf_builder.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class SalesInvoicePdfService {
  const SalesInvoicePdfService(this._appDatabase, this._companySettingsService);

  final AppDatabase _appDatabase;
  final CompanySettingsService _companySettingsService;

  Future<Uint8List> generateA4Invoice(int saleId) async {
    final db = await _appDatabase.database;

    final saleRows = await db.rawQuery(
      '''
      SELECT s.id, s.invoice_number, s.total_amount, s.created_at,
            a.name AS customer_name,
            u.full_name AS seller_name,
            u.username AS seller_username,
            um.full_name AS modifier_name,
            um.username AS modifier_username
      FROM sales s
      LEFT JOIN accounts a ON a.id = s.account_id
      LEFT JOIN users u ON u.id = s.created_by_user_id
      LEFT JOIN users um ON um.id = s.last_modified_by_user_id
      WHERE s.id = ?
      LIMIT 1
      ''',
      [saleId],
    );

    if (saleRows.isEmpty) {
      throw StateError('Sale not found for PDF generation.'.tr());
    }

    final items = await db.rawQuery(
      '''
      SELECT si.quantity, si.unit_price, si.discount_amount, si.line_total, p.name
      FROM sale_items si
      JOIN products p ON p.id = si.product_id
      WHERE si.sale_id = ?
      ORDER BY si.id ASC
      ''',
      [saleId],
    );

    final sale = saleRows.first;
    final sellerName = (sale['seller_name']?.toString() ?? '').trim();
    final sellerUsername = (sale['seller_username']?.toString() ?? '').trim();
    final issuedBy = sellerName.isNotEmpty
        ? sellerName
        : (sellerUsername.isNotEmpty ? sellerUsername : null);
    final modName = (sale['modifier_name']?.toString() ?? '').trim();
    final modUser = (sale['modifier_username']?.toString() ?? '').trim();
    final lastModifiedBy = modName.isNotEmpty
        ? modName
        : (modUser.isNotEmpty ? modUser : null);
    final company = _companySettingsService.settings;
    final invoiceData = A4InvoiceViewData(
      companyName: company.name,
      address: 'العنوان: ${company.address}',
      phone: 'التليفون: ${company.phonesText}',
      title: 'Sales Invoice'.tr(),
      invoiceNumber: sale['invoice_number']?.toString() ?? '-',
      issuedAt:
          DateTime.tryParse((sale['created_at'] ?? '').toString()) ??
          DateTime.now(),
      partyLabel: 'Customer'.tr(),
      partyName: sale['customer_name']?.toString() ?? 'Walk-in'.tr(),
      issuedBy: issuedBy,
      lastModifiedBy: lastModifiedBy,
      lines: items
          .map(
            (row) => A4InvoiceLine(
              productName: row['name']?.toString() ?? '-',
              quantity: (row['quantity'] as num).toStringAsFixed(0),
              price: (row['line_total'] as num).toStringAsFixed(2),
            ),
          )
          .toList(growable: false),
      total: (sale['total_amount'] as num).toStringAsFixed(2),
      invoiceFooterNote: company.invoiceFooterNote,
      invoiceFooterImageBytes: await _companySettingsService.loadFooterImageBytes(),
    );
    final doc = await _createDocumentWithSafeFonts();
    final companyLogo = await _loadCompanyLogo();

    buildA4RtlInvoicePage(
      document: doc,
      data: invoiceData,
      logo: companyLogo,
    );

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
      // Fallback for environments where native print dialog is unavailable.
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

      // Some Windows setups do not register the Print verb for PDFs.
      // In that case, open the file so the user can print manually.
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

    if (Platform.isMacOS || Platform.isLinux) {
      final result = await Process.run('lp', [file.path]);
      if (result.exitCode != 0) {
        throw StateError(
          '${'Failed to send invoice to printer.'.tr()} ${result.stderr}'
              .trim(),
        );
      }
      return;
    }

    throw UnsupportedError('Printing is not supported on this platform.'.tr());
  }

  Future<File> _saveTempPdf(
    Uint8List bytes, {
    required String fileNamePrefix,
  }) async {
    final dir = await getTemporaryDirectory();
    final fileName =
        '${fileNamePrefix}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<pw.MemoryImage?> _loadCompanyLogo() async {
    final bytes = await _companySettingsService.loadLogoBytes();
    if (bytes == null) return null;
    return pw.MemoryImage(bytes);
  }

  Future<pw.Document> _createDocumentWithSafeFonts() async {
    try {
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
    } catch (e) {
      if (_isArabicLocale()) {
        throw StateError(
          'تعذر تحميل خط عربي للطباعة. تأكد من الاتصال بالإنترنت ثم أعد المحاولة. ($e)',
        );
      }
      return pw.Document();
    }
  }

  bool _isArabicLocale() =>
      Intl.getCurrentLocale().toLowerCase().startsWith('ar');
}
