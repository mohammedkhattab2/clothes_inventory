import 'dart:typed_data';

import 'package:delta_erp/features/invoices/domain/invoice_print_model.dart';
import 'package:delta_erp/services/printing/esc_pos_collected_generator.dart';
import 'package:delta_erp/services/printing/esc_pos_constants.dart';
import 'package:delta_erp/services/printing/escpos_arabic_printer_service.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

/// Builds native ESC/POS text receipts from [InvoicePrintModel].
abstract final class EscPosInvoiceBuilder {
  static Future<Uint8List> build({
    required InvoicePrintModel invoice,
    required double paperWidthMm,
    required bool printerSupportsArabic,
    bool preferImageFallback = false,
    String partyLabel = 'العميل',
  }) async {
    if (preferImageFallback) {
      throw StateError(
        'Image fallback is not supported for ESC/POS thermal printing.',
      );
    }

    final profile = await CapabilityProfile.load();
    final paperSize = paperWidthMm <= 58 ? PaperSize.mm58 : PaperSize.mm80;
    final generator = Generator(paperSize, profile);
    final collector = EscPosCollectedGenerator(
      generator: generator,
      printerSupportsArabic: printerSupportsArabic,
    );
    collector.reset();

    final service = EscPosArabicPrinterService(
      lineWidth: lineWidthForPaper(paperWidthMm),
    );

    await service.printInvoice(
      generator: collector,
      payload: _toPayload(invoice, partyLabel: partyLabel),
      printerSupportsArabic: printerSupportsArabic,
      preferImageFallback: false,
    );

    collector.completeJob(feedLines: 0, cut: true);

    if (collector.bytes.length < 32) {
      throw StateError('Invoice ESC/POS payload is too small to print.');
    }

    return collector.bytes;
  }

  static EscPosInvoicePayload _toPayload(
    InvoicePrintModel invoice, {
    required String partyLabel,
  }) {
    final paid = invoice.paidAmount;
    final outstanding = invoice.outstandingAmount;
    return EscPosInvoicePayload(
      companyName: invoice.companyName,
      address: invoice.address,
      phone: invoice.phone,
      title: invoice.title,
      invoiceNumber: invoice.invoiceNumber,
      createdAt: _formatDateTime(invoice.date),
      partyLabel: partyLabel,
      partyName: invoice.customerName,
      cashierName: invoice.cashierName,
      currency: invoice.currency,
      total: invoice.total.toStringAsFixed(2),
      paidAmount: paid > 0.000001 ? paid.toStringAsFixed(2) : '',
      outstandingAmount:
          outstanding > 0.000001 ? outstanding.toStringAsFixed(2) : '',
      returnPolicyNote: invoice.returnPolicyNote,
      invoiceFooterNote: invoice.invoiceFooterNote,
      lines: invoice.items
          .map(
            (item) => EscPosInvoiceLine(
              name: item.productName,
              quantity: item.quantity.toStringAsFixed(0),
              unitPrice: item.unitPrice.toStringAsFixed(2),
              discount: item.discount.toStringAsFixed(2),
              lineTotal: item.effectiveLineTotal.toStringAsFixed(2),
            ),
          )
          .toList(growable: false),
    );
  }

  static String _formatDateTime(DateTime value) {
    final yyyy = value.year.toString().padLeft(4, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd $hh:$min';
  }
}
