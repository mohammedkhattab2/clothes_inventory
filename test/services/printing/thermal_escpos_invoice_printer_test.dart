import 'dart:typed_data';

import 'package:delta_erp/features/invoices/domain/invoice_print_model.dart';
import 'package:delta_erp/services/printing/esc_pos_print_service.dart';
import 'package:delta_erp/services/printing/invoice_print_preferences.dart';
import 'package:delta_erp/services/printing/invoice_printer.dart';
import 'package:delta_erp/services/printing/thermal_escpos_invoice_printer.dart';
import 'package:delta_erp/services/printing/thermal_printer_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingPrintService extends EscPosPrintService {
  _RecordingPrintService({required ThermalPrinterPreferences printerPrefs})
      : super(printerPrefs: printerPrefs);

  int calls = 0;
  Uint8List? lastBytes;
  String? lastJobName;

  @override
  Future<void> printEscPosBytes({
    required String jobName,
    required Uint8List bytes,
  }) async {
    calls++;
    lastJobName = jobName;
    lastBytes = bytes;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final invoice = InvoicePrintModel(
    companyName: 'ZERO JEANS',
    address: 'Cairo',
    phone: '0100',
    invoiceNumber: 'S-100',
    date: DateTime(2026, 6, 4),
    customerName: 'Customer',
    items: [
      InvoiceItem(productName: 'Jeans', quantity: 1, unitPrice: 200),
    ],
    total: 200,
  );

  test('ThermalEscPosInvoicePrinter sends one ESC/POS RAW job', () async {
    SharedPreferences.setMockInitialValues({});

    const prefs = ThermalPrinterPreferences();
    final printService = _RecordingPrintService(printerPrefs: prefs);
    final printer = ThermalEscPosInvoicePrinter(
      paperWidthMm: 80,
      printerPrefs: prefs,
      printService: printService,
      invoicePrefs: const InvoicePrintPreferences(),
    );

    await printer.print(invoice);

    expect(printService.calls, 1);
    expect(printService.lastJobName, 'invoice_S-100');
    expect(printService.lastBytes, isNotNull);
    expect(printService.lastBytes!.length, greaterThan(20));
  });

  test('ThermalEscPosInvoicePrinter ignores saved image fallback preference',
      () async {
    SharedPreferences.setMockInitialValues({
      'print.printerType': PrinterType.thermal80.name,
      'print.useImageFallback': true,
    });

    const prefs = ThermalPrinterPreferences();
    final printService = _RecordingPrintService(printerPrefs: prefs);
    final printer = ThermalEscPosInvoicePrinter(
      paperWidthMm: 80,
      printerPrefs: prefs,
      printService: printService,
      invoicePrefs: const InvoicePrintPreferences(),
    );

    await expectLater(printer.print(invoice), completes);
    expect(printService.calls, 1);
  });
}
