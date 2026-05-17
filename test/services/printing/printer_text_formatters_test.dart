import 'package:flutter_test/flutter_test.dart';
import 'package:delta_erp/features/invoices/domain/invoice_print_model.dart';
import 'package:delta_erp/services/printing/printer_text_formatters.dart';

void main() {
  test('A4 formatter does not reshape Arabic text', () {
    const formatter = A4TextFormatter();
    const input = 'شركة المشد للتجارة الحديثة';

    final output = formatter.format(input);

    expect(output, input);
  });

  test('Thermal formatter reshapes Arabic text', () {
    const formatter = ThermalTextFormatter();
    const input = 'شركة المشد للتجارة الحديثة';

    final output = formatter.format(input);

    expect(output, isNotEmpty);
    expect(output, isNot(input));
  });

  test('Thermal formatter keeps plain english readable', () {
    const formatter = ThermalTextFormatter();
    const input = 'Invoice #123';

    final output = formatter.format(input);

    expect(output, input);
  });

  test('formatter resolver returns A4 formatter for A4', () {
    final formatter = formatterForPrinterType(PrinterType.a4);
    expect(formatter, isA<A4TextFormatter>());
  });

  test('formatter resolver returns Thermal formatter for thermal types', () {
    final formatter58 = formatterForPrinterType(PrinterType.thermal58);
    final formatter80 = formatterForPrinterType(PrinterType.thermal80);

    expect(formatter58, isA<ThermalTextFormatter>());
    expect(formatter80, isA<ThermalTextFormatter>());
  });
}
