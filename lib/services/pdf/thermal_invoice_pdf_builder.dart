import 'package:clothes_inventory/features/invoices/domain/invoice_print_model.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Builds a narrow receipt-style PDF for thermal printers (58 mm or 80 mm).
///
/// The layout is fully RTL/Arabic-ready and mirrors the information
/// shown on the A4 invoice: header, invoice meta, items, total.
void buildThermalRtlInvoicePage({
  required pw.Document document,
  required InvoicePrintModel invoice,
  required double paperWidthMm,
}) {
  const marginMm = 3.0;
  final pageWidthPt = paperWidthMm * PdfPageFormat.mm;
  final marginPt = marginMm * PdfPageFormat.mm;
  // Use a very tall page – thermal printers consume only what is printed.
  final pageFormat = PdfPageFormat(
    pageWidthPt,
    400 * PdfPageFormat.mm,
    marginAll: marginPt,
  );
  final contentWidthPt = pageWidthPt - marginPt * 2;
  final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(invoice.date);

  document.addPage(
    pw.Page(
      pageFormat: pageFormat,
      build: (context) {
        return pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────────
              pw.Text(
                invoice.companyName,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (invoice.address.isNotEmpty)
                pw.Text(
                  invoice.address,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 7),
                ),
              if (invoice.phone.isNotEmpty)
                pw.Text(
                  invoice.phone,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 7),
                ),
              _separator(contentWidthPt),
              // ── Invoice meta ─────────────────────────────────────────────
              pw.Text(
                invoice.title,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              _metaRow('رقم الفاتورة', invoice.invoiceNumber),
              _metaRow('التاريخ', dateStr),
              _metaRow('العميل', invoice.customerName),
              _separator(contentWidthPt),
              // ── Column headers ───────────────────────────────────────────
              _headerRow(),
              _thinSeparator(contentWidthPt),
              // ── Items ────────────────────────────────────────────────────
              ...invoice.items.map(_itemRow),
              _separator(contentWidthPt),
              // ── Total ────────────────────────────────────────────────────
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
                    'الإجمالي:',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'شكراً لتعاملكم معنا!',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontStyle: pw.FontStyle.italic,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (invoice.invoiceFooterNote.trim().isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Text(
                  invoice.invoiceFooterNote.trim(),
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 7, lineSpacing: 1.15),
                ),
              ],
              if (invoice.invoiceFooterImageBytes != null) ...[
                pw.SizedBox(height: 6),
                pw.Center(
                  child: pw.Image(
                    pw.MemoryImage(invoice.invoiceFooterImageBytes!),
                    width: contentWidthPt * 0.55,
                    fit: pw.BoxFit.contain,
                  ),
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

// ── Helpers ────────────────────────────────────────────────────────────────────

pw.Widget _separator(double width) => pw.Container(
  margin: const pw.EdgeInsets.symmetric(vertical: 3),
  height: 0.5,
  width: width,
  color: PdfColors.black,
);

pw.Widget _thinSeparator(double width) => pw.Container(
  margin: const pw.EdgeInsets.symmetric(vertical: 1),
  height: 0.3,
  width: width,
  color: PdfColors.grey600,
);

pw.Widget _metaRow(String label, String value) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 1),
  child: pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(value, style: const pw.TextStyle(fontSize: 7)),
      pw.Text('$label:', style: const pw.TextStyle(fontSize: 7)),
    ],
  ),
);

pw.Widget _headerRow() => pw.Row(
  children: [
    pw.Expanded(
      flex: 3,
      child: pw.Text(
        'البند',
        textAlign: pw.TextAlign.right,
        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
      ),
    ),
    pw.SizedBox(width: 4),
    pw.Text(
      'الكمية',
      style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
      textAlign: pw.TextAlign.center,
    ),
    pw.SizedBox(width: 4),
    pw.SizedBox(
      width: 40,
      child: pw.Text(
        'الإجمالي',
        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.left,
      ),
    ),
  ],
);

pw.Widget _itemRow(InvoiceItem item) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 1),
  child: pw.Row(
    children: [
      pw.Expanded(
        flex: 3,
        child: pw.Text(
          item.productName,
          textAlign: pw.TextAlign.right,
          style: const pw.TextStyle(fontSize: 7),
          overflow: pw.TextOverflow.clip,
        ),
      ),
      pw.SizedBox(width: 4),
      pw.Text(
        item.quantity.toStringAsFixed(0),
        style: const pw.TextStyle(fontSize: 7),
        textAlign: pw.TextAlign.center,
      ),
      pw.SizedBox(width: 4),
      pw.SizedBox(
        width: 40,
        child: pw.Text(
          item.lineTotal.toStringAsFixed(2),
          style: const pw.TextStyle(fontSize: 7),
          textAlign: pw.TextAlign.left,
        ),
      ),
    ],
  ),
);
