import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class SalesReturnDialogActions extends StatelessWidget {
  const SalesReturnDialogActions({
    super.key,
    required this.canSubmit,
    required this.submittingReturns,
    required this.onCancel,
    required this.onApply,
    this.showAmendInCart = false,
    this.canAmendInCart = false,
    this.onAmendInCart,
  });

  final bool canSubmit;
  final bool submittingReturns;
  final VoidCallback onCancel;
  final VoidCallback onApply;
  final bool showAmendInCart;
  final bool canAmendInCart;
  final VoidCallback? onAmendInCart;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 8,
      children: [
        TextButton.icon(
          onPressed: onCancel,
          icon: const Icon(Icons.close_outlined),
          label: Text('Cancel'.tr()),
        ),
        if (showAmendInCart)
          OutlinedButton.icon(
            onPressed:
                (!submittingReturns && canAmendInCart) ? onAmendInCart : null,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text('sale.edit_invoice_in_cart'.tr()),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
          ),
        FilledButton.icon(
          onPressed: canSubmit ? onApply : null,
          icon: const Icon(Icons.assignment_return_outlined),
          label: Text(
            submittingReturns ? 'Applying...'.tr() : 'Apply Return'.tr(),
          ),
          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
      ],
    );
  }
}
