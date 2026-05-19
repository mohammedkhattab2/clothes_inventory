import 'dart:io';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:delta_erp/core/config/company_settings_service.dart';
import 'package:delta_erp/features/invoices/domain/a4_invoice_view_data.dart';
import 'package:delta_erp/services/database/app_database.dart';
import 'package:delta_erp/services/pdf/a4_invoice_rtl_pdf_builder.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PurchaseInvoicePdfService {
  const PurchaseInvoicePdfService(
    this._appDatabase,
    this._companySettingsService,
  );

  final AppDatabase _appDatabase;
  final CompanySettingsService _companySettingsService;

  Future<Uint8List> generateA4Invoice(int purchaseId) async {
    final db = await _appDatabase.database;

    final purchaseRows = await db.rawQuery(
      '''
      SELECT p.id, p.invoice_number, p.total_amount, p.created_at,
            a.name AS supplier_name,
            u.full_name AS seller_name,
            u.username AS seller_username,
            um.full_name AS modifier_name,
            um.username AS modifier_username
      FROM purchases p
      LEFT JOIN accounts a ON a.id = p.account_id
      LEFT JOIN users u ON u.id = p.created_by_user_id
      LEFT JOIN users um ON um.id = p.last_modified_by_user_id
      WHERE p.id = ?
      LIMIT 1
      ''',
      [purchaseId],
    );

    if (purchaseRows.isEmpty) {
      throw StateError('Purchase not found for PDF generation.'.tr());
    }

    final items = await db.rawQuery(
      '''
      SELECT pi.quantity, pi.unit_price, pi.discount_amount, pi.line_total, pr.name
      FROM purchase_items pi
      JOIN products pr ON pr.id = pi.product_id
      WHERE pi.purchase_id = ?
      ORDER BY pi.id ASC
      ''',
      [purchaseId],
    );

    final purchase = purchaseRows.first;
    final sellerName = (purchase['seller_name']?.toString() ?? '').trim();
    final sellerUsername = (purchase['seller_username']?.toString() ?? '')
        .trim();
    final issuedBy = sellerName.isNotEmpty
        ? sellerName
        : (sellerUsername.isNotEmpty ? sellerUsername : null);
    final modName = (purchase['modifier_name']?.toString() ?? '').trim();
    final modUser = (purchase['modifier_username']?.toString() ?? '').trim();
    final lastModifiedBy = modName.isNotEmpty
        ? modName
        : (modUser.isNotEmpty ? modUser : null);
    final company = _companySettingsService.settings;
    var sumQty = 0.0;
    var sumLine = 0.0;
    final lines = items.map((row) {
      final qty = (row['quantity'] as num).toDouble();
      final lineTotal = (row['line_total'] as num).toDouble();
      sumQty += qty;
      sumLine += lineTotal;
      return A4InvoiceLine(
        productName: row['name']?.toString() ?? '-',
        barcode: '',
        quantity: qty.toStringAsFixed(0),
        unitPrice: lineTotal.toStringAsFixed(2),
        discount: '0.00',
        lineTotal: lineTotal.toStringAsFixed(2),
      );
    }).toList(growable: false);

    final invoiceData = A4InvoiceViewData(
      companyName: company.name,
      address: company.address,
      phone: company.phonesText,
      title: 'Purchase Invoice'.tr(),
      invoiceNumber: purchase['invoice_number']?.toString() ?? '-',
      issuedAt:
          DateTime.tryParse((purchase['created_at'] ?? '').toString()) ??
          DateTime.now(),
      partyLabel: 'Supplier'.tr(),
      partyName: purchase['supplier_name']?.toString() ?? '-',
      cashierName: issuedBy ?? '—',
      issuedBy: issuedBy,
      lastModifiedBy: lastModifiedBy,
      lines: lines,
      totalsRow: A4InvoiceTotalsRow(
        totalQuantity: sumQty.toStringAsFixed(0),
        totalUnitPrice: '—',
        totalDiscount: '0.00',
        totalLineAmount: sumLine.toStringAsFixed(2),
      ),
      total: (purchase['total_amount'] as num).toStringAsFixed(2),
      invoiceFooterNote: company.invoiceFooterNote,
      invoiceFooterImageBytes:
          await _companySettingsService.loadFooterImageBytes(),
    );
    final doc = await _createDocumentWithSafeFonts();
    final companyLogo = await _loadCompanyLogo();

    buildA4RtlInvoicePage(document: doc, data: invoiceData, logo: companyLogo);

    return doc.save();
  }

  Future<void> printInvoice(int purchaseId) async {
    if (purchaseId <= 0) {
      throw ArgumentError('purchaseId must be greater than zero.'.tr());
    }

    final bytes = await generateA4Invoice(purchaseId);
    try {
      final ok = await Printing.layoutPdf(
        name: 'purchase_invoice_$purchaseId',
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
        fileNamePrefix: 'purchase_invoice_$purchaseId',
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
