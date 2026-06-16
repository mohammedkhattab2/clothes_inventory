import 'package:flutter_test/flutter_test.dart';
import 'package:delta_erp/features/invoices/domain/invoice_print_model.dart';
import 'package:delta_erp/services/printing/invoice_print_preferences.dart';
import 'package:delta_erp/services/printing/invoice_printer.dart';
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

  test('defaults to thermal80 when thermal printer configured but type not saved',
      () async {
    SharedPreferences.setMockInitialValues({
      'thermal.printerName': 'XP-350B',
    });

    final config = await prefsService.load();

    expect(config.printerType, PrinterType.thermal80);
  });

  test('explicit printer type overrides thermal printer default', () async {
    SharedPreferences.setMockInitialValues({
      'thermal.printerName': 'XP-350B',
      'print.printerType': PrinterType.a4.name,
    });

    final config = await prefsService.load();

    expect(config.printerType, PrinterType.a4);
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
    expect(loaded.useImageFallback, isFalse);
  });

  test('clears stale image fallback when thermal printer configured', () async {
    SharedPreferences.setMockInitialValues({
      'thermal.printerName': 'XP-350B',
      'print.useImageFallback': true,
    });

    final config = await prefsService.load();

    expect(config.useImageFallback, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('print.useImageFallback'), isFalse);
  });

  test('preserves image fallback for A4 printing', () async {
    const target = InvoicePrintConfiguration(
      printerType: PrinterType.a4,
      printerSupportsArabic: true,
      useImageFallback: true,
    );

    await prefsService.save(target);
    final loaded = await prefsService.load();

    expect(loaded.useImageFallback, isTrue);
  });
}
