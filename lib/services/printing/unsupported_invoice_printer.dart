import 'package:delta_erp/features/invoices/domain/invoice_print_model.dart';
import 'package:delta_erp/services/printing/invoice_printer.dart';

class UnsupportedInvoicePrinter implements InvoicePrinter {
  const UnsupportedInvoicePrinter(this.message);

  final String message;

  @override
  Future<void> print(InvoicePrintModel invoice) {
    throw UnsupportedError(message);
  }
}
