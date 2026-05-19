import 'dart:typed_data';

enum PrinterType { a4, thermal58, thermal80 }

class InvoiceItem {
  const InvoiceItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.barcode = '',
    this.discount = 0,
    this.lineTotal,
  });

  final String productName;
  final double quantity;
  final double unitPrice;
  final String barcode;
  final double discount;
  final double? lineTotal;

  double get resolvedLineTotal =>
      lineTotal ?? (quantity * unitPrice - discount).clamp(0, double.infinity);

  /// Back-compat alias for thermal/simple layouts.
  double get effectiveLineTotal => resolvedLineTotal;
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
    this.cashierName = '',
    this.paidAmount = 0,
    this.outstandingAmount = 0,
    this.returnPolicyNote = '',
    this.invoiceFooterNote = '',
    this.invoiceFooterImageBytes,
    this.appIconBytes,
    this.developerBrand = 'deltadev',
    this.developerName = 'ENG. Abd-elrahaman',
    this.developerPhone = '01010772643',
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
  final String cashierName;
  final double paidAmount;
  final double outstandingAmount;
  final String returnPolicyNote;
  /// Shown at bottom of printed invoice (from company settings).
  final String invoiceFooterNote;
  final Uint8List? invoiceFooterImageBytes;
  final Uint8List? appIconBytes;
  final String developerBrand;
  final String developerName;
  final String developerPhone;
}
