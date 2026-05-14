import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PurchasesCancelDialog {
  const PurchasesCancelDialog._();

  static Future<void> show(
    BuildContext context, {
    int? initialPurchaseId,
    required int? Function(String value) parseFlexibleInt,
    required Widget Function(Widget child) animateDialogEntrance,
    required Future<bool> Function(int purchaseId) onConfirmCancel,
  }) async {
    final purchaseIdController = TextEditingController(
      text: initialPurchaseId?.toString() ?? '',
    );

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final colorScheme = Theme.of(dialogContext).colorScheme;
          final veryDense = MediaQuery.sizeOf(dialogContext).height < 720;

          return animateDialogEntrance(
            Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: (MediaQuery.sizeOf(dialogContext).width * 0.94)
                      .clamp(320.0, 560.0),
                ),
                child: Padding(
                  padding: EdgeInsets.all(veryDense ? 12 : 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.errorContainer
                                  .withValues(alpha: 0.9),
                              colorScheme.tertiaryContainer
                                  .withValues(alpha: 0.65),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.cancel_outlined,
                              color: colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Cancel Purchase Invoice'.tr(),
                                style: Theme.of(dialogContext)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: colorScheme.onErrorContainer,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: veryDense ? 10 : 12),
                      TextField(
                        controller: purchaseIdController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9٠-٩]'),
                          ),
                        ],
                        onTap: () {
                          purchaseIdController.selection = TextSelection(
                            baseOffset: 0,
                            extentOffset: purchaseIdController.text.length,
                          );
                        },
                        decoration: InputDecoration(
                          labelText: 'Purchase ID'.tr(),
                        ),
                      ),
                      SizedBox(height: veryDense ? 6 : 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer.withValues(
                            alpha: 0.45,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: colorScheme.error.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          'This action cannot be undone.'.tr(),
                          style: Theme.of(
                            dialogContext,
                          ).textTheme.bodySmall?.copyWith(
                            color: colorScheme.error,
                          ),
                        ),
                      ),
                      SizedBox(height: veryDense ? 10 : 12),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close_outlined),
                            label: Text('No'.tr()),
                          ),
                          FilledButton.icon(
                            onPressed: () async {
                              final purchaseId = parseFlexibleInt(
                                purchaseIdController.text,
                              );
                              if (purchaseId == null) return;
                              final success = await onConfirmCancel(purchaseId);
                              if (success && dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                            },
                            icon: const Icon(Icons.cancel_outlined),
                            label: Text('Confirm Cancel'.tr()),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    } finally {
      purchaseIdController.dispose();
    }
  }
}
