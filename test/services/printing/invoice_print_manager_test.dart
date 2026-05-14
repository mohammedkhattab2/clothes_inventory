import 'package:flutter_test/flutter_test.dart';
import 'package:clothes_inventory/features/invoices/domain/invoice_print_model.dart';
import 'package:clothes_inventory/services/printing/invoice_print_manager.dart';
import 'package:clothes_inventory/services/printing/invoice_printer.dart';

class _FakePrinter implements InvoicePrinter {
  _FakePrinter(this.name);

  final String name;
  int calls = 0;

  @override
  Future<void> print(InvoicePrintModel invoice) async {
    calls++;
  }
}

void main() {
  final invoice = InvoicePrintModel(
    companyName: 'شركة',
    address: 'عنوان',
    phone: '0100',
    invoiceNumber: '1',
    date: DateTime(2026, 4, 5),
    customerName: 'عميل',
    items: const [InvoiceItem(productName: 'منتج', quantity: 1, unitPrice: 10)],
    total: 10,
  );

  test('routes to A4 strategy', () async {
    final a4 = _FakePrinter('a4');
    final t58 = _FakePrinter('58');
    final t80 = _FakePrinter('80');
    final manager = InvoicePrintManager(
      a4Printer: a4,
      thermal58Printer: t58,
      thermal80Printer: t80,
    );

    await manager.printInvoice(
      invoice,
      const InvoicePrintConfiguration(printerType: PrinterType.a4),
    );

    expect(a4.calls, 1);
    expect(t58.calls, 0);
    expect(t80.calls, 0);
  });

  test('routes to thermal 58 strategy', () async {
    final a4 = _FakePrinter('a4');
    final t58 = _FakePrinter('58');
    final t80 = _FakePrinter('80');
    final manager = InvoicePrintManager(
      a4Printer: a4,
      thermal58Printer: t58,
      thermal80Printer: t80,
    );

    await manager.printInvoice(
      invoice,
      const InvoicePrintConfiguration(printerType: PrinterType.thermal58),
    );

    expect(a4.calls, 0);
    expect(t58.calls, 1);
    expect(t80.calls, 0);
  });

  test('routes to thermal 80 strategy', () async {
    final a4 = _FakePrinter('a4');
    final t58 = _FakePrinter('58');
    final t80 = _FakePrinter('80');
    final manager = InvoicePrintManager(
      a4Printer: a4,
      thermal58Printer: t58,
      thermal80Printer: t80,
    );

    await manager.printInvoice(
      invoice,
      const InvoicePrintConfiguration(printerType: PrinterType.thermal80),
    );

    expect(a4.calls, 0);
    expect(t58.calls, 0);
    expect(t80.calls, 1);
  });
}
