import 'package:clothes_inventory/features/invoices/domain/invoice_print_model.dart';
import 'package:clothes_inventory/services/printing/invoice_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InvoicePrintPreferences {
  const InvoicePrintPreferences();

  static const _keyPrinterType = 'print.printerType';
  static const _keySupportsArabic = 'print.supportsArabic';
  static const _keyUseImageFallback = 'print.useImageFallback';

  Future<InvoicePrintConfiguration> load() async {
    final prefs = await SharedPreferences.getInstance();
    return InvoicePrintConfiguration(
      printerType: _parsePrinterType(
        prefs.getString(_keyPrinterType) ?? PrinterType.a4.name,
      ),
      printerSupportsArabic: prefs.getBool(_keySupportsArabic) ?? true,
      useImageFallback: prefs.getBool(_keyUseImageFallback) ?? false,
    );
  }

  Future<void> save(InvoicePrintConfiguration config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPrinterType, config.printerType.name);
    await prefs.setBool(_keySupportsArabic, config.printerSupportsArabic);
    await prefs.setBool(_keyUseImageFallback, config.useImageFallback);
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
