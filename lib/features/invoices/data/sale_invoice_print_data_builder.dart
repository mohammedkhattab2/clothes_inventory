import 'dart:typed_data';

import 'package:delta_erp/core/config/company_settings_service.dart';
import 'package:delta_erp/core/utils/invoice_number_display.dart';
import 'package:delta_erp/features/invoices/domain/a4_invoice_view_data.dart';
import 'package:delta_erp/features/invoices/domain/invoice_print_model.dart';
import 'package:delta_erp/services/database/app_database.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Loads sale invoice data for A4/thermal printing from the database.
class SaleInvoicePrintDataBuilder {
  SaleInvoicePrintDataBuilder(
    this._appDatabase,
    this._companySettingsService,
  );

  final AppDatabase _appDatabase;
  final CompanySettingsService _companySettingsService;

  static Uint8List? _cachedAppIconBytes;

  static Future<Uint8List?> loadAppIconBytes() async {
    if (_cachedAppIconBytes != null) return _cachedAppIconBytes;
    try {
      final data = await rootBundle.load('assets/icon/app_icon.png');
      _cachedAppIconBytes = data.buffer.asUint8List();
      return _cachedAppIconBytes;
    } catch (_) {
      return null;
    }
  }

  Future<InvoicePrintModel?> buildInvoicePrintModel(int saleId) async {
    final a4 = await buildA4ViewData(saleId);
    if (a4 == null) return null;

    final company = _companySettingsService.settings;
    final footerBytes = await _companySettingsService.loadFooterImageBytes();
    final appIcon = await loadAppIconBytes();

    final paid = double.tryParse(a4.paidAmount.replaceAll(',', '')) ?? 0;
    final outstanding =
        double.tryParse(a4.outstandingAmount.replaceAll(',', '')) ?? 0;
    final total = double.tryParse(a4.total.replaceAll(',', '')) ?? 0;

    return InvoicePrintModel(
      companyName: company.name,
      address: company.address,
      phone: company.phonesText,
      invoiceNumber: a4.invoiceNumber,
      date: a4.issuedAt,
      customerName: a4.partyName,
      items: a4.lines
          .map(
            (line) => InvoiceItem(
              productName: line.productName,
              barcode: line.barcode,
              quantity: double.tryParse(line.quantity) ?? 0,
              unitPrice: double.tryParse(line.unitPrice) ?? 0,
              discount: double.tryParse(line.discount) ?? 0,
              lineTotal: double.tryParse(line.lineTotal) ?? 0,
            ),
          )
          .toList(growable: false),
      total: total,
      title: a4.title,
      cashierName: a4.cashierName,
      paidAmount: paid,
      outstandingAmount: outstanding,
      returnPolicyNote: a4.returnPolicyText,
      invoiceFooterNote: company.invoiceFooterNote,
      invoiceFooterImageBytes: footerBytes,
      appIconBytes: appIcon,
      developerBrand: a4.developerBrand,
      developerName: a4.developerName,
      developerPhone: a4.developerPhone,
    );
  }

  Future<A4InvoiceViewData?> buildA4ViewData(int saleId) async {
    final db = await _appDatabase.database;
    final saleRows = await db.rawQuery(
      '''
      SELECT s.id, s.invoice_number, s.total_amount, s.created_at,
             COALESCE(a.name, 'Walk-in') AS customer_name,
             u.full_name AS seller_name,
             u.username AS seller_username
      FROM sales s
      LEFT JOIN accounts a ON a.id = s.account_id
      LEFT JOIN users u ON u.id = s.created_by_user_id
      WHERE s.id = ?
      LIMIT 1
      ''',
      [saleId],
    );
    if (saleRows.isEmpty) return null;

    final itemRows = await db.rawQuery(
      '''
      SELECT p.name AS product_name,
             COALESCE(p.barcode, '') AS barcode,
             si.quantity,
             si.unit_price,
             si.discount_amount,
             si.line_total,
             si.added_after_amendment
      FROM sale_items si
      JOIN products p ON p.id = si.product_id
      WHERE si.sale_id = ?
      ORDER BY si.id ASC
      ''',
      [saleId],
    );
    if (itemRows.isEmpty) return null;

    final sale = saleRows.first;
    final company = _companySettingsService.settings;
    final footerBytes = await _companySettingsService.loadFooterImageBytes();
    final appIcon = await loadAppIconBytes();

    final sellerName = (sale['seller_name']?.toString() ?? '').trim();
    final sellerUsername = (sale['seller_username']?.toString() ?? '').trim();
    final cashier = sellerName.isNotEmpty
        ? sellerName
        : (sellerUsername.isNotEmpty ? sellerUsername : '-');

    final totalAmount = ((sale['total_amount'] ?? 0) as num).toDouble();
    final paidRows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(
        CASE WHEN pay.reversal_for_id IS NULL THEN pay.amount ELSE 0 END
      ), 0) AS paid_amount
      FROM payments pay
      WHERE pay.invoice_type = 'sale' AND pay.invoice_id = ?
      ''',
      [saleId],
    );
    final paidAmount =
        ((paidRows.first['paid_amount'] ?? 0) as num).toDouble();
    final outstanding =
        (totalAmount - paidAmount).clamp(0, double.infinity).toDouble();

    final money = NumberFormat('#,##0.00');
    final qtyFmt = NumberFormat('#,##0.##');

    var sumQty = 0.0;
    var sumDiscount = 0.0;
    var sumLine = 0.0;

    final lines = itemRows.map((row) {
      final qty = ((row['quantity'] ?? 0) as num).toDouble();
      final unitPrice = ((row['unit_price'] ?? 0) as num).toDouble();
      final discount = ((row['discount_amount'] ?? 0) as num).toDouble();
      final lineTotal = ((row['line_total'] ?? 0) as num).toDouble();
      final isAdded =
          ((row['added_after_amendment'] ?? 0) as num).toInt() == 1;
      var name = (row['product_name'] as String?) ?? '-';
      if (isAdded) {
        name = '$name (${'sale.line_added_after_amendment'.tr()})';
      }

      sumQty += qty;
      sumDiscount += discount;
      sumLine += lineTotal;

      return A4InvoiceLine(
        productName: name,
        barcode: (row['barcode'] as String?) ?? '',
        quantity: qtyFmt.format(qty),
        unitPrice: money.format(unitPrice),
        discount: money.format(discount),
        lineTotal: money.format(lineTotal),
      );
    }).toList(growable: false);

    final rawNo = (sale['invoice_number'] as String?) ?? 'S-$saleId';
    final issuedAt =
        DateTime.tryParse((sale['created_at'] ?? '').toString()) ??
        DateTime.now();

    return A4InvoiceViewData(
      companyName: company.name,
      address: company.address,
      phone: company.phonesText,
      title: 'Sales Invoice'.tr(),
      invoiceNumber: displaySaleInvoiceNumber(
        id: saleId,
        rawInvoiceNumber: rawNo,
      ),
      issuedAt: issuedAt,
      partyLabel: 'invoice.print.customer'.tr(),
      partyName: (sale['customer_name'] as String?) ?? 'Walk-in'.tr(),
      cashierName: cashier,
      paidAmount: money.format(paidAmount),
      outstandingAmount: money.format(outstanding),
      returnPolicyText: 'invoice.print.return_policy'.tr(),
      lines: lines,
      totalsRow: A4InvoiceTotalsRow(
        totalQuantity: qtyFmt.format(sumQty),
        totalUnitPrice: '—',
        totalDiscount: money.format(sumDiscount),
        totalLineAmount: money.format(sumLine),
      ),
      total: money.format(totalAmount),
      currency: 'EGP',
      invoiceFooterNote: company.invoiceFooterNote,
      invoiceFooterImageBytes: footerBytes,
      appIconBytes: appIcon,
      developerBrand: 'invoice.print.developer_brand'.tr(),
      developerName: 'invoice.print.developer_name'.tr(),
      developerPhone: 'invoice.print.developer_phone'.tr(),
    );
  }
}
