import 'dart:typed_data';

import 'package:delta_erp/features/invoices/domain/invoice_print_model.dart';
import 'package:delta_erp/services/printing/esc_pos_print_service.dart';
import 'package:delta_erp/services/printing/thermal_printer_preferences.dart';
import 'package:delta_erp/services/printing/thermal_raster_invoice_printer.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingPrintService extends EscPosPrintService {
  _RecordingPrintService({required super.printerPrefs});

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

bool _containsRasterHeader(Uint8List bytes) {
  for (var i = 0; i <= bytes.length - 3; i++) {
    if (bytes[i] == 0x1D && bytes[i + 1] == 0x76 && bytes[i + 2] == 0x30) {
      return true;
    }
  }
  return false;
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
    items: List.generate(
      20,
      (i) => InvoiceItem(productName: 'Product $i', quantity: 1, unitPrice: 25),
    ),
    total: 500,
  );

  test(
    'ThermalRasterInvoicePrinter sends one ESC/POS raster RAW job',
    () async {
      const prefs = ThermalPrinterPreferences();
      final printService = _RecordingPrintService(printerPrefs: prefs);
      final printer = ThermalRasterInvoicePrinter(
        paperWidthMm: 80,
        printerPrefs: prefs,
        printService: printService,
        rasterJobBuilder:
            ({
              required pdfBytes,
              required paperWidthMm,
              dpi = 203,
              feedLines = 2,
              cut = true,
            }) async =>
                Uint8List.fromList([0x1D, 0x76, 0x30, 0x00, 0x0A, 0x0A]),
      );

      await printer.print(invoice);

      expect(printService.calls, 1);
      expect(printService.lastJobName, 'invoice_S-100');
      expect(printService.lastBytes, isNotNull);
      expect(printService.lastBytes!.length, greaterThan(5));
      expect(_containsRasterHeader(printService.lastBytes!), isTrue);
    },
  );
}
