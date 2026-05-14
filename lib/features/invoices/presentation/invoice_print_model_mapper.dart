import 'package:clothes_inventory/features/invoices/domain/a4_invoice_view_data.dart';
import 'package:clothes_inventory/features/invoices/domain/invoice_print_model.dart';
import 'package:clothes_inventory/services/printing/printer_text_formatters.dart';

class InvoicePrintModelMapper {
  const InvoicePrintModelMapper({
    this.partyLabel = 'العميل',
    this.formatter = const A4TextFormatter(),
  });

  final String partyLabel;
  final A4TextFormatter formatter;

  A4InvoiceViewData toA4ViewData(InvoicePrintModel model) {
    return A4InvoiceViewData(
      companyName: formatter.format(model.companyName),
      address: formatter.format(model.address),
      phone: formatter.format(model.phone),
      title: formatter.format(model.title),
      invoiceNumber: formatter.format(model.invoiceNumber),
      issuedAt: model.date,
      partyLabel: formatter.format(partyLabel),
      partyName: formatter.format(model.customerName),
      lines: model.items
          .map(
            (item) => A4InvoiceLine(
              productName: formatter.format(item.productName),
              quantity: item.quantity.toStringAsFixed(0),
              price: item.lineTotal.toStringAsFixed(2),
            ),
          )
          .toList(growable: false),
      total: model.total.toStringAsFixed(2),
      currency: model.currency,
    );
  }
}
