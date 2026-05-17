import 'package:delta_erp/features/invoices/domain/invoice_print_model.dart';
import 'package:delta_erp/services/printing/invoice_print_manager.dart';
import 'package:delta_erp/services/printing/invoice_printer.dart';

Future<void> printInvoiceExample({
  required InvoicePrintManager manager,
  required PrinterType selectedPrinter,
}) async {
  final invoice = InvoicePrintModel(
    companyName: 'شركة المشد للتجارة الحديثة',
    address: 'طنطا - أول ميت حبيش - عمارة المشد',
    phone: '+201017149438',
    invoiceNumber: 'P-1775',
    date: DateTime.now(),
    customerName: 'خالد خطاب',
    items: const [
      InvoiceItem(productName: 'لبن', quantity: 2, unitPrice: 10),
      InvoiceItem(productName: 'زيت', quantity: 1, unitPrice: 25),
    ],
    total: 45,
    title: 'فاتورة مشتريات',
  );

  final config = InvoicePrintConfiguration(printerType: selectedPrinter);
  await manager.printInvoice(invoice, config);
}
