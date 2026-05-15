import 'dart:typed_data';

enum PrinterType { a4, thermal58, thermal80 }

class InvoiceItem {
  const InvoiceItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  final String productName;
  final double quantity;
  final double unitPrice;

  double get lineTotal => quantity * unitPrice;
}

class InvoicePrintModel {
  const InvoicePrintModel({
    required this.companyName,
    required this.address,
    required this.phone,
    required this.invoiceNumber,
    required this.date,
    required this.customerName,
    required this.items,
    required this.total,
    this.currency = 'EGP',
    this.title = 'فاتورة',
    this.invoiceFooterNote = '',
    this.invoiceFooterImageBytes,
  });

  final String companyName;
  final String address;
  final String phone;
  final String invoiceNumber;
  final DateTime date;
  final String customerName;
  final List<InvoiceItem> items;
  final double total;
  final String currency;
  final String title;
  /// Shown at bottom of printed invoice (from company settings).
  final String invoiceFooterNote;
  final Uint8List? invoiceFooterImageBytes;
}
