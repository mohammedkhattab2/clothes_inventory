import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class SalesCancelDialogActions extends StatelessWidget {
  const SalesCancelDialogActions({
    super.key,
    required this.onNo,
    required this.onConfirmCancel,
  });

  final VoidCallback onNo;
  final VoidCallback onConfirmCancel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 8,
      children: [
        TextButton.icon(
          onPressed: onNo,
          icon: const Icon(Icons.close_outlined),
          label: Text('No'.tr()),
        ),
        FilledButton.icon(
          onPressed: onConfirmCancel,
          icon: const Icon(Icons.cancel_outlined),
          label: Text('Confirm Cancel'.tr()),
          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
      ],
    );
  }
}
