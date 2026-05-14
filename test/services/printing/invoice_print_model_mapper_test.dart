import 'package:flutter_test/flutter_test.dart';
import 'package:clothes_inventory/features/invoices/domain/invoice_print_model.dart';
import 'package:clothes_inventory/features/invoices/presentation/invoice_print_model_mapper.dart';

void main() {
  test('maps unified invoice model into A4 view data', () {
    const mapper = InvoicePrintModelMapper();
    final invoice = InvoicePrintModel(
      companyName: 'شركة المشد',
      address: 'طنطا',
      phone: '0100',
      invoiceNumber: 'P-1',
      date: DateTime(2026, 4, 5, 12, 30),
      customerName: 'خالد',
      items: const [
        InvoiceItem(productName: 'لبن', quantity: 2, unitPrice: 10),
        InvoiceItem(productName: 'جبنة', quantity: 1, unitPrice: 15),
      ],
      total: 35,
      currency: 'EGP',
      title: 'فاتورة مشتريات',
    );

    final data = mapper.toA4ViewData(invoice);

    expect(data.companyName, isNotEmpty);
    expect(data.companyName, 'شركة المشد');
    expect(data.partyName, 'خالد');
    expect(data.lines.first.productName, 'لبن');
    expect(data.invoiceNumber, isNotEmpty);
    expect(data.lines, hasLength(2));
    expect(data.lines.first.price, '20.00');
    expect(data.total, '35.00');
    expect(data.currency, 'EGP');
  });
}
