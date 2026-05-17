import 'package:flutter_test/flutter_test.dart';
import 'package:delta_erp/services/printing/arabic_print_mode_resolver.dart';
import 'package:delta_erp/services/printing/arabic_text_formatter.dart';

void main() {
  const formatter = ArabicTextFormatter();

  group('ArabicTextFormatter', () {
    test('returns english text unchanged', () {
      const input = 'Invoice #123';
      final output = formatter.formatArabicText(input);
      expect(output, input);
    });

    test('returns empty string unchanged', () {
      const input = '';
      final output = formatter.formatArabicText(input);
      expect(output, input);
    });

    test('reshapes pure arabic text for printer-ready rendering', () {
      const input = 'شركة المشد للتجارة الحديثة';
      final output = formatter.formatArabicText(input);

      expect(output, isNotEmpty);
      expect(output, isNot(input));
    });

    test('handles mixed arabic english and numbers safely', () {
      const input = 'Invoice رقم 123';
      final output = formatter.formatArabicText(input);

      expect(output, isNotEmpty);
      expect(output.contains('123'), isTrue);
    });

    test('formats long invoice text batch without throwing', () {
      final batch = List<String>.generate(
        150,
        (i) => 'بند رقم $i - Product $i - 100.00',
      );

      final output = formatter.formatBatch(batch);
      expect(output, hasLength(150));
      expect(output.first, isNotEmpty);
      expect(output.last, isNotEmpty);
    });
  });

  group('ArabicPrintModeResolver', () {
    const resolver = ArabicPrintModeResolver();

    test('uses text mode when printer supports arabic', () {
      final mode = resolver.resolve(printerSupportsArabic: true);
      expect(mode, ArabicPrintMode.text);
    });

    test('uses image mode when printer does not support arabic', () {
      final mode = resolver.resolve(printerSupportsArabic: false);
      expect(mode, ArabicPrintMode.image);
    });

    test('forces image mode when fallback preferred', () {
      final mode = resolver.resolve(
        printerSupportsArabic: true,
        preferImageFallback: true,
      );
      expect(mode, ArabicPrintMode.image);
    });
  });
}
