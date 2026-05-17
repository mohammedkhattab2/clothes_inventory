import 'package:delta_erp/features/invoices/domain/invoice_print_model.dart';
import 'package:delta_erp/services/printing/invoice_printer.dart';

class InvoicePrintManager {
  const InvoicePrintManager({
    required this.a4Printer,
    required this.thermal58Printer,
    required this.thermal80Printer,
  });

  final InvoicePrinter a4Printer;
  final InvoicePrinter thermal58Printer;
  final InvoicePrinter thermal80Printer;

  Future<void> printInvoice(
    InvoicePrintModel invoice,
    InvoicePrintConfiguration config,
  ) {
    switch (config.printerType) {
      case PrinterType.a4:
        return a4Printer.print(invoice);
      case PrinterType.thermal58:
        return thermal58Printer.print(invoice);
      case PrinterType.thermal80:
        return thermal80Printer.print(invoice);
    }
  }
}
