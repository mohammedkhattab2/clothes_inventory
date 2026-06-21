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

  test('buildThermalInvoicePdfDocument uses one continuous roll page', () async {
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
    expect(estimatedHeightMm, greaterThan(100.0));

    final match =
        RegExp(r'/MediaBox\[0 0 ([\d.]+) ([\d.]+)\]').firstMatch(text);
    expect(match, isNotNull);
    expect(
      double.parse(match!.group(1)!),
      closeTo(80 * PdfPageFormat.mm, 0.01),
    );
    expect(
      double.parse(match.group(2)!),
      closeTo(estimatedHeightMm * PdfPageFormat.mm, 2.0),
    );
  });

  test('planThermalInvoicePrintStrips splits long receipts for 350B driver', () {
    final sevenItemsInvoice = InvoicePrintModel(
      companyName: sampleThermalInvoice.companyName,
      address: sampleThermalInvoice.address,
      phone: sampleThermalInvoice.phone,
      invoiceNumber: sampleThermalInvoice.invoiceNumber,
      date: sampleThermalInvoice.date,
      customerName: sampleThermalInvoice.customerName,
      cashierName: sampleThermalInvoice.cashierName,
      items: List.generate(
        7,
        (index) => InvoiceItem(
          productName: 'منتج ${index + 1}',
          barcode: 'BC-${index + 1}',
          quantity: 1,
          unitPrice: 100,
          discount: 0,
          lineTotal: 100,
        ),
      ),
      total: 700,
      paidAmount: 700,
      returnPolicyNote: sampleThermalInvoice.returnPolicyNote,
      invoiceFooterNote: sampleThermalInvoice.invoiceFooterNote,
    );

    final strips = planThermalInvoicePrintStrips(
      invoice: sevenItemsInvoice,
      paperWidthMm: 80,
    );

    expect(strips.length, greaterThan(1));
    for (final strip in strips) {
      expect(strip.pageHeightMm, lessThanOrEqualTo(109.001));
      expect(strip.widgets, isNotEmpty);
    }
  });

  test('planThermalInvoicePrintStrips packs every segment within driver height',
      () {
    final minimalInvoice = InvoicePrintModel(
      companyName: sampleThermalInvoice.companyName,
      address: sampleThermalInvoice.address,
      phone: sampleThermalInvoice.phone,
      invoiceNumber: sampleThermalInvoice.invoiceNumber,
      date: sampleThermalInvoice.date,
      customerName: sampleThermalInvoice.customerName,
      items: const [
        InvoiceItem(
          productName: 'منتج',
          barcode: '100',
          quantity: 1,
          unitPrice: 10,
          discount: 0,
          lineTotal: 10,
        ),
      ],
      total: 10,
    );

    final segments = buildThermalReceiptSegments(
      invoice: minimalInvoice,
      paperWidthMm: 80,
    );
    final strips = planThermalInvoicePrintStrips(
      invoice: minimalInvoice,
      paperWidthMm: 80,
    );

    for (final strip in strips) {
      expect(strip.pageHeightMm, lessThanOrEqualTo(109.001));
    }

    final packedWidgets = strips.fold<int>(
      0,
      (sum, strip) => sum + strip.widgets.length,
    );
    expect(packedWidgets, segments.length);
  });

  test('buildThermalInvoicePdfDocument keeps medium receipts on one page', () async {
    final sevenItemsInvoice = InvoicePrintModel(
      companyName: sampleThermalInvoice.companyName,
      address: sampleThermalInvoice.address,
      phone: sampleThermalInvoice.phone,
      invoiceNumber: sampleThermalInvoice.invoiceNumber,
      date: sampleThermalInvoice.date,
      customerName: sampleThermalInvoice.customerName,
      cashierName: sampleThermalInvoice.cashierName,
      items: List.generate(
        7,
        (index) => InvoiceItem(
          productName: 'منتج ${index + 1}',
          barcode: 'BC-${index + 1}',
          quantity: 1,
          unitPrice: 100,
          discount: 0,
          lineTotal: 100,
        ),
      ),
      total: 700,
      paidAmount: 700,
      returnPolicyNote: sampleThermalInvoice.returnPolicyNote,
      invoiceFooterNote: sampleThermalInvoice.invoiceFooterNote,
    );

    final bytes = await buildThermalInvoicePdfDocument(
      invoice: sevenItemsInvoice,
      paperWidthMm: 80,
    );
    final text = String.fromCharCodes(bytes);
    final pageCount = RegExp(r'/Type\s*/Page\b').allMatches(text).length;
    expect(pageCount, 1);

    final estimatedHeightMm = thermalEstimatedPageHeightMm(sevenItemsInvoice, 80);
    final match =
        RegExp(r'/MediaBox\[0 0 ([\d.]+) ([\d.]+)\]').firstMatch(text);
    expect(match, isNotNull);
    expect(
      double.parse(match!.group(2)!),
      closeTo(estimatedHeightMm * PdfPageFormat.mm, 2.0),
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

  test('thermalEstimatedPageHeightMm grows with long footer note', () {
    const shortFooter = 'شكراً';
    const longFooter =
        'شكراً لتعاملكم معنا. '
        'للاستبدال خلال 7 أيام مع الفاتورة. '
        'لا يتم استرداد النقد بعد 14 يوماً.';

    final base = InvoicePrintModel(
      companyName: sampleThermalInvoice.companyName,
      address: sampleThermalInvoice.address,
      phone: sampleThermalInvoice.phone,
      invoiceNumber: sampleThermalInvoice.invoiceNumber,
      date: sampleThermalInvoice.date,
      customerName: sampleThermalInvoice.customerName,
      items: sampleThermalInvoice.items,
      total: sampleThermalInvoice.total,
      invoiceFooterNote: shortFooter,
    );
    final long = InvoicePrintModel(
      companyName: base.companyName,
      address: base.address,
      phone: base.phone,
      invoiceNumber: base.invoiceNumber,
      date: base.date,
      customerName: base.customerName,
      items: base.items,
      total: base.total,
      invoiceFooterNote: longFooter,
    );

    final shortHeight = thermalEstimatedPageHeightMm(base, 80);
    final longHeight = thermalEstimatedPageHeightMm(long, 80);

    expect(longHeight, greaterThan(shortHeight));
    expect(shortHeight, greaterThan(100.0));
  });
}
