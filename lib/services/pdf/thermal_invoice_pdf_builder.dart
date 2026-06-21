import 'package:delta_erp/features/invoices/domain/invoice_print_model.dart';
import 'package:delta_erp/services/pdf/invoice_pdf_theme.dart';
import 'package:delta_erp/services/printing/thermal_printer_presets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:pdf/widgets.dart' as pw;

/// Extra safety when packing receipt segments into a 109 mm driver strip.
const thermalStripPackSafetyMm = 2.0;

/// Safety margin added to the content estimate so nothing is clipped on print.
const thermalPageHeightSafetyBufferMm = 8.0;

/// Minimum receipt page height in millimeters.
const thermalPageMinHeightMm = 50.0;

int _thermalEstimatedTextLines(
  String text,
  double paperWidthMm, {
  required int maxLines,
}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return 0;
  }

  final charsPerLine = paperWidthMm <= 58 ? 12 : 18;
  var lines = 0;
  for (final paragraph in trimmed.split('\n')) {
    if (paragraph.trim().isEmpty) continue;
    lines += (paragraph.length / charsPerLine).ceil().clamp(1, maxLines);
  }
  return lines;
}

double _thermalTextBlockHeightMm(int lines, double fontSizePt) {
  if (lines <= 0) {
    return 0;
  }
  // lineSpacing 1.15 in footer widgets — use conservative mm-per-line estimate.
  return lines * fontSizePt * 0.42 + 4;
}

double _thermalItemRowHeightMm(InvoiceItem item, double paperWidthMm) {
  final cellFontSize = InvoicePdfTheme.thermalCellFontSize(paperWidthMm);
  final nameLines = _thermalEstimatedTextLines(
    item.productName,
    paperWidthMm,
    maxLines: 3,
  ).clamp(1, 3);
  final barcodeLines = item.barcode.isEmpty
      ? 1
      : _thermalEstimatedTextLines(
          item.barcode,
          paperWidthMm,
          maxLines: 2,
        ).clamp(1, 2);
  final rowLines = nameLines > barcodeLines ? nameLines : barcodeLines;
  return 8.0 + rowLines * cellFontSize * 0.55;
}

/// Estimates receipt height in millimeters for a content-fit thermal roll page.
double thermalEstimatedPageHeightMm(
  InvoicePrintModel invoice,
  double paperWidthMm,
) {
  final footerMinFontSize = InvoicePdfTheme.thermalFooterMinFontSize(
    paperWidthMm,
  );

  var heightMm = 40.0; // letterhead (company + address up to 3 lines) + meta
  heightMm += 10.0; // table header row
  for (final item in invoice.items) {
    heightMm += _thermalItemRowHeightMm(item, paperWidthMm);
  }
  heightMm += 8.0; // table totals row
  heightMm += 12.0; // grand total row + spacing
  if (invoice.paidAmount > 0.000001 || invoice.outstandingAmount > 0.000001) {
    heightMm += 10.0;
  }
  if (invoice.returnPolicyNote.trim().isNotEmpty) {
    heightMm += _thermalTextBlockHeightMm(
      _thermalEstimatedTextLines(
        invoice.returnPolicyNote,
        paperWidthMm,
        maxLines: 10,
      ),
      footerMinFontSize,
    );
  }
  if (invoice.invoiceFooterNote.trim().isNotEmpty) {
    heightMm += _thermalTextBlockHeightMm(
      _thermalEstimatedTextLines(
        invoice.invoiceFooterNote,
        paperWidthMm,
        maxLines: 10,
      ),
      footerMinFontSize,
    );
  }
  if (invoice.invoiceFooterImageBytes != null) {
    heightMm += 20.0; // 36pt image + spacing
  }
  heightMm += 24.0; // developer footer block (icon + 3 lines)
  heightMm += InvoicePdfTheme.thermalMarginVerticalMm;
  heightMm += InvoicePdfTheme.thermalMarginBottomMm;
  heightMm += thermalPageHeightSafetyBufferMm;
  heightMm += invoice.items.length * 2.0;

  return heightMm.clamp(thermalPageMinHeightMm, double.infinity);
}

/// Builds a narrow receipt-style PDF for thermal printers (58 mm or 80 mm).
///
/// One continuous roll page — avoids inter-page gaps from 350B / Windows drivers
/// that feed ~10 cm per PDF page when using multi-page jobs.
void buildThermalRtlInvoicePage({
  required pw.Document document,
  required InvoicePrintModel invoice,
  required double paperWidthMm,
}) {
  final footerImg = invoice.invoiceFooterImageBytes != null
      ? pw.MemoryImage(invoice.invoiceFooterImageBytes!)
      : null;
  final appIcon = invoice.appIconBytes != null
      ? pw.MemoryImage(invoice.appIconBytes!)
      : null;

  final widgets = _buildThermalReceiptWidgets(
    invoice: invoice,
    paperWidthMm: paperWidthMm,
    footerImg: footerImg,
    appIcon: appIcon,
  );
  final pageHeightMm = thermalEstimatedPageHeightMm(invoice, paperWidthMm);

  document.addPage(
    pw.Page(
      pageFormat: InvoicePdfTheme.thermalPageFormat(
        paperWidthMm: paperWidthMm,
        pageHeightMm: pageHeightMm,
      ),
      textDirection: pw.TextDirection.rtl,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: widgets,
      ),
    ),
  );
}

List<pw.Widget> _buildThermalReceiptWidgets({
  required InvoicePrintModel invoice,
  required double paperWidthMm,
  pw.MemoryImage? footerImg,
  pw.MemoryImage? appIcon,
}) {
  final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(invoice.date);
  final cellFontSize = InvoicePdfTheme.thermalCellFontSize(paperWidthMm);
  final headerFontSize = InvoicePdfTheme.thermalHeaderFontSize(paperWidthMm);
  final metaFontSize = InvoicePdfTheme.thermalMetaFontSize(paperWidthMm);
  final companyFontSize = InvoicePdfTheme.thermalCompanyNameFontSize(
    paperWidthMm,
  );
  final footerMinFontSize = InvoicePdfTheme.thermalFooterMinFontSize(
    paperWidthMm,
  );

  final widgets = <pw.Widget>[
    _buildThermalLetterhead(
      invoice: invoice,
      companyFontSize: companyFontSize,
      metaFontSize: metaFontSize,
    ),
    pw.SizedBox(height: 3),
    pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        invoice.invoiceNumber,
        style: pw.TextStyle(
          fontSize: metaFontSize,
          fontWeight: pw.FontWeight.bold,
          color: InvoicePdfTheme.textColor,
        ),
      ),
    ),
    pw.SizedBox(height: 2),
  ];

  if (invoice.cashierName.trim().isNotEmpty) {
    widgets.add(
      _metaRow(
        'invoice.print.cashier'.tr(),
        invoice.cashierName,
        fontSize: metaFontSize,
      ),
    );
  }
  widgets.addAll([
    _metaRow(
      'invoice.print.customer'.tr(),
      invoice.customerName,
      fontSize: metaFontSize,
    ),
    _metaRow('invoice.print.datetime'.tr(), dateStr, fontSize: metaFontSize),
    pw.SizedBox(height: 4),
  ]);

  widgets.add(
    _buildThermalItemsTable(
      invoice: invoice,
      items: invoice.items,
      paperWidthMm: paperWidthMm,
      cellFontSize: cellFontSize,
      headerFontSize: headerFontSize,
      includeHeaderRow: true,
      includeTotalsRow: true,
    ),
  );

  widgets.addAll([
    pw.SizedBox(height: 6),
    pw.Row(
      children: [
        pw.Expanded(
          child: pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              '${'Total'.tr()}:',
              style: pw.TextStyle(
                fontSize: metaFontSize + 1,
                fontWeight: pw.FontWeight.bold,
                color: InvoicePdfTheme.textColor,
              ),
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(
              '${invoice.total.toStringAsFixed(2)} ${invoice.currency}',
              style: pw.TextStyle(
                fontSize: metaFontSize + 1,
                fontWeight: pw.FontWeight.bold,
                color: InvoicePdfTheme.textColor,
              ),
            ),
          ),
        ),
      ],
    ),
  ]);

  if (invoice.paidAmount > 0.000001 || invoice.outstandingAmount > 0.000001) {
    widgets.addAll([
      pw.SizedBox(height: 4),
      _metaRow(
        'invoice.print.paid'.tr(),
        invoice.paidAmount.toStringAsFixed(2),
        fontSize: metaFontSize,
      ),
      _metaRow(
        'invoice.print.outstanding'.tr(),
        invoice.outstandingAmount.toStringAsFixed(2),
        fontSize: metaFontSize,
      ),
    ]);
  }

  widgets.add(pw.SizedBox(height: 6));

  if (invoice.returnPolicyNote.trim().isNotEmpty) {
    widgets.add(
      pw.Text(
        invoice.returnPolicyNote.trim(),
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: footerMinFontSize,
          lineSpacing: 1.15,
          color: InvoicePdfTheme.textColor,
        ),
      ),
    );
    widgets.add(pw.SizedBox(height: 6));
  }

  widgets.addAll(
    _buildThermalFooterSection(
      invoice: invoice,
      footerImg: footerImg,
      appIcon: appIcon,
      footerMinFontSize: footerMinFontSize,
    ),
  );

  return widgets;
}

pw.Widget _buildThermalLetterhead({
  required InvoicePrintModel invoice,
  required double companyFontSize,
  required double metaFontSize,
}) {
  return pw.Container(
    color: InvoicePdfTheme.thermalHeaderBandColor,
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          invoice.companyName,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: companyFontSize,
            fontWeight: pw.FontWeight.bold,
            color: InvoicePdfTheme.textColor,
          ),
        ),
        if (invoice.address.trim().isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            invoice.address.trim(),
            textAlign: pw.TextAlign.center,
            maxLines: 3,
            style: pw.TextStyle(
              fontSize: metaFontSize,
              color: InvoicePdfTheme.textColor,
            ),
          ),
        ],
        if (invoice.phone.trim().isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            invoice.phone.trim(),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: metaFontSize,
              color: InvoicePdfTheme.textColor,
            ),
          ),
        ],
      ],
    ),
  );
}

List<pw.Widget> _buildThermalFooterSection({
  required InvoicePrintModel invoice,
  pw.MemoryImage? footerImg,
  pw.MemoryImage? appIcon,
  required double footerMinFontSize,
}) {
  return [
    if (invoice.invoiceFooterNote.trim().isNotEmpty) ...[
      pw.Text(
        invoice.invoiceFooterNote.trim(),
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: footerMinFontSize,
          lineSpacing: 1.15,
          color: InvoicePdfTheme.textColor,
        ),
      ),
      pw.SizedBox(height: 4),
    ],
    if (footerImg != null) ...[
      pw.Center(child: pw.Image(footerImg, height: 36)),
      pw.SizedBox(height: 4),
    ],
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Center(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            if (appIcon != null) pw.Image(appIcon, width: 16, height: 16),
            pw.Text(
              invoice.developerBrand,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: footerMinFontSize,
                fontWeight: pw.FontWeight.bold,
                color: InvoicePdfTheme.textColor,
              ),
            ),
            pw.Text(
              invoice.developerName,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: footerMinFontSize,
                color: InvoicePdfTheme.textColor,
              ),
            ),
            pw.Text(
              invoice.developerPhone,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: footerMinFontSize,
                color: InvoicePdfTheme.textColor,
              ),
            ),
          ],
        ),
      ),
    ),
  ];
}

const _thermalColumnWidths = {
  0: pw.FlexColumnWidth(1.0),
  1: pw.FlexColumnWidth(1.0),
  2: pw.FlexColumnWidth(1.05),
  3: pw.FlexColumnWidth(0.75),
  4: pw.FlexColumnWidth(1.8),
  5: pw.FlexColumnWidth(0.95),
};

pw.TableRow _thermalHeaderTableRow({required double headerFontSize}) {
  pw.Widget cell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 1.5, vertical: 3),
      child: pw.Align(
        alignment: pw.Alignment.center,
        child: pw.Text(
          text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: headerFontSize,
            fontWeight: pw.FontWeight.bold,
            color: InvoicePdfTheme.textColor,
          ),
        ),
      ),
    );
  }

  return pw.TableRow(
    decoration: const pw.BoxDecoration(
      color: InvoicePdfTheme.thermalTableHeaderBg,
    ),
    children: [
      cell('invoice.print.col_price'.tr()),
      cell('invoice.print.col_discount'.tr()),
      cell('invoice.print.col_total'.tr()),
      cell('invoice.print.col_qty'.tr()),
      cell('invoice.print.col_description'.tr()),
      cell('invoice.print.col_barcode'.tr()),
    ],
  );
}

pw.Widget _buildThermalItemsTable({
  required InvoicePrintModel invoice,
  required List<InvoiceItem> items,
  required double paperWidthMm,
  required double cellFontSize,
  required double headerFontSize,
  required bool includeHeaderRow,
  required bool includeTotalsRow,
}) {
  final money = NumberFormat('#,##0.##');
  final qtyFmt = NumberFormat('#,##0.##');

  pw.Widget cell(String text, {double? fontSize, bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 1.5, vertical: 3),
      child: pw.Align(
        alignment: pw.Alignment.center,
        child: pw.Text(
          text,
          textAlign: pw.TextAlign.center,
          maxLines: 3,
          style: pw.TextStyle(
            fontSize: fontSize ?? cellFontSize,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: InvoicePdfTheme.textColor,
          ),
        ),
      ),
    );
  }

  final rows = <pw.TableRow>[];

  if (includeHeaderRow) {
    rows.add(_thermalHeaderTableRow(headerFontSize: headerFontSize));
  }

  for (final item in items) {
    rows.add(
      pw.TableRow(
        children: [
          cell(money.format(item.unitPrice)),
          cell(money.format(item.discount)),
          cell(money.format(item.effectiveLineTotal)),
          cell(qtyFmt.format(item.quantity)),
          cell(item.productName),
          cell(item.barcode.isEmpty ? '—' : item.barcode),
        ],
      ),
    );
  }

  if (includeTotalsRow) {
    var sumQty = 0.0;
    var sumDiscount = 0.0;
    var sumLine = 0.0;
    for (final item in invoice.items) {
      sumQty += item.quantity;
      sumDiscount += item.discount;
      sumLine += item.effectiveLineTotal;
    }

    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(
          color: InvoicePdfTheme.thermalTableTotalsBg,
        ),
        children: [
          cell('—'),
          cell(money.format(sumDiscount), bold: true),
          cell(money.format(sumLine), bold: true),
          cell(qtyFmt.format(sumQty), bold: true),
          cell('—'),
          cell('—'),
        ],
      ),
    );
  }

  return pw.Table(
    border: InvoicePdfTheme.thermalUnifiedTableBorder(
      paperWidthMm: paperWidthMm,
    ),
    columnWidths: _thermalColumnWidths,
    children: rows,
  );
}

pw.Widget _metaRow(String label, String value, {required double fontSize}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                '$label:',
                style: pw.TextStyle(
                  fontSize: fontSize,
                  fontWeight: pw.FontWeight.bold,
                  color: InvoicePdfTheme.textColor,
                ),
              ),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: fontSize,
                  color: InvoicePdfTheme.textColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );

/// Sized receipt block used when packing a long invoice into driver strips.
class ThermalReceiptSegment {
  const ThermalReceiptSegment({required this.widget, required this.heightMm});

  final pw.Widget widget;
  final double heightMm;
}

/// One printable strip (≤ [ThermalPrinterPresets.driverMaxStripHeightMm]).
class ThermalInvoicePrintStrip {
  const ThermalInvoicePrintStrip({
    required this.widgets,
    required this.pageHeightMm,
  });

  final List<pw.Widget> widgets;
  final double pageHeightMm;
}

/// Printable content budget inside one 350B driver PDF job.
double thermalStripMaxContentHeightMm({
  double maxStripHeightMm = ThermalPrinterPresets.driverMaxStripHeightMm,
}) {
  return maxStripHeightMm -
      InvoicePdfTheme.thermalMarginVerticalMm -
      InvoicePdfTheme.thermalMarginBottomMm -
      thermalStripPackSafetyMm;
}

/// Splits a receipt into consecutive driver-safe strips with no blank gaps.
List<ThermalInvoicePrintStrip> planThermalInvoicePrintStrips({
  required InvoicePrintModel invoice,
  required double paperWidthMm,
  double maxStripHeightMm = ThermalPrinterPresets.driverMaxStripHeightMm,
}) {
  final segments = buildThermalReceiptSegments(
    invoice: invoice,
    paperWidthMm: paperWidthMm,
  );
  if (segments.isEmpty) {
    throw StateError('Invoice has no printable segments.');
  }

  final marginTop = InvoicePdfTheme.thermalMarginVerticalMm;
  final marginBottom = InvoicePdfTheme.thermalMarginBottomMm;
  final maxContent = thermalStripMaxContentHeightMm(
    maxStripHeightMm: maxStripHeightMm,
  );

  final strips = <ThermalInvoicePrintStrip>[];
  var batch = <ThermalReceiptSegment>[];
  var batchHeight = 0.0;

  void flush() {
    if (batch.isEmpty) return;
    strips.add(
      ThermalInvoicePrintStrip(
        widgets: batch.map((segment) => segment.widget).toList(growable: false),
        pageHeightMm:
            marginTop + batchHeight + marginBottom + thermalStripPackSafetyMm,
      ),
    );
    batch = <ThermalReceiptSegment>[];
    batchHeight = 0;
  }

  for (final segment in segments) {
    if (batch.isNotEmpty &&
        batchHeight + segment.heightMm > maxContent + 0.001) {
      flush();
    }
    batch.add(segment);
    batchHeight += segment.heightMm;
  }
  flush();

  return strips;
}

List<ThermalReceiptSegment> buildThermalReceiptSegments({
  required InvoicePrintModel invoice,
  required double paperWidthMm,
}) {
  final footerImg = invoice.invoiceFooterImageBytes != null
      ? pw.MemoryImage(invoice.invoiceFooterImageBytes!)
      : null;
  final appIcon = invoice.appIconBytes != null
      ? pw.MemoryImage(invoice.appIconBytes!)
      : null;

  final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(invoice.date);
  final cellFontSize = InvoicePdfTheme.thermalCellFontSize(paperWidthMm);
  final headerFontSize = InvoicePdfTheme.thermalHeaderFontSize(paperWidthMm);
  final metaFontSize = InvoicePdfTheme.thermalMetaFontSize(paperWidthMm);
  final companyFontSize = InvoicePdfTheme.thermalCompanyNameFontSize(
    paperWidthMm,
  );
  final footerMinFontSize = InvoicePdfTheme.thermalFooterMinFontSize(
    paperWidthMm,
  );

  final segments = <ThermalReceiptSegment>[
    ThermalReceiptSegment(
      widget: _buildThermalLetterhead(
        invoice: invoice,
        companyFontSize: companyFontSize,
        metaFontSize: metaFontSize,
      ),
      heightMm: 36,
    ),
    ThermalReceiptSegment(widget: pw.SizedBox(height: 3), heightMm: 2),
    ThermalReceiptSegment(
      widget: pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          invoice.invoiceNumber,
          style: pw.TextStyle(
            fontSize: metaFontSize,
            fontWeight: pw.FontWeight.bold,
            color: InvoicePdfTheme.textColor,
          ),
        ),
      ),
      heightMm: 8,
    ),
    ThermalReceiptSegment(widget: pw.SizedBox(height: 2), heightMm: 2),
  ];

  if (invoice.cashierName.trim().isNotEmpty) {
    segments.add(
      ThermalReceiptSegment(
        widget: _metaRow(
          'invoice.print.cashier'.tr(),
          invoice.cashierName,
          fontSize: metaFontSize,
        ),
        heightMm: 5.5,
      ),
    );
  }

  segments.addAll([
    ThermalReceiptSegment(
      widget: _metaRow(
        'invoice.print.customer'.tr(),
        invoice.customerName,
        fontSize: metaFontSize,
      ),
      heightMm: 5.5,
    ),
    ThermalReceiptSegment(
      widget: _metaRow(
        'invoice.print.datetime'.tr(),
        dateStr,
        fontSize: metaFontSize,
      ),
      heightMm: 5.5,
    ),
    ThermalReceiptSegment(widget: pw.SizedBox(height: 4), heightMm: 2.5),
  ]);

  for (var index = 0; index < invoice.items.length; index++) {
    final item = invoice.items[index];
    final rowHeight = _thermalItemRowHeightMm(item, paperWidthMm);
    final headerHeight = index == 0 ? 10.0 : 0.0;
    segments.add(
      ThermalReceiptSegment(
        widget: _buildThermalItemsTable(
          invoice: invoice,
          items: [item],
          paperWidthMm: paperWidthMm,
          cellFontSize: cellFontSize,
          headerFontSize: headerFontSize,
          includeHeaderRow: index == 0,
          includeTotalsRow: false,
        ),
        heightMm: headerHeight + rowHeight + 2,
      ),
    );
  }

  if (invoice.items.isNotEmpty) {
    segments.add(
      ThermalReceiptSegment(
        widget: _buildThermalItemsTable(
          invoice: invoice,
          items: const [],
          paperWidthMm: paperWidthMm,
          cellFontSize: cellFontSize,
          headerFontSize: headerFontSize,
          includeHeaderRow: false,
          includeTotalsRow: true,
        ),
        heightMm: 8,
      ),
    );
  }

  segments.addAll([
    ThermalReceiptSegment(widget: pw.SizedBox(height: 6), heightMm: 6),
    ThermalReceiptSegment(
      widget: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                '${'Total'.tr()}:',
                style: pw.TextStyle(
                  fontSize: metaFontSize + 1,
                  fontWeight: pw.FontWeight.bold,
                  color: InvoicePdfTheme.textColor,
                ),
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                '${invoice.total.toStringAsFixed(2)} ${invoice.currency}',
                style: pw.TextStyle(
                  fontSize: metaFontSize + 1,
                  fontWeight: pw.FontWeight.bold,
                  color: InvoicePdfTheme.textColor,
                ),
              ),
            ),
          ),
        ],
      ),
      heightMm: 12,
    ),
  ]);

  if (invoice.paidAmount > 0.000001 || invoice.outstandingAmount > 0.000001) {
    segments.addAll([
      ThermalReceiptSegment(widget: pw.SizedBox(height: 4), heightMm: 4),
      ThermalReceiptSegment(
        widget: _metaRow(
          'invoice.print.paid'.tr(),
          invoice.paidAmount.toStringAsFixed(2),
          fontSize: metaFontSize,
        ),
        heightMm: 6,
      ),
      ThermalReceiptSegment(
        widget: _metaRow(
          'invoice.print.outstanding'.tr(),
          invoice.outstandingAmount.toStringAsFixed(2),
          fontSize: metaFontSize,
        ),
        heightMm: 6,
      ),
    ]);
  }

  segments.add(
    ThermalReceiptSegment(widget: pw.SizedBox(height: 6), heightMm: 6),
  );

  if (invoice.returnPolicyNote.trim().isNotEmpty) {
    final lines = _thermalEstimatedTextLines(
      invoice.returnPolicyNote,
      paperWidthMm,
      maxLines: 10,
    );
    segments.addAll([
      ThermalReceiptSegment(
        widget: pw.Text(
          invoice.returnPolicyNote.trim(),
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: footerMinFontSize,
            lineSpacing: 1.15,
            color: InvoicePdfTheme.textColor,
          ),
        ),
        heightMm: _thermalTextBlockHeightMm(lines, footerMinFontSize),
      ),
      ThermalReceiptSegment(widget: pw.SizedBox(height: 6), heightMm: 6),
    ]);
  }

  if (invoice.invoiceFooterNote.trim().isNotEmpty) {
    final lines = _thermalEstimatedTextLines(
      invoice.invoiceFooterNote,
      paperWidthMm,
      maxLines: 10,
    );
    segments.addAll([
      ThermalReceiptSegment(
        widget: pw.Text(
          invoice.invoiceFooterNote.trim(),
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: footerMinFontSize,
            lineSpacing: 1.15,
            color: InvoicePdfTheme.textColor,
          ),
        ),
        heightMm: _thermalTextBlockHeightMm(lines, footerMinFontSize),
      ),
      ThermalReceiptSegment(widget: pw.SizedBox(height: 4), heightMm: 4),
    ]);
  }

  if (footerImg != null) {
    segments.addAll([
      ThermalReceiptSegment(
        widget: pw.Center(child: pw.Image(footerImg, height: 36)),
        heightMm: 20,
      ),
      ThermalReceiptSegment(widget: pw.SizedBox(height: 4), heightMm: 4),
    ]);
  }

  segments.add(
    ThermalReceiptSegment(
      widget: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Center(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              if (appIcon != null) pw.Image(appIcon, width: 16, height: 16),
              pw.Text(
                invoice.developerBrand,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: footerMinFontSize,
                  fontWeight: pw.FontWeight.bold,
                  color: InvoicePdfTheme.textColor,
                ),
              ),
              pw.Text(
                invoice.developerName,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: footerMinFontSize,
                  color: InvoicePdfTheme.textColor,
                ),
              ),
              pw.Text(
                invoice.developerPhone,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: footerMinFontSize,
                  color: InvoicePdfTheme.textColor,
                ),
              ),
            ],
          ),
        ),
      ),
      heightMm: 24,
    ),
  );

  return segments;
}
