import 'dart:typed_data';

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
      textDirection: TextDirection.rtl,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(24),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Color(0xFF111111)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderSection(data: data, logoBytes: logoBytes),
              const SizedBox(height: 18),
              _InvoiceInfoSection(
                title: data.title,
                invoiceNumber: data.invoiceNumber,
                dateText: dateText,
                timeText: timeText,
              ),
              const SizedBox(height: 12),
              const Divider(thickness: 0.8, color: Color(0xFF2F2F2F)),
              const SizedBox(height: 10),
              Text(
                '${data.partyLabel}: ${data.partyName}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _ItemsTable(lines: data.lines),
              const SizedBox(height: 14),
              _TotalSection(total: data.total, currency: data.currency),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'شكراً لتعاملكم معنا!',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF222222),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              if (data.invoiceFooterNote.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  data.invoiceFooterNote,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, height: 1.35),
                ),
              ],
              if (data.invoiceFooterImageBytes != null) ...[
                const SizedBox(height: 12),
                Center(
                  child: Image.memory(
                    data.invoiceFooterImageBytes!,
                    height: 72,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.data, this.logoBytes});
  final A4InvoiceViewData data;
  final Uint8List? logoBytes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (logoBytes != null) ...[
          Center(
            child: Image.memory(
              logoBytes!,
              height: 54,
              width: 54,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          data.companyName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          data.address,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          data.phone,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 6),
        const Divider(thickness: 1.1, color: Color(0xFF2F2F2F)),
      ],
    );
  }
}

class _InvoiceInfoSection extends StatelessWidget {
  const _InvoiceInfoSection({
    required this.title,
    required this.invoiceNumber,
    required this.dateText,
    required this.timeText,
  });

  final String title;
  final String invoiceNumber;
  final String dateText;
  final String timeText;

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                title,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'رقم الفاتورة: $invoiceNumber',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'التاريخ: $dateText',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                'الوقت: $timeText',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ItemsTable extends StatelessWidget {
  const _ItemsTable({required this.lines});
  final List<A4InvoiceLine> lines;

  @override
  Widget build(BuildContext context) {
    return Table(
      border: TableBorder.all(color: const Color(0xFF3A3A3A), width: 0.8),
      textDirection: TextDirection.rtl,
      columnWidths: const {
        0: FlexColumnWidth(1.5),
        1: FlexColumnWidth(1.2),
        2: FlexColumnWidth(4),
      },
      children: [
        const TableRow(
          decoration: BoxDecoration(color: Color(0xFFE3E3E3)),
          children: [
            _Cell('السعر', textAlign: TextAlign.center, bold: true),
            _Cell('الكمية', textAlign: TextAlign.center, bold: true),
            _Cell('المنتج', textAlign: TextAlign.right, bold: true),
          ],
        ),
        ...lines.map(
          (line) => TableRow(
            children: [
              _Cell(line.price, textAlign: TextAlign.center),
              _Cell(line.quantity, textAlign: TextAlign.center),
              _Cell(line.productName, textAlign: TextAlign.right),
            ],
          ),
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.text, {required this.textAlign, this.bold = false});
  final String text;
  final TextAlign textAlign;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        text,
        textAlign: textAlign,
        softWrap: true,
        style: TextStyle(
          fontSize: bold ? 13 : 12,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: bold ? const Color(0xFF111111) : const Color(0xFF1A1A1A),
        ),
      ),
    );
  }
}

class _TotalSection extends StatelessWidget {
  const _TotalSection({required this.total, required this.currency});
  final String total;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final value = currency.trim().isEmpty ? total : '$total $currency';
    return Row(
      textDirection: TextDirection.rtl,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'الإجمالي:',
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
