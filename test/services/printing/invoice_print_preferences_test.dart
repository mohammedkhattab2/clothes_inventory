import 'package:flutter_test/flutter_test.dart';
import 'package:clothes_inventory/features/invoices/domain/invoice_print_model.dart';
import 'package:clothes_inventory/services/printing/invoice_print_preferences.dart';
import 'package:clothes_inventory/services/printing/invoice_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const prefsService = InvoicePrintPreferences();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loads defaults when no values saved', () async {
    final config = await prefsService.load();

    expect(config.printerType, PrinterType.a4);
    expect(config.printerSupportsArabic, isTrue);
    expect(config.useImageFallback, isFalse);
  });

  test('saves and reloads print configuration', () async {
    const target = InvoicePrintConfiguration(
      printerType: PrinterType.thermal80,
      printerSupportsArabic: false,
      useImageFallback: true,
    );

    await prefsService.save(target);
    final loaded = await prefsService.load();

    expect(loaded.printerType, PrinterType.thermal80);
    expect(loaded.printerSupportsArabic, isFalse);
    expect(loaded.useImageFallback, isTrue);
  });
}
