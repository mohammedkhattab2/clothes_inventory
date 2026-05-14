class A4InvoiceLine {
  const A4InvoiceLine({
    required this.productName,
    required this.quantity,
    required this.price,
  });

  final String productName;
  final String quantity;
  final String price;
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
    this.issuedBy,
    required this.lines,
    required this.total,
    this.currency = '',
  });

  final String companyName;
  final String address;
  final String phone;
  final String title;
  final String invoiceNumber;
  final DateTime issuedAt;
  final String partyLabel;
  final String partyName;
  final String? issuedBy;
  final List<A4InvoiceLine> lines;
  final String total;
  final String currency;
}
