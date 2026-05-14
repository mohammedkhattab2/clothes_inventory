import 'package:intl/intl.dart';
import 'package:clothes_inventory/features/invoices/domain/a4_invoice_view_data.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void buildA4RtlInvoicePage({
  required pw.Document document,
  required A4InvoiceViewData data,
  pw.MemoryImage? logo,
}) {
  final dateText = DateFormat('yyyy-MM-dd').format(data.issuedAt);
  final timeText = DateFormat('HH:mm').format(data.issuedAt);

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => [
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (logo != null)
                    pw.Container(
                      width: 52,
                      height: 52,
                      margin: const pw.EdgeInsets.only(left: 10),
                      child: pw.Image(logo, fit: pw.BoxFit.contain),
                    ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Text(
                          data.companyName,
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          data.address,
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                        pw.Text(
                          data.phone,
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 14),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'التاريخ: $dateText',
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                        pw.Text(
                          'الوقت: $timeText',
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          data.title,
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'رقم الفاتورة: ${data.invoiceNumber}',
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                '${data.partyLabel}: ${data.partyName}',
                textAlign: pw.TextAlign.right,
                style: const pw.TextStyle(fontSize: 11),
              ),
              if (data.issuedBy != null && data.issuedBy!.trim().isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 2),
                  child: pw.Text(
                    'المستخدم: ${data.issuedBy}',
                    textAlign: pw.TextAlign.right,
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey500,
                  width: 0.6,
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.5),
                  1: pw.FlexColumnWidth(1.2),
                  2: pw.FlexColumnWidth(4),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      _pdfCell('السعر', align: pw.TextAlign.center, bold: true),
                      _pdfCell(
                        'الكمية',
                        align: pw.TextAlign.center,
                        bold: true,
                      ),
                      _pdfCell('المنتج', align: pw.TextAlign.right, bold: true),
                    ],
                  ),
                  ...data.lines.map(
                    (line) => pw.TableRow(
                      children: [
                        _pdfCell(line.price, align: pw.TextAlign.center),
                        _pdfCell(line.quantity, align: pw.TextAlign.center),
                        _pdfCell(line.productName, align: pw.TextAlign.right),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 14),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      data.currency.trim().isEmpty
                          ? data.total
                          : '${data.total} ${data.currency}',
                      textAlign: pw.TextAlign.left,
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      'الإجمالي:',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _pdfCell(
  String text, {
  required pw.TextAlign align,
  bool bold = false,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 6),
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: 10.5,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}
