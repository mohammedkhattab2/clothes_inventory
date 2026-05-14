import 'package:flutter_test/flutter_test.dart';
import 'package:clothes_inventory/services/printing/rtl_alignment_helper.dart';
import 'package:clothes_inventory/services/printing/rtl_printer_formatter.dart';

void main() {
  group('rtl_alignment_helper', () {
    test('alignRight pads to target width', () {
      final line = alignRight('abc', 10);
      expect(line.length, 10);
      expect(line.endsWith('abc'), isTrue);
    });

    test('alignCenter pads evenly around text', () {
      final line = alignCenter('abc', 9);
      expect(line.length, 9);
      expect(line.trim(), 'abc');
    });

    test('alignLeft pads on right side', () {
      final line = alignLeft('abc', 8);
      expect(line.length, 8);
      expect(line.startsWith('abc'), isTrue);
    });

    test('alignment truncates too-long text with ellipsis', () {
      final line = alignRight('abcdefghijk', 6);
      expect(line.length, 6);
      expect(line.endsWith('…'), isTrue);
    });
  });

  group('buildRtlRow', () {
    test('reverses column order and preserves fixed total width', () {
      final row = buildRtlRow(
        columns: ['Name', '2', '10.00'],
        columnWidths: [10, 4, 8],
      );

      expect(row.length, 24);
      expect(row.contains('10.00'), isTrue);
      expect(row.contains('Name'), isTrue);
      expect(row.indexOf('10.00') < row.indexOf('Name'), isTrue);
    });

    test('throws when columns and widths do not match', () {
      expect(
        () => buildRtlRow(columns: ['a', 'b'], columnWidths: [10]),
        throwsArgumentError,
      );
    });
  });

  group('RtlPrinterFormatter', () {
    final formatter = RtlPrinterFormatter(kThermal58mmLineWidth);

    test('right/center/left produce exact line width', () {
      expect(formatter.right('اختبار').length, kThermal58mmLineWidth);
      expect(formatter.center('اختبار').length, kThermal58mmLineWidth);
      expect(formatter.left('اختبار').length, kThermal58mmLineWidth);
    });

    test('buildInvoiceRow returns fixed width line', () {
      final row = formatter.buildInvoiceRow(
        name: 'منتج طويل جدا للاختبار',
        qty: '12',
        price: '150.00',
      );

      expect(row.length, kThermal58mmLineWidth);
      expect(row.contains('150.00'), isTrue);
    });

    test('buildFiveColumnRow handles mixed language and numbers', () {
      final row = formatter.buildFiveColumnRow(
        name: 'رقم 123',
        qty: '2',
        unitPrice: '99.50',
        discount: '0.00',
        total: '199.00',
      );

      expect(row.length, kThermal58mmLineWidth);
      expect(row.contains(RegExp(r'123|١٢٣')), isTrue);
    });

    test('totalLine aligns label/value in one row', () {
      final total = formatter.totalLine(
        label: 'الإجمالي:',
        value: '750.00 EGP',
      );
      expect(total.length, kThermal58mmLineWidth);
      expect(total.contains('750.00'), isTrue);
    });
  });
}
