import 'package:delta_erp/core/printing/invoice_print_dispatch.dart';
import 'package:delta_erp/core/printing/print_user_feedback.dart';
import 'package:delta_erp/features/invoices/domain/invoice_print_model.dart';
import 'package:delta_erp/features/invoices/presentation/widgets/confirm_print_invoice_dialog.dart';
import 'package:delta_erp/services/printing/invoice_print_manager.dart';
import 'package:flutter/material.dart';

/// After checkout succeeds, asks whether to print and sends directly to the printer.
Future<void> promptCheckoutInvoicePrint({
  required BuildContext context,
  required InvoicePrintModel invoice,
  required InvoicePrintManager printManager,
}) async {
  final shouldPrint = await showConfirmPrintInvoiceDialog(context);
  if (shouldPrint != true || !context.mounted) return;

  try {
    await printInvoiceToSavedPrinter(
      printManager: printManager,
      invoice: invoice,
    );
    if (!context.mounted) return;
    showPrintSentToPrinterSnackBar(context);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(formatPrintFailureMessage(e, fallbackKey: 'Failed to print invoice'))),
    );
  }
}
