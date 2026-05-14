import 'package:clothes_inventory/features/invoices/domain/invoice_print_model.dart';

abstract class InvoicePrinter {
  Future<void> print(InvoicePrintModel invoice);
}

class InvoicePrintConfiguration {
  const InvoicePrintConfiguration({
    required this.printerType,
    this.printerSupportsArabic = true,
    this.useImageFallback = false,
  });

  final PrinterType printerType;
  final bool printerSupportsArabic;
  final bool useImageFallback;
}
