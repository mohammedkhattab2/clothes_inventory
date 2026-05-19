import 'package:delta_erp/features/invoices/domain/invoice_print_model.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Builds a narrow receipt-style PDF for thermal printers (58 mm or 80 mm).
///
/// Item table uses the same six columns as the A4 invoice (RTL):
/// price, discount, line total, quantity, description, barcode.
void buildThermalRtlInvoicePage({
  required pw.Document document,
  required InvoicePrintModel invoice,
  required double paperWidthMm,
}) {
  const marginMm = 3.0;
  final pageWidthPt = paperWidthMm * PdfPageFormat.mm;
  final marginPt = marginMm * PdfPageFormat.mm;
  final pageFormat = PdfPageFormat(
    pageWidthPt,
    400 * PdfPageFormat.mm,
    marginAll: marginPt,
  );
  final contentWidthPt = pageWidthPt - marginPt * 2;
  final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(invoice.date);
  final cellFontSize = paperWidthMm <= 58 ? 5.0 : 5.8;
  final headerFontSize = paperWidthMm <= 58 ? 5.2 : 6.0;

  document.addPage(
    pw.Page(
      pageFormat: pageFormat,
      build: (context) {
        return pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  invoice.invoiceNumber,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                invoice.companyName,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              if (invoice.cashierName.trim().isNotEmpty)
                _metaRow('invoice.print.cashier'.tr(), invoice.cashierName),
              _metaRow('invoice.print.customer'.tr(), invoice.customerName),
              _metaRow('invoice.print.datetime'.tr(), dateStr),
              _separator(contentWidthPt),
              _buildItemsTable(
                invoice: invoice,
                cellFontSize: cellFontSize,
                headerFontSize: headerFontSize,
              ),
              _separator(contentWidthPt),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '${invoice.total.toStringAsFixed(2)} ${invoice.currency}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '${'Total'.tr()}:',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (invoice.paidAmount > 0.000001 ||
                  invoice.outstandingAmount > 0.000001) ...[
                pw.SizedBox(height: 4),
                _metaRow(
                  'invoice.print.paid'.tr(),
                  invoice.paidAmount.toStringAsFixed(2),
                ),
                _metaRow(
                  'invoice.print.outstanding'.tr(),
                  invoice.outstandingAmount.toStringAsFixed(2),
                ),
              ],
              pw.SizedBox(height: 6),
              if (invoice.returnPolicyNote.trim().isNotEmpty)
                pw.Text(
                  invoice.returnPolicyNote.trim(),
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 6.5, lineSpacing: 1.1),
                ),
              if (invoice.address.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  invoice.address,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 6.5),
                ),
              ],
              if (invoice.phone.isNotEmpty)
                pw.Text(
                  invoice.phone,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 6.5),
                ),
              pw.SizedBox(height: 6),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  if (invoice.invoiceFooterImageBytes != null)
                    pw.Expanded(
                      child: pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Image(
                          pw.MemoryImage(invoice.invoiceFooterImageBytes!),
                          height: 36,
                        ),
                      ),
                    ),
                  if (invoice.invoiceFooterImageBytes != null)
                    pw.SizedBox(width: 4),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (invoice.appIconBytes != null)
                          pw.Image(
                            pw.MemoryImage(invoice.appIconBytes!),
                            width: 22,
                            height: 22,
                          ),
                        pw.Text(
                          invoice.developerBrand,
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          invoice.developerName,
                          style: const pw.TextStyle(fontSize: 6),
                        ),
                        pw.Text(
                          invoice.developerPhone,
                          style: const pw.TextStyle(fontSize: 6),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (invoice.invoiceFooterNote.trim().isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  invoice.invoiceFooterNote.trim(),
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 6, lineSpacing: 1.1),
                ),
              ],
              pw.SizedBox(height: 8),
            ],
          ),
        );
      },
    ),
  );
}

pw.Widget _buildItemsTable({
  required InvoicePrintModel invoice,
  required double cellFontSize,
  required double headerFontSize,
}) {
  final money = NumberFormat('#,##0.##');
  final qtyFmt = NumberFormat('#,##0.##');

  var sumQty = 0.0;
  var sumDiscount = 0.0;
  var sumLine = 0.0;

  pw.Widget cell(
    String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 1.5, vertical: 2),
      child: pw.Text(
        text,
        textAlign: align,
        maxLines: 3,
        style: pw.TextStyle(
          fontSize: bold ? headerFontSize : cellFontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  final dataRows = <pw.TableRow>[];
  for (final item in invoice.items) {
    sumQty += item.quantity;
    sumDiscount += item.discount;
    sumLine += item.effectiveLineTotal;

    dataRows.add(
      pw.TableRow(
        children: [
          cell(money.format(item.unitPrice)),
          cell(money.format(item.discount)),
          cell(money.format(item.effectiveLineTotal)),
          cell(qtyFmt.format(item.quantity)),
          cell(item.productName, align: pw.TextAlign.right),
          cell(item.barcode.isEmpty ? '—' : item.barcode),
        ],
      ),
    );
  }

  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.4),
    columnWidths: const {
      0: pw.FlexColumnWidth(1.0),
      1: pw.FlexColumnWidth(1.0),
      2: pw.FlexColumnWidth(1.05),
      3: pw.FlexColumnWidth(0.75),
      4: pw.FlexColumnWidth(1.8),
      5: pw.FlexColumnWidth(0.95),
    },
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          cell('invoice.print.col_price'.tr(), bold: true),
          cell('invoice.print.col_discount'.tr(), bold: true),
          cell('invoice.print.col_total'.tr(), bold: true),
          cell('invoice.print.col_qty'.tr(), bold: true),
          cell(
            'invoice.print.col_description'.tr(),
            bold: true,
            align: pw.TextAlign.right,
          ),
          cell('invoice.print.col_barcode'.tr(), bold: true),
        ],
      ),
      ...dataRows,
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          cell('—'),
          cell(money.format(sumDiscount), bold: true),
          cell(money.format(sumLine), bold: true),
          cell(qtyFmt.format(sumQty), bold: true),
          cell('—'),
          cell('—'),
        ],
      ),
    ],
  );
}

pw.Widget _separator(double width) => pw.Container(
  margin: const pw.EdgeInsets.symmetric(vertical: 3),
  height: 0.5,
  width: width,
  color: PdfColors.black,
);

pw.Widget _metaRow(String label, String value) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 1),
  child: pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Expanded(
        child: pw.Text(
          value,
          textAlign: pw.TextAlign.left,
          style: const pw.TextStyle(fontSize: 7),
        ),
      ),
      pw.Text('$label:', style: const pw.TextStyle(fontSize: 7)),
    ],
  ),
);
