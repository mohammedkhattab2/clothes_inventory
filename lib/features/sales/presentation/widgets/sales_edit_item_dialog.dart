import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:clothes_inventory/features/sales/domain/sale_models.dart';

class SalesEditItemDialog {
  const SalesEditItemDialog._();

  static Future<void> show(
    BuildContext context, {
    required SaleDraftItem item,
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
          final dialogWidth = (MediaQuery.sizeOf(dialogContext).width * 0.9)
              .clamp(280.0, 420.0);
          return AlertDialog(
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
                      decoration: InputDecoration(labelText: 'Quantity'.tr()),
                    ),
                    const SizedBox(height: 8),
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
                      decoration: InputDecoration(labelText: 'Unit Price'.tr()),
                    ),
                    const SizedBox(height: 8),
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
                      decoration: InputDecoration(labelText: 'Discount'.tr()),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text('Cancel'.tr()),
              ),
              FilledButton(
                onPressed: () {
                  final newQty = parseFlexibleNumber(qtyController.text);
                  if (newQty != null &&
                      newQty > item.availableStock + 0.000001) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Cannot sell more than available stock.'.tr(),
                        ),
                      ),
                    );
                    return;
                  }

                  final newPrice = parseFlexibleNumber(priceController.text);
                  if (newPrice != null &&
                      newPrice < item.minUnitPrice - 0.000001) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Sale price cannot be less than purchase price.'.tr(),
                        ),
                      ),
                    );
                    return;
                  }

                  onApply(
                    quantity: newQty,
                    unitPrice: newPrice,
                    discount: parseFlexibleNumber(discountController.text),
                  );
                  Navigator.of(dialogContext).pop();
                },
                child: Text('Apply'.tr()),
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
