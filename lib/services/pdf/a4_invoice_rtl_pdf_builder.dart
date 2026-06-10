import 'package:easy_localization/easy_localization.dart';
import 'package:delta_erp/features/invoices/domain/a4_invoice_view_data.dart';
import 'package:delta_erp/services/pdf/invoice_pdf_theme.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const _tableColumnWidths = {
  0: pw.FlexColumnWidth(1.1),
  1: pw.FlexColumnWidth(1.1),
  2: pw.FlexColumnWidth(1.2),
  3: pw.FlexColumnWidth(0.9),
  4: pw.FlexColumnWidth(2.4),
  5: pw.FlexColumnWidth(1.2),
};

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
  final marginPt = InvoicePdfTheme.a4MarginMm * PdfPageFormat.mm;
  final borderWidth = InvoicePdfTheme.a4BorderWidth;

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.all(marginPt),
      textDirection: pw.TextDirection.rtl,
      header: (context) => pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            if (context.pageNumber == 1) ...[
              _buildCompanyLetterhead(data: data, logo: logo),
              pw.SizedBox(height: 8),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  data.invoiceNumber,
                  style: pw.TextStyle(
                    fontSize: InvoicePdfTheme.a4InvoiceNumberFontSize,
                    fontWeight: pw.FontWeight.bold,
                    color: InvoicePdfTheme.textColor,
                  ),
                ),
              ),
              pw.SizedBox(height: 6),
              _metaLine('invoice.print.cashier'.tr(), data.cashierName),
              _metaLine('invoice.print.customer'.tr(), data.partyName),
              _metaLine(
                'invoice.print.datetime'.tr(),
                '$dateText  $timeText',
              ),
              pw.SizedBox(height: 8),
            ],
            _buildTableHeaderRow(borderWidth: borderWidth),
          ],
        ),
      ),
      build: (context) => [
        ...data.lines.map((line) => _buildItemRow(line, borderWidth: borderWidth)),
        _buildTotalsRow(data, borderWidth: borderWidth),
        pw.SizedBox(height: 12),
        ..._buildPaymentsSection(data),
        ..._buildFooterSection(
          data: data,
          footerImg: footerImg,
          appIcon: appIcon,
        ),
      ],
    ),
  );
}

pw.Widget _buildCompanyLetterhead({
  required A4InvoiceViewData data,
  pw.MemoryImage? logo,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Container(
        color: InvoicePdfTheme.headerBandColor,
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null) ...[
              pw.Container(
                width: 72,
                height: 72,
                alignment: pw.Alignment.center,
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(width: 12),
            ],
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    data.companyName,
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      fontSize: InvoicePdfTheme.a4CompanyNameFontSize,
                      fontWeight: pw.FontWeight.bold,
                      color: InvoicePdfTheme.textColor,
                    ),
                  ),
                  if (data.address.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      data.address.trim(),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: InvoicePdfTheme.a4MetaFontSize,
                        color: InvoicePdfTheme.textColor,
                      ),
                    ),
                  ],
                  if (data.phone.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      data.phone.trim(),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: InvoicePdfTheme.a4MetaFontSize,
                        color: InvoicePdfTheme.textColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      pw.Container(
        height: 1,
        color: InvoicePdfTheme.borderColor,
      ),
    ],
  );
}

List<pw.Widget> _buildPaymentsSection(A4InvoiceViewData data) {
  return [
    pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            '${'invoice.print.paid'.tr()}: ${data.paidAmount}',
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: InvoicePdfTheme.textColor,
              fontSize: InvoicePdfTheme.a4MetaFontSize,
            ),
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Text(
            '${'invoice.print.outstanding'.tr()}: ${data.outstandingAmount}',
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: InvoicePdfTheme.textColor,
              fontSize: InvoicePdfTheme.a4MetaFontSize,
            ),
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
          fontSize: InvoicePdfTheme.a4TotalFontSize,
          fontWeight: pw.FontWeight.bold,
          color: InvoicePdfTheme.textColor,
        ),
      ),
    ),
    if (data.returnPolicyText.trim().isNotEmpty) ...[
      pw.SizedBox(height: 12),
      pw.Text(
        data.returnPolicyText,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: InvoicePdfTheme.a4MetaFontSize,
          fontWeight: pw.FontWeight.bold,
          color: InvoicePdfTheme.textColor,
        ),
      ),
    ],
    pw.SizedBox(height: 14),
  ];
}

List<pw.Widget> _buildFooterSection({
  required A4InvoiceViewData data,
  pw.MemoryImage? footerImg,
  pw.MemoryImage? appIcon,
}) {
  return [
    if (data.invoiceFooterNote.trim().isNotEmpty) ...[
      pw.Text(
        data.invoiceFooterNote.trim(),
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: InvoicePdfTheme.a4FooterNoteFontSize,
          lineSpacing: 1.2,
          color: InvoicePdfTheme.textColor,
        ),
      ),
      pw.SizedBox(height: 10),
    ],
    if (footerImg != null) ...[
      pw.Center(child: pw.Image(footerImg, height: 64)),
      pw.SizedBox(height: 10),
    ],
    pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: InvoicePdfTheme.borderColor, width: 0.5),
        ),
      ),
      child: pw.Column(
        children: [
          if (appIcon != null)
            pw.Image(appIcon, width: 24, height: 24),
          pw.Text(
            data.developerBrand,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: InvoicePdfTheme.a4DeveloperFontSize,
              fontWeight: pw.FontWeight.bold,
              color: InvoicePdfTheme.textColor,
            ),
          ),
          pw.Text(
            data.developerName,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: InvoicePdfTheme.a4DeveloperFontSize,
              color: InvoicePdfTheme.textColor,
            ),
          ),
          pw.Text(
            data.developerPhone,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: InvoicePdfTheme.a4DeveloperFontSize,
              color: InvoicePdfTheme.textColor,
            ),
          ),
        ],
      ),
    ),
  ];
}

pw.Widget _metaLine(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Text(
      '$label: ${value.isEmpty ? '—' : value}',
      textAlign: pw.TextAlign.right,
      style: pw.TextStyle(
        fontSize: InvoicePdfTheme.a4MetaFontSize,
        color: InvoicePdfTheme.textColor,
      ),
    ),
  );
}

pw.Widget _buildTableHeaderRow({required double borderWidth}) {
  return pw.Table(
    border: InvoicePdfTheme.fullTableBorder(width: borderWidth),
    columnWidths: _tableColumnWidths,
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: InvoicePdfTheme.tableHeaderBg),
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
    ],
  );
}

pw.Widget _buildItemRow(A4InvoiceLine line, {required double borderWidth}) {
  return pw.Table(
    border: InvoicePdfTheme.fullTableBorder(width: borderWidth),
    columnWidths: _tableColumnWidths,
    children: [
      pw.TableRow(
        children: [
          _pdfCell(line.unitPrice),
          _pdfCell(line.discount),
          _pdfCell(line.lineTotal),
          _pdfCell(line.quantity),
          _pdfCell(line.productName, align: pw.TextAlign.right),
          _pdfCell(line.barcode.isEmpty ? '—' : line.barcode),
        ],
      ),
    ],
  );
}

pw.Widget _buildTotalsRow(A4InvoiceViewData data, {required double borderWidth}) {
  return pw.Table(
    border: InvoicePdfTheme.fullTableBorder(width: borderWidth),
    columnWidths: _tableColumnWidths,
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: InvoicePdfTheme.tableTotalsBg),
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
        fontSize: InvoicePdfTheme.a4CellFontSize,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: InvoicePdfTheme.textColor,
      ),
    ),
  );
}
