import 'dart:typed_data';

class A4InvoiceLine {
  const A4InvoiceLine({
    required this.productName,
    required this.barcode,
    required this.quantity,
    required this.unitPrice,
    required this.discount,
    required this.lineTotal,
  });

  final String productName;
  final String barcode;
  final String quantity;
  final String unitPrice;
  final String discount;
  final String lineTotal;
}

class A4InvoiceTotalsRow {
  const A4InvoiceTotalsRow({
    required this.totalQuantity,
    required this.totalUnitPrice,
    required this.totalDiscount,
    required this.totalLineAmount,
  });

  final String totalQuantity;
  final String totalUnitPrice;
  final String totalDiscount;
  final String totalLineAmount;
}

class A4InvoiceViewData {
  const A4InvoiceViewData({
    required this.companyName,
    required this.address,
    required this.phone,
    required this.title,
    required this.invoiceNumber,
    required this.issuedAt,
    required this.partyLabel,
    required this.partyName,
    required this.lines,
    required this.totalsRow,
    required this.total,
    this.cashierName = '',
    this.paidAmount = '',
    this.outstandingAmount = '',
    this.returnPolicyText = '',
    this.issuedBy,
    this.lastModifiedBy,
    this.currency = '',
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
  final String title;
  final String invoiceNumber;
  final DateTime issuedAt;
  final String partyLabel;
  final String partyName;
  final String cashierName;
  final String paidAmount;
  final String outstandingAmount;
  final String returnPolicyText;
  final String? issuedBy;
  final String? lastModifiedBy;
  final List<A4InvoiceLine> lines;
  final A4InvoiceTotalsRow totalsRow;
  final String total;
  final String currency;
  final String invoiceFooterNote;
  final Uint8List? invoiceFooterImageBytes;
  final Uint8List? appIconBytes;
  final String developerBrand;
  final String developerName;
  final String developerPhone;
}
