import 'package:easy_localization/easy_localization.dart';

import 'package:flutter/material.dart';

import 'package:delta_erp/services/printing/print_batch_failure.dart';



/// Shows a short confirmation after all print jobs complete on the printer.

/// Call only after [ProductBarcodeLabelPrinter.printLabel]

/// or [printInvoiceToSavedPrinter] complete without throwing.

void showPrintSentToPrinterSnackBar(BuildContext context) {

  if (!context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);

  messenger.removeCurrentSnackBar();

  messenger.showSnackBar(
    SnackBar(content: Text('print.sent_to_printer'.tr())),
  );

}



/// Formats barcode/invoice print errors, including partial multi-batch failures.

String formatPrintFailureMessage(Object error, {required String fallbackKey}) {

  if (error is PrintBatchFailure) {

    if (error.completedCopies > 0) {

      return 'print.partial_batch_failure'.tr(

        namedArgs: {

          'completed': '${error.completedCopies}',

          'requested': '${error.requestedCopies}',

          'details': error.cause.toString(),

        },

      );

    }

    return '${fallbackKey.tr()}: ${error.cause}';

  }

  return '${fallbackKey.tr()}: $error';

}


