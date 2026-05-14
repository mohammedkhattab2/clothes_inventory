import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:clothes_inventory/features/purchases/domain/purchase_models.dart';

class PurchasesEditItemDialog {
  const PurchasesEditItemDialog._();

  static Future<void> show(
    BuildContext context, {
    required PurchaseDraftItem item,
    required double? Function(String value) parseFlexibleNumber,
    required void Function({
      double? quantity,
      double? unitPrice,
      double? discount,
    })
    onApply,
  }) async {
    final qtyController = TextEditingController(text: item.quantity.toString());
    final priceController = TextEditingController(
      text: item.unitPrice.toStringAsFixed(2),
    );
    final discountController = TextEditingController(
      text: item.discount.toStringAsFixed(2),
    );

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final colorScheme = Theme.of(dialogContext).colorScheme;
          final veryDense = MediaQuery.sizeOf(dialogContext).height < 720;
          final dialogWidth = (MediaQuery.sizeOf(dialogContext).width * 0.9)
              .clamp(280.0, 420.0);
          return AlertDialog(
            backgroundColor: colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            actionsOverflowDirection: VerticalDirection.down,
            title: Text('${'Edit'.tr()} ${item.productName}'),
            content: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: dialogWidth),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: qtyController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9٠-٩.,٫٬]'),
                        ),
                      ],
                      onTap: () {
                        qtyController.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: qtyController.text.length,
                        );
                      },
                      decoration: InputDecoration(labelText: 'Quantity'.tr()),
                    ),
                    SizedBox(height: veryDense ? 6 : 8),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9٠-٩.,٫٬]'),
                        ),
                      ],
                      onTap: () {
                        priceController.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: priceController.text.length,
                        );
                      },
                      decoration: InputDecoration(labelText: 'Unit price'.tr()),
                    ),
                    SizedBox(height: veryDense ? 6 : 8),
                    TextField(
                      controller: discountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9٠-٩.,٫٬]'),
                        ),
                      ],
                      onTap: () {
                        discountController.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: discountController.text.length,
                        );
                      },
                      decoration: InputDecoration(labelText: 'Discount'.tr()),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close_outlined),
                label: Text('Cancel'.tr()),
              ),
              FilledButton.icon(
                onPressed: () {
                  onApply(
                    quantity: parseFlexibleNumber(qtyController.text),
                    unitPrice: parseFlexibleNumber(priceController.text),
                    discount: parseFlexibleNumber(discountController.text),
                  );
                  Navigator.of(dialogContext).pop();
                },
                icon: const Icon(Icons.check_circle_outline),
                label: Text('Apply'.tr()),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          );
        },
      );
    } finally {
      qtyController.dispose();
      priceController.dispose();
      discountController.dispose();
    }
  }
}
