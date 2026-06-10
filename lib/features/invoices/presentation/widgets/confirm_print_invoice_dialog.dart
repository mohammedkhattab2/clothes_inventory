import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

Future<bool?> showConfirmPrintInvoiceDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('checkout.print_invoice_prompt'.tr()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text('checkout.print_invoice_no'.tr()),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text('checkout.print_invoice_yes'.tr()),
        ),
      ],
    ),
  );
}
