import 'package:delta_erp/features/invoices/domain/invoice_print_model.dart';
import 'package:delta_erp/features/invoices/presentation/widgets/confirm_print_invoice_dialog.dart';
import 'package:delta_erp/services/printing/invoice_print_manager.dart';
import 'package:delta_erp/services/printing/invoice_print_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
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
    const preferences = InvoicePrintPreferences();
    final config = await preferences.load();
    await printManager.printInvoice(invoice, config);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invoice sent to printer.'.tr())),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${'Failed to print invoice'.tr()}: $e')),
    );
  }
}
