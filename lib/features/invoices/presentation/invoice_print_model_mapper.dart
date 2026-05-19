import 'package:easy_localization/easy_localization.dart';
import 'package:delta_erp/features/invoices/domain/a4_invoice_view_data.dart';
import 'package:delta_erp/features/invoices/domain/invoice_print_model.dart';
import 'package:delta_erp/services/printing/printer_text_formatters.dart';

class InvoicePrintModelMapper {
  const InvoicePrintModelMapper({
    this.partyLabel = 'invoice.print.customer',
    this.formatter = const A4TextFormatter(),
  });

  final String partyLabel;
  final A4TextFormatter formatter;

  A4InvoiceViewData toA4ViewData(InvoicePrintModel model) {
    final money = NumberFormat('#,##0.00');
    final qtyFmt = NumberFormat('#,##0.##');

    var sumQty = 0.0;
    var sumDiscount = 0.0;
    var sumLine = 0.0;

    final lines = model.items
        .map((item) {
          sumQty += item.quantity;
          sumDiscount += item.discount;
          sumLine += item.resolvedLineTotal;
          return A4InvoiceLine(
            productName: formatter.format(item.productName),
            barcode: formatter.format(item.barcode),
            quantity: qtyFmt.format(item.quantity),
            unitPrice: money.format(item.unitPrice),
            discount: money.format(item.discount),
            lineTotal: money.format(item.resolvedLineTotal),
          );
        })
        .toList(growable: false);

    final policy = model.returnPolicyNote.trim().isNotEmpty
        ? model.returnPolicyNote
        : 'invoice.print.return_policy'.tr();

    return A4InvoiceViewData(
      companyName: formatter.format(model.companyName),
      address: formatter.format(model.address),
      phone: formatter.format(model.phone),
      title: formatter.format(model.title),
      invoiceNumber: formatter.format(model.invoiceNumber),
      issuedAt: model.date,
      partyLabel: formatter.format(partyLabel.tr()),
      partyName: formatter.format(model.customerName),
      cashierName: formatter.format(
        model.cashierName.isNotEmpty ? model.cashierName : '—',
      ),
      paidAmount: money.format(model.paidAmount),
      outstandingAmount: money.format(model.outstandingAmount),
      returnPolicyText: formatter.format(policy),
      lines: lines,
      totalsRow: A4InvoiceTotalsRow(
        totalQuantity: qtyFmt.format(sumQty),
        totalUnitPrice: '—',
        totalDiscount: money.format(sumDiscount),
        totalLineAmount: money.format(sumLine),
      ),
      total: model.total.toStringAsFixed(2),
      currency: model.currency,
      invoiceFooterNote: formatter.format(model.invoiceFooterNote),
      invoiceFooterImageBytes: model.invoiceFooterImageBytes,
      appIconBytes: model.appIconBytes,
      developerBrand: formatter.format(model.developerBrand),
      developerName: formatter.format(model.developerName),
      developerPhone: formatter.format(model.developerPhone),
    );
  }
}
