import 'package:delta_erp/features/invoices/domain/a4_invoice_view_data.dart';
import 'package:delta_erp/features/invoices/domain/invoice_print_model.dart';
import 'package:delta_erp/services/pdf/a4_invoice_pdf_document.dart';
import 'package:delta_erp/services/pdf/thermal_invoice_pdf_builder.dart';
import 'package:delta_erp/services/pdf/thermal_invoice_pdf_document.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

void main() {
  final sampleA4Data = A4InvoiceViewData(
    companyName: 'شركة تجريبية',
    address: 'طنطا - الغربية',
    phone: '01001234567',
    title: 'فاتورة بيع',
    invoiceNumber: 'S-1001',
    issuedAt: DateTime(2026, 4, 5, 14, 30),
    partyLabel: 'العميل',
    partyName: 'أحمد',
    cashierName: 'محمد',
    paidAmount: '100.00',
    outstandingAmount: '50.00',
    returnPolicyText: 'سياسة الإرجاع خلال 7 أيام',
    lines: const [
      A4InvoiceLine(
        productName: 'منتج أ',
        barcode: '123',
        quantity: '2',
        unitPrice: '45.00',
        discount: '5.00',
        lineTotal: '85.00',
      ),
    ],
    totalsRow: const A4InvoiceTotalsRow(
      totalQuantity: '2',
      totalUnitPrice: '—',
      totalDiscount: '5.00',
      totalLineAmount: '85.00',
    ),
    total: '150.00',
    currency: 'EGP',
    invoiceFooterNote: 'شكراً لتعاملكم معنا',
  );

  final sampleThermalInvoice = InvoicePrintModel(
    companyName: 'شركة تجريبية',
    address: 'طنطا',
    phone: '0100',
    invoiceNumber: 'S-1001',
    date: DateTime(2026, 4, 5, 14, 30),
    customerName: 'أحمد',
    cashierName: 'محمد',
    items: const [
      InvoiceItem(
        productName: 'منتج أ',
        barcode: '123',
        quantity: 2,
        unitPrice: 45,
        discount: 5,
        lineTotal: 85,
      ),
    ],
    total: 150,
    paidAmount: 100,
    outstandingAmount: 50,
    returnPolicyNote: 'سياسة الإرجاع',
    invoiceFooterNote: 'شكراً لتعاملكم معنا',
  );

  test('buildA4InvoicePdfDocument returns non-empty PDF bytes', () async {
    final bytes = await buildA4InvoicePdfDocument(data: sampleA4Data);
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('buildThermalInvoicePdfDocument returns non-empty PDF bytes', () async {
    for (final width in [58.0, 80.0]) {
      final bytes = await buildThermalInvoicePdfDocument(
        invoice: sampleThermalInvoice,
        paperWidthMm: width,
      );
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    }
  });

  test('buildThermalInvoicePdfDocument uses a single dynamic-height page', () async {
    final manyItemsInvoice = InvoicePrintModel(
      companyName: sampleThermalInvoice.companyName,
      address: sampleThermalInvoice.address,
      phone: sampleThermalInvoice.phone,
      invoiceNumber: sampleThermalInvoice.invoiceNumber,
      date: sampleThermalInvoice.date,
      customerName: sampleThermalInvoice.customerName,
      cashierName: sampleThermalInvoice.cashierName,
      items: List.generate(
        50,
        (index) => InvoiceItem(
          productName: 'منتج طويل الاسم رقم ${index + 1}',
          barcode: 'BC-${index + 1}',
          quantity: (index + 1).toDouble(),
          unitPrice: 10.0 + index,
          discount: 1,
          lineTotal: (10.0 + index) * (index + 1) - 1,
        ),
      ),
      total: sampleThermalInvoice.total,
      paidAmount: sampleThermalInvoice.paidAmount,
      outstandingAmount: sampleThermalInvoice.outstandingAmount,
      returnPolicyNote: sampleThermalInvoice.returnPolicyNote,
      invoiceFooterNote: sampleThermalInvoice.invoiceFooterNote,
    );

    final bytes = await buildThermalInvoicePdfDocument(
      invoice: manyItemsInvoice,
      paperWidthMm: 80,
    );
    final text = String.fromCharCodes(bytes);
    final pageCount = RegExp(r'/Type\s*/Page\b').allMatches(text).length;
    expect(pageCount, 1);

    final estimatedHeightMm =
        thermalEstimatedPageHeightMm(manyItemsInvoice, 80);
    final match =
        RegExp(r'/MediaBox\[0 0 ([\d.]+) ([\d.]+)\]').firstMatch(text);
    expect(match, isNotNull);
    expect(
      double.parse(match!.group(1)!),
      closeTo(80 * PdfPageFormat.mm, 0.01),
    );
    expect(
      double.parse(match.group(2)!),
      closeTo(estimatedHeightMm * PdfPageFormat.mm, 1.0),
    );
  });

  test('buildThermalInvoicePdfDocument handles many line items', () async {
    final manyItemsInvoice = InvoicePrintModel(
      companyName: sampleThermalInvoice.companyName,
      address: sampleThermalInvoice.address,
      phone: sampleThermalInvoice.phone,
      invoiceNumber: sampleThermalInvoice.invoiceNumber,
      date: sampleThermalInvoice.date,
      customerName: sampleThermalInvoice.customerName,
      cashierName: sampleThermalInvoice.cashierName,
      items: List.generate(
        50,
        (index) => InvoiceItem(
          productName: 'منتج طويل الاسم رقم ${index + 1}',
          barcode: 'BC-${index + 1}',
          quantity: (index + 1).toDouble(),
          unitPrice: 10.0 + index,
          discount: 1,
          lineTotal: (10.0 + index) * (index + 1) - 1,
        ),
      ),
      total: sampleThermalInvoice.total,
      paidAmount: sampleThermalInvoice.paidAmount,
      outstandingAmount: sampleThermalInvoice.outstandingAmount,
      returnPolicyNote: sampleThermalInvoice.returnPolicyNote,
      invoiceFooterNote: sampleThermalInvoice.invoiceFooterNote,
    );

    final shortBytes = await buildThermalInvoicePdfDocument(
      invoice: sampleThermalInvoice,
      paperWidthMm: 58,
    );
    final bytes = await buildThermalInvoicePdfDocument(
      invoice: manyItemsInvoice,
      paperWidthMm: 58,
    );
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(bytes.length, greaterThan(shortBytes.length));
  });
}
