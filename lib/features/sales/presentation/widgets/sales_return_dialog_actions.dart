import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class SalesReturnDialogActions extends StatelessWidget {
  const SalesReturnDialogActions({
    super.key,
    required this.canSubmit,
    required this.submittingReturns,
    required this.onCancel,
    required this.onApply,
  });

  final bool canSubmit;
  final bool submittingReturns;
  final VoidCallback onCancel;
  final VoidCallback onApply;

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
