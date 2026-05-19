import 'package:easy_localization/easy_localization.dart';
import 'package:delta_erp/features/invoices/domain/a4_invoice_view_data.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void buildA4RtlInvoicePage({
  required pw.Document document,
  required A4InvoiceViewData data,
  pw.MemoryImage? logo,
}) {
  final footerImg = data.invoiceFooterImageBytes != null
      ? pw.MemoryImage(data.invoiceFooterImageBytes!)
      : null;
  final appIcon = data.appIconBytes != null
      ? pw.MemoryImage(data.appIconBytes!)
      : null;
  final dateText = DateFormat('yyyy-MM-dd').format(data.issuedAt);
  final timeText = DateFormat('HH:mm').format(data.issuedAt);

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      build: (context) => [
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  data.invoiceNumber,
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                data.companyName,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              _metaLine('invoice.print.cashier'.tr(), data.cashierName),
              _metaLine('invoice.print.customer'.tr(), data.partyName),
              _metaLine(
                'invoice.print.datetime'.tr(),
                '$dateText  $timeText',
              ),
              pw.SizedBox(height: 14),
              _buildItemsTable(data),
              pw.SizedBox(height: 12),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      '${'invoice.print.paid'.tr()}: ${data.paidAmount}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Text(
                      '${'invoice.print.outstanding'.tr()}: ${data.outstandingAmount}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  '${'Total'.tr()}: ${data.currency.trim().isEmpty ? data.total : '${data.total} ${data.currency}'}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              if (data.returnPolicyText.trim().isNotEmpty) ...[
                pw.SizedBox(height: 14),
                pw.Text(
                  data.returnPolicyText,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
              if (data.address.trim().isNotEmpty) ...[
                pw.SizedBox(height: 10),
                pw.Text(
                  data.address,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
              if (data.phone.trim().isNotEmpty)
                pw.Text(
                  data.phone,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              pw.SizedBox(height: 16),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  if (footerImg != null)
                    pw.Expanded(
                      child: pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Image(footerImg, height: 64),
                      ),
                    ),
                  if (footerImg != null) pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Row(
                      children: [
                        if (appIcon != null) ...[
                          pw.Image(appIcon, width: 40, height: 40),
                          pw.SizedBox(width: 8),
                        ],
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                data.developerBrand,
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(data.developerName),
                              pw.Text(data.developerPhone),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (data.invoiceFooterNote.trim().isNotEmpty) ...[
                pw.SizedBox(height: 10),
                pw.Text(
                  data.invoiceFooterNote.trim(),
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 8, lineSpacing: 1.15),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _metaLine(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Text(
      '$label: ${value.isEmpty ? '—' : value}',
      style: const pw.TextStyle(fontSize: 11),
    ),
  );
}

pw.Widget _buildItemsTable(A4InvoiceViewData data) {
  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.6),
    columnWidths: {
      0: const pw.FlexColumnWidth(1.1),
      1: const pw.FlexColumnWidth(1.1),
      2: const pw.FlexColumnWidth(1.2),
      3: const pw.FlexColumnWidth(0.9),
      4: const pw.FlexColumnWidth(2.4),
      5: const pw.FlexColumnWidth(1.2),
    },
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          _pdfCell('invoice.print.col_price'.tr(), bold: true),
          _pdfCell('invoice.print.col_discount'.tr(), bold: true),
          _pdfCell('invoice.print.col_total'.tr(), bold: true),
          _pdfCell('invoice.print.col_qty'.tr(), bold: true),
          _pdfCell(
            'invoice.print.col_description'.tr(),
            align: pw.TextAlign.right,
            bold: true,
          ),
          _pdfCell('invoice.print.col_barcode'.tr(), bold: true),
        ],
      ),
      ...data.lines.map(
        (line) => pw.TableRow(
          children: [
            _pdfCell(line.unitPrice),
            _pdfCell(line.discount),
            _pdfCell(line.lineTotal),
            _pdfCell(line.quantity),
            _pdfCell(line.productName, align: pw.TextAlign.right),
            _pdfCell(line.barcode.isEmpty ? '—' : line.barcode),
          ],
        ),
      ),
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          _pdfCell(data.totalsRow.totalUnitPrice),
          _pdfCell(data.totalsRow.totalDiscount, bold: true),
          _pdfCell(data.totalsRow.totalLineAmount, bold: true),
          _pdfCell(data.totalsRow.totalQuantity, bold: true),
          _pdfCell('—'),
          _pdfCell('—'),
        ],
      ),
    ],
  );
}

pw.Widget _pdfCell(
  String text, {
  pw.TextAlign align = pw.TextAlign.center,
  bool bold = false,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: 9.5,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}
