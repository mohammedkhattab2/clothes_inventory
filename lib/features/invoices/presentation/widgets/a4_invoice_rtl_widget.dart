import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:delta_erp/features/invoices/domain/a4_invoice_view_data.dart';

class A4InvoiceRtlWidget extends StatelessWidget {
  const A4InvoiceRtlWidget({super.key, required this.data, this.logoBytes});

  final A4InvoiceViewData data;
  final Uint8List? logoBytes;

  @override
  Widget build(BuildContext context) {
    final dateText = intl.DateFormat('yyyy-MM-dd').format(data.issuedAt);
    final timeText = intl.DateFormat('HH:mm').format(data.issuedAt);

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Color(0xFF1A1A1A), height: 1.35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  data.invoiceNumber,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                data.companyName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Color(0xFF0D0D0D),
                ),
              ),
              const SizedBox(height: 12),
              _metaLine(
                'invoice.print.cashier'.tr(),
                data.cashierName.isNotEmpty ? data.cashierName : '—',
              ),
              _metaLine('invoice.print.customer'.tr(), data.partyName),
              _metaLine(
                'invoice.print.datetime'.tr(),
                '$dateText  $timeText',
              ),
              const SizedBox(height: 16),
              _ItemsTable(data: data),
              const SizedBox(height: 14),
              _PaymentsSection(data: data),
              const SizedBox(height: 16),
              if (data.returnPolicyText.trim().isNotEmpty)
                Text(
                  data.returnPolicyText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
              const SizedBox(height: 14),
              if (data.address.trim().isNotEmpty)
                Text(
                  data.address,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              if (data.phone.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  data.phone,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
              const SizedBox(height: 18),
              _FooterBrandingRow(data: data),
              if (data.invoiceFooterNote.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  data.invoiceFooterNote,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, height: 1.35),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$label: $value',
        textAlign: TextAlign.right,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _ItemsTable extends StatelessWidget {
  const _ItemsTable({required this.data});
  final A4InvoiceViewData data;

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFF3A3A3A);
    const headerBg = Color(0xFFE8E8E8);

    Widget headerCell(String text) => _Cell(text, bold: true);
    Widget bodyCell(
      String text, {
      TextAlign align = TextAlign.center,
      bool bold = false,
    }) =>
        _Cell(text, textAlign: align, bold: bold);

    return Table(
      border: TableBorder.all(color: borderColor, width: 0.8),
      textDirection: ui.TextDirection.rtl,
      columnWidths: const {
        0: FlexColumnWidth(1.1),
        1: FlexColumnWidth(1.1),
        2: FlexColumnWidth(1.2),
        3: FlexColumnWidth(0.9),
        4: FlexColumnWidth(2.4),
        5: FlexColumnWidth(1.2),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: headerBg),
          children: [
            headerCell('invoice.print.col_price'.tr()),
            headerCell('invoice.print.col_discount'.tr()),
            headerCell('invoice.print.col_total'.tr()),
            headerCell('invoice.print.col_qty'.tr()),
            headerCell('invoice.print.col_description'.tr()),
            headerCell('invoice.print.col_barcode'.tr()),
          ],
        ),
        ...data.lines.map(
          (line) => TableRow(
            children: [
              bodyCell(line.unitPrice),
              bodyCell(line.discount),
              bodyCell(line.lineTotal),
              bodyCell(line.quantity),
              bodyCell(line.productName, align: TextAlign.right),
              bodyCell(line.barcode.isEmpty ? '—' : line.barcode),
            ],
          ),
        ),
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFF4F4F4)),
          children: [
            bodyCell(data.totalsRow.totalUnitPrice),
            bodyCell(data.totalsRow.totalDiscount, bold: true),
            bodyCell(data.totalsRow.totalLineAmount, bold: true),
            bodyCell(data.totalsRow.totalQuantity, bold: true),
            bodyCell('—'),
            bodyCell('—'),
          ],
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(
    this.text, {
    this.bold = false,
    this.textAlign = TextAlign.center,
  });

  final String text;
  final bool bold;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: Text(
        text,
        textAlign: textAlign,
        softWrap: true,
        style: TextStyle(
          fontSize: bold ? 12.5 : 11.5,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

class _PaymentsSection extends StatelessWidget {
  const _PaymentsSection({required this.data});
  final A4InvoiceViewData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          textDirection: ui.TextDirection.rtl,
          children: [
            Expanded(
              child: Text(
                '${'invoice.print.paid'.tr()}: ${data.paidAmount}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                '${'invoice.print.outstanding'.tr()}: ${data.outstandingAmount}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${'Total'.tr()}: ${data.currency.trim().isEmpty ? data.total : '${data.total} ${data.currency}'}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _FooterBrandingRow extends StatelessWidget {
  const _FooterBrandingRow({required this.data});
  final A4InvoiceViewData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: ui.TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (data.invoiceFooterImageBytes != null)
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Image.memory(
                data.invoiceFooterImageBytes!,
                height: 72,
                fit: BoxFit.contain,
              ),
            ),
          ),
        if (data.invoiceFooterImageBytes != null) const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Row(
            textDirection: ui.TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (data.appIconBytes != null)
                Image.memory(
                  data.appIconBytes!,
                  width: 44,
                  height: 44,
                  fit: BoxFit.contain,
                ),
              if (data.appIconBytes != null) const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.developerBrand,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      data.developerName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      data.developerPhone,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
