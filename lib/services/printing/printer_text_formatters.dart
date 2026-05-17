import 'package:delta_erp/services/printing/arabic_text_formatter.dart';
import 'package:delta_erp/features/invoices/domain/invoice_print_model.dart';

abstract class PrinterTextFormatter {
  String format(String text);
}

class A4TextFormatter implements PrinterTextFormatter {
  const A4TextFormatter();

  @override
  String format(String text) {
    // A4 relies on native RTL layout (Directionality/TextAlign).
    return text;
  }
}

class ThermalTextFormatter implements PrinterTextFormatter {
  const ThermalTextFormatter({
    ArabicTextFormatter arabicFormatter = const ArabicTextFormatter(),
  }) : _arabicFormatter = arabicFormatter;

  final ArabicTextFormatter _arabicFormatter;

  @override
  String format(String text) {
    return _arabicFormatter.formatArabicText(text);
  }
}

PrinterTextFormatter formatterForPrinterType(PrinterType type) {
  switch (type) {
    case PrinterType.a4:
      return const A4TextFormatter();
    case PrinterType.thermal58:
    case PrinterType.thermal80:
      return const ThermalTextFormatter();
  }
}
