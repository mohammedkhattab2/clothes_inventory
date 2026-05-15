import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores the user-selected thermal printer name and provides helpers
/// for discovering system printers via the [Printing] package.
class ThermalPrinterPreferences {
  const ThermalPrinterPreferences();

  static const _keyPrinterName = 'thermal.printerName';

  Future<String?> loadPrinterName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPrinterName);
  }

  Future<void> savePrinterName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPrinterName, name);
  }

  Future<void> clearPrinterName() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPrinterName);
  }

  Future<List<Printer>> listSystemPrinters() => Printing.listPrinters();

  Future<Printer?> resolveCurrentPrinter() async {
    final name = await loadPrinterName();
    if (name == null || name.isEmpty) return null;
    final printers = await listSystemPrinters();
    for (final p in printers) {
      if (p.name == name) return p;
    }
    return null;
  }
}
