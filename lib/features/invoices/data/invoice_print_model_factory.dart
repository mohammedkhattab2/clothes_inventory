import 'package:delta_erp/core/config/company_settings_service.dart';
import 'package:delta_erp/core/utils/invoice_number_display.dart';
import 'package:delta_erp/features/invoices/data/sale_invoice_print_data_builder.dart';
import 'package:delta_erp/features/invoices/domain/invoice_print_model.dart';
import 'package:delta_erp/features/purchases/data/purchases_repository.dart';
import 'package:delta_erp/services/database/app_database.dart';
import 'package:easy_localization/easy_localization.dart';

class InvoicePrintModelFactory {
  InvoicePrintModelFactory(
    this._salesPrintBuilder,
    this._purchasesRepository,
    this._appDatabase,
    this._companySettingsService,
  );

  final SaleInvoicePrintDataBuilder _salesPrintBuilder;
  final PurchasesRepository _purchasesRepository;
  final AppDatabase _appDatabase;
  final CompanySettingsService _companySettingsService;

  Future<InvoicePrintModel?> buildForSale(int saleId) =>
      _salesPrintBuilder.buildInvoicePrintModel(saleId);

  Future<InvoicePrintModel?> buildForPurchase(int purchaseId) async {
    final lines = await _purchasesRepository.listInvoiceLines(purchaseId);
    if (lines.isEmpty) return null;

    final db = await _appDatabase.database;
    final rows = await db.rawQuery(
      '''
      SELECT p.invoice_number, p.total_amount, p.created_at,
             COALESCE(a.name, '-') AS account_name
      FROM purchases p
      LEFT JOIN accounts a ON a.id = p.account_id
      WHERE p.id = ?
      LIMIT 1
      ''',
      [purchaseId],
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    final company = _companySettingsService.settings;
    final footerBytes = await _companySettingsService.loadFooterImageBytes();
    final appIcon = await SaleInvoicePrintDataBuilder.loadAppIconBytes();
    final rawNo = (row['invoice_number'] as String?) ?? 'P-$purchaseId';
    final total = ((row['total_amount'] ?? 0) as num).toDouble();

    return InvoicePrintModel(
      companyName: company.name,
      address: company.address,
      phone: company.phonesText,
      invoiceNumber: displayPurchaseInvoiceNumber(
        id: purchaseId,
        rawInvoiceNumber: rawNo,
      ),
      date: DateTime.parse(row['created_at'] as String),
      customerName: (row['account_name'] as String?) ?? '-',
      items: lines
          .map(
            (line) => InvoiceItem(
              productName: line.productName,
              quantity: line.quantity,
              unitPrice: line.unitPrice,
              lineTotal: line.lineTotal,
            ),
          )
          .toList(growable: false),
      total: total,
      title: 'Purchase Invoice'.tr(),
      invoiceFooterNote: company.invoiceFooterNote,
      invoiceFooterImageBytes: footerBytes,
      appIconBytes: appIcon,
    );
  }
}
