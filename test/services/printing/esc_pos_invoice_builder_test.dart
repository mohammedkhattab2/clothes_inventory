import 'package:delta_erp/features/invoices/domain/invoice_print_model.dart';
import 'package:delta_erp/services/printing/esc_pos_invoice_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final invoice = InvoicePrintModel(
    companyName: 'ZERO JEANS',
    address: 'Cairo',
    phone: '0100',
    invoiceNumber: 'S-100',
    date: DateTime(2026, 6, 4, 14, 30),
    customerName: 'Customer',
    cashierName: 'Admin',
    items: [
      InvoiceItem(productName: 'Jeans', quantity: 2, unitPrice: 200),
    ],
    total: 400,
    paidAmount: 200,
    outstandingAmount: 200,
    returnPolicyNote: 'سياسة الاسترجاع',
    invoiceFooterNote: 'شكراً',
  );

  group('EscPosInvoiceBuilder', () {
    test('build emits ESC/POS reset and invoice fields', () async {
      final bytes = await EscPosInvoiceBuilder.build(
        invoice: invoice,
        paperWidthMm: 80,
        printerSupportsArabic: true,
      );

      expect(bytes, isNotEmpty);
      expect(bytes.contains(0x1B), isTrue);
      expect(bytes.contains(0x40), isTrue);
      final text = String.fromCharCodes(bytes);
      expect(text.contains('S-100'), isTrue);
      expect(text.contains('ZERO JEANS'), isTrue);
    });

    test('rejects image fallback mode', () async {
      await expectLater(
        EscPosInvoiceBuilder.build(
          invoice: invoice,
          paperWidthMm: 80,
          printerSupportsArabic: true,
          preferImageFallback: true,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
