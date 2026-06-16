import 'package:delta_erp/features/invoices/domain/invoice_print_model.dart';
import 'package:delta_erp/services/printing/invoice_printer.dart';
import 'package:delta_erp/services/printing/thermal_printer_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InvoicePrintPreferences {
  const InvoicePrintPreferences();

  static const _keyPrinterType = 'print.printerType';
  static const _keySupportsArabic = 'print.supportsArabic';
  static const _keyUseImageFallback = 'print.useImageFallback';

  Future<InvoicePrintConfiguration> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPrinterType = prefs.getString(_keyPrinterType);

    var useImageFallback = prefs.getBool(_keyUseImageFallback) ?? false;

    const thermalPrefs = ThermalPrinterPreferences();
    final thermalName = await thermalPrefs.loadPrinterName();
    final hasThermalPrinter = thermalName != null && thermalName.isNotEmpty;

    final PrinterType printerType;
    if (savedPrinterType != null) {
      printerType = _parsePrinterType(savedPrinterType);
    } else {
      printerType = hasThermalPrinter ? PrinterType.thermal80 : PrinterType.a4;
    }

    final isThermalType =
        printerType == PrinterType.thermal58 ||
        printerType == PrinterType.thermal80;

    // ESC/POS thermal path is text-only; image fallback applied to A4/PDF only.
    if (isThermalType || hasThermalPrinter) {
      if (useImageFallback) {
        await prefs.setBool(_keyUseImageFallback, false);
      }
      useImageFallback = false;
    }

    return InvoicePrintConfiguration(
      printerType: printerType,
      printerSupportsArabic: prefs.getBool(_keySupportsArabic) ?? true,
      useImageFallback: useImageFallback,
    );
  }

  Future<void> save(InvoicePrintConfiguration config) async {
    final prefs = await SharedPreferences.getInstance();
    final isThermalType =
        config.printerType == PrinterType.thermal58 ||
        config.printerType == PrinterType.thermal80;
    final useImageFallback =
        isThermalType ? false : config.useImageFallback;
    await prefs.setString(_keyPrinterType, config.printerType.name);
    await prefs.setBool(_keySupportsArabic, config.printerSupportsArabic);
    await prefs.setBool(_keyUseImageFallback, useImageFallback);
  }

  PrinterType _parsePrinterType(String raw) {
    for (final value in PrinterType.values) {
      if (value.name == raw) {
        return value;
      }
    }
    return PrinterType.a4;
  }
}
