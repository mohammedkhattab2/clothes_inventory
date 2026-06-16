import 'dart:typed_data';

import 'package:delta_erp/services/printing/escpos_arabic_printer_service.dart';
import 'package:delta_erp/services/printing/esc_pos_text_encoding.dart';
import 'package:delta_erp/services/printing/printer_text_formatters.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

/// Collects ESC/POS bytes from [Generator] while implementing [EscPosGeneratorAdapter].
class EscPosCollectedGenerator implements EscPosGeneratorAdapter {
  EscPosCollectedGenerator({
    required Generator generator,
    this.printerSupportsArabic = true,
    PrinterTextFormatter formatter = const EscPosThermalTextFormatter(),
  })  : _generator = generator,
        _formatter = formatter {
    if (printerSupportsArabic) {
      _bytes.addAll(_generator.setGlobalCodeTable('CP1256'));
    }
  }

  final Generator _generator;
  final PrinterTextFormatter _formatter;
  final bool printerSupportsArabic;
  final List<int> _bytes = <int>[];

  Uint8List get bytes => Uint8List.fromList(_bytes);

  void append(List<int> chunk) => _bytes.addAll(chunk);

  void _emitText(
    String value, {
    PosStyles styles = const PosStyles(),
    bool formatted = false,
  }) {
    if (value.isEmpty) return;
    final output = formatted ? value : _formatter.format(value);
    final encoded = encodeEscPosText(
      output,
      useArabicCodePage: printerSupportsArabic,
    );
    if (encoded.isEmpty) return;

    if (textNeedsArabicCodePage(output) && printerSupportsArabic) {
      _bytes.addAll(
        _generator.textEncoded(
          encoded,
          styles: styles.copyWith(codeTable: 'CP1256'),
        ),
      );
      return;
    }

    _bytes.addAll(_generator.text(output, styles: styles));
  }

  @override
  void text(String value) => _emitText(value, formatted: false);

  @override
  void row(List<String> columns) {
    if (columns.isEmpty) return;
    if (columns.length == 1) {
      text(columns.first);
      return;
    }
    final cols = <PosColumn>[];
    final width = (12 / columns.length).floor().clamp(1, 12);
    for (final column in columns) {
      cols.add(
        PosColumn(
          text: _formatter.format(column),
          width: width,
          styles: const PosStyles(),
        ),
      );
    }
    _bytes.addAll(_generator.row(cols));
  }

  @override
  void image(Uint8List value) {
    throw UnsupportedError(
      'Raster image printing is disabled; use native ESC/POS text.',
    );
  }

  @override
  void hr() {
    _bytes.addAll(_generator.hr());
  }

  @override
  void feed(int lines) {
    if (lines <= 0) return;
    _bytes.addAll(_generator.feed(lines));
  }

  void textStyled(String value, PosStyles styles) => _emitText(value, styles: styles);

  void barcodeCode128(
    String data, {
    int? height,
    BarcodeText textPos = BarcodeText.none,
    PosAlign align = PosAlign.center,
  }) {
    final trimmed = data.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Barcode data cannot be empty.');
    }
    _bytes.addAll(
      _generator.barcode(
        Barcode.code128('{B$trimmed'.split('')),
        height: height,
        textPos: textPos,
        align: align,
      ),
    );
  }

  void reset() {
    _bytes.addAll(_generator.reset());
    if (printerSupportsArabic) {
      _bytes.addAll(_generator.setGlobalCodeTable('CP1256'));
    }
  }

  /// Flushes buffered output so the printer finishes the job.
  void completeJob({int feedLines = 2, bool cut = false}) {
    if (feedLines > 0) {
      feed(feedLines);
    }
    if (cut) {
      _bytes.addAll(_generator.cut(mode: PosCutMode.partial));
    }
  }
}
