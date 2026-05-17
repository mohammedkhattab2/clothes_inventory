import 'package:delta_erp/services/printing/printer_text_formatters.dart';
import 'package:delta_erp/services/printing/rtl_alignment_helper.dart';

const int kThermal58mmLineWidth = 32;
const int kThermal80mmLineWidth = 48;

String buildRtlRow({
  required List<String> columns,
  required List<int> columnWidths,
  PrinterTextFormatter formatter = const ThermalTextFormatter(),
}) {
  if (columns.length != columnWidths.length) {
    throw ArgumentError('columns and columnWidths must have same length.');
  }
  if (columns.isEmpty) {
    return '';
  }

  final rtlColumns = columns.reversed.toList(growable: false);
  final rtlWidths = columnWidths.reversed.toList(growable: false);

  final chunks = <String>[];
  for (var i = 0; i < rtlColumns.length; i++) {
    final formatted = formatter.format(rtlColumns[i]);
    final width = rtlWidths[i];
    final aligned = _isMostlyNumeric(rtlColumns[i])
        ? alignLeft(formatted, width)
        : alignRight(formatted, width);
    chunks.add(aligned);
  }

  final targetWidth =
      rtlWidths.fold<int>(0, (sum, width) => sum + (width > 0 ? width : 0)) +
      (rtlWidths.length - 1);
  return alignLeft(chunks.join(' '), targetWidth);
}

class RtlPrinterFormatter {
  RtlPrinterFormatter(this.lineWidth, {PrinterTextFormatter? textFormatter})
    : _textFormatter = textFormatter ?? const ThermalTextFormatter();

  final int lineWidth;
  final PrinterTextFormatter _textFormatter;

  String right(String text) =>
      alignRight(_textFormatter.format(text), lineWidth);

  String center(String text) =>
      alignCenter(_textFormatter.format(text), lineWidth);

  String left(String text) => alignLeft(_textFormatter.format(text), lineWidth);

  String buildInvoiceRow({
    required String name,
    required String qty,
    required String price,
  }) {
    final widths = _invoiceThreeColumnWidths();
    return buildRtlRow(
      columns: [name, qty, price],
      columnWidths: widths,
      formatter: _textFormatter,
    );
  }

  String buildFiveColumnRow({
    required String name,
    required String qty,
    required String unitPrice,
    required String discount,
    required String total,
  }) {
    final widths = _invoiceFiveColumnWidths();
    return buildRtlRow(
      columns: [name, qty, unitPrice, discount, total],
      columnWidths: widths,
      formatter: _textFormatter,
    );
  }

  String totalLine({required String label, required String value}) {
    const gap = 2;
    final safeGap = lineWidth > gap ? gap : 0;
    final valueWidth = (lineWidth * 0.35).floor().clamp(8, lineWidth - safeGap);
    final labelWidth = (lineWidth - valueWidth - safeGap).clamp(0, lineWidth);
    final formattedLabel = right(label).trimRight();
    final formattedValue = left(value).trimRight();
    final leftPart = alignRight(formattedLabel, labelWidth);
    final rightPart = alignLeft(formattedValue, valueWidth);
    return '$leftPart${' ' * safeGap}$rightPart';
  }

  List<int> _invoiceThreeColumnWidths() {
    final qtyWidth = 6;
    final priceWidth = 10;
    final nameWidth = lineWidth - qtyWidth - priceWidth - 2;
    return [nameWidth, qtyWidth, priceWidth];
  }

  List<int> _invoiceFiveColumnWidths() {
    const minQty = 4;
    const minPrice = 5;
    const minDiscount = 5;
    const minTotal = 6;
    const spaces = 4;

    final available = lineWidth - spaces;
    var qtyWidth = (available * 0.12).round().clamp(minQty, 8);
    var priceWidth = (available * 0.18).round().clamp(minPrice, 10);
    var discountWidth = (available * 0.18).round().clamp(minDiscount, 10);
    var totalWidth = (available * 0.22).round().clamp(minTotal, 12);

    var nameWidth =
        available - qtyWidth - priceWidth - discountWidth - totalWidth;

    if (nameWidth < 8) {
      final deficit = 8 - nameWidth;
      var remaining = deficit;

      final reducibleTotal = totalWidth - minTotal;
      final cutTotal = reducibleTotal >= remaining ? remaining : reducibleTotal;
      totalWidth -= cutTotal;
      remaining -= cutTotal;

      final reduciblePrice = priceWidth - minPrice;
      final cutPrice = reduciblePrice >= remaining ? remaining : reduciblePrice;
      priceWidth -= cutPrice;
      remaining -= cutPrice;

      final reducibleDiscount = discountWidth - minDiscount;
      final cutDiscount = reducibleDiscount >= remaining
          ? remaining
          : reducibleDiscount;
      discountWidth -= cutDiscount;
      remaining -= cutDiscount;

      final reducibleQty = qtyWidth - minQty;
      final cutQty = reducibleQty >= remaining ? remaining : reducibleQty;
      qtyWidth -= cutQty;

      nameWidth =
          available - qtyWidth - priceWidth - discountWidth - totalWidth;
    }

    return [nameWidth, qtyWidth, priceWidth, discountWidth, totalWidth];
  }
}

bool _isMostlyNumeric(String value) {
  final stripped = value.replaceAll(RegExp(r'[^0-9.,-]'), '');
  return stripped.isNotEmpty && stripped.length >= (value.trim().length / 2);
}
