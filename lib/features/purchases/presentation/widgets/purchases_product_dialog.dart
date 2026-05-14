import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:clothes_inventory/features/products/domain/product.dart';

class PurchasesProductDialog {
  const PurchasesProductDialog._();

  static void _disposeControllersSafely(
    List<TextEditingController> controllers,
  ) {
    // Defer disposal to avoid using disposed controllers during route pop frames.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final controller in controllers) {
          controller.dispose();
        }
      });
    });
  }

  static Future<void> show(
    BuildContext context, {
    Product? existingProduct,
    String? initialName,
    double? initialQuantity,
    double? initialPurchasePrice,
    required double? Function(String value) parseFlexibleNumber,
    required Future<Product> Function(Product payload) onCreateProduct,
    required Future<void> Function(Product payload) onUpdateProduct,
    required Future<void> Function() onRefreshSearch,
    required void Function(Product created, double enteredQuantity)
    onCreatedAttachToCart,
    required void Function(int productId, double unitPrice) onUpdatedSyncCart,
  }) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(
      text: existingProduct?.name ?? (initialName ?? ''),
    );
    final barcodeController = TextEditingController(
      text: existingProduct?.barcode ?? '',
    );
    final salePriceRetailController = TextEditingController(
      text: existingProduct == null
          ? ''
          : existingProduct.salePrice.toStringAsFixed(2),
    );
    final salePriceHalfWholesaleController = TextEditingController(
      text: existingProduct == null
          ? ''
          : existingProduct.salePriceHalfWholesale.toStringAsFixed(2),
    );
    final salePriceWholesaleController = TextEditingController(
      text: existingProduct == null
          ? ''
          : existingProduct.salePriceWholesale.toStringAsFixed(2),
    );
    final purchasePriceController = TextEditingController(
      text: existingProduct == null
          ? (initialPurchasePrice == null
                ? ''
                : initialPurchasePrice.toStringAsFixed(2))
          : existingProduct.purchasePrice.toStringAsFixed(2),
    );
    final quantityController = TextEditingController(
      text: existingProduct == null
          ? (initialQuantity == null
                ? ''
                : ((initialQuantity - initialQuantity.roundToDouble()).abs() <
                          0.000001
                      ? initialQuantity.toStringAsFixed(0)
                      : initialQuantity.toStringAsFixed(2)))
          : '1',
    );
    final lowStockController = TextEditingController(
      text: existingProduct == null
          ? ''
          : existingProduct.lowStockThreshold.toStringAsFixed(0),
    );
    var unit = existingProduct?.unitType ?? UnitType.piece;

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
            title: Text(
              existingProduct == null
                  ? 'Add Product'.tr()
                  : 'Edit Product'.tr(),
            ),
            content: StatefulBuilder(
              builder: (context, setDialogState) {
                final parsedSalePrice = parseFlexibleNumber(
                  salePriceRetailController.text,
                );
                final parsedSalePriceHalfWholesale = parseFlexibleNumber(
                  salePriceHalfWholesaleController.text,
                );
                final parsedSalePriceWholesale = parseFlexibleNumber(
                  salePriceWholesaleController.text,
                );
                final parsedPurchasePrice = parseFlexibleNumber(
                  purchasePriceController.text,
                );
                final isBelowCost =
                    parsedSalePrice != null &&
                    parsedPurchasePrice != null &&
                    parsedSalePrice < parsedPurchasePrice;
                final isHalfWholesaleBelowCost =
                    parsedSalePriceHalfWholesale != null &&
                    parsedPurchasePrice != null &&
                    parsedSalePriceHalfWholesale < parsedPurchasePrice;
                final isWholesaleBelowCost =
                    parsedSalePriceWholesale != null &&
                    parsedPurchasePrice != null &&
                    parsedSalePriceWholesale < parsedPurchasePrice;

                return ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: dialogWidth),
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: nameController,
                            decoration: InputDecoration(labelText: 'Name'.tr()),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Name is required'.tr();
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: veryDense ? 6 : 8),
                          TextFormField(
                            controller: barcodeController,
                            decoration: InputDecoration(
                              labelText: 'Barcode (optional)'.tr(),
                            ),
                          ),
                          SizedBox(height: veryDense ? 6 : 8),
                          DropdownButtonFormField<UnitType>(
                            initialValue: unit,
                            decoration: InputDecoration(
                              labelText: 'Unit Type'.tr(),
                            ),
                            items: UnitType.values
                                .map(
                                  (e) => DropdownMenuItem<UnitType>(
                                    value: e,
                                    child: Text(e.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() => unit = value);
                              }
                            },
                          ),
                          SizedBox(height: veryDense ? 6 : 8),
                          TextFormField(
                            controller: purchasePriceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9٠-٩.,٫٬]'),
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText: 'Purchase Price'.tr(),
                              hintText: '0',
                            ),
                            onChanged: (_) {
                              setDialogState(() {});
                              formKey.currentState?.validate();
                            },
                          ),
                          if (existingProduct == null) ...[
                            SizedBox(height: veryDense ? 6 : 8),
                            TextFormField(
                              controller: quantityController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9٠-٩.,٫٬]'),
                                ),
                              ],
                              decoration: InputDecoration(
                                labelText: 'Purchased Quantity'.tr(),
                                hintText: '1',
                              ),
                              validator: (value) {
                                final quantity = parseFlexibleNumber(
                                  value ?? '',
                                );
                                if (quantity == null || quantity <= 0) {
                                  return 'Quantity must be greater than zero'
                                      .tr();
                                }
                                return null;
                              },
                            ),
                          ],
                          SizedBox(height: veryDense ? 6 : 8),
                          TextFormField(
                            controller: salePriceRetailController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9٠-٩.,٫٬]'),
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText: 'Retail Price'.tr(),
                              hintText: '0',
                              helperText: parsedPurchasePrice == null
                                  ? null
                                  : '${'Minimum sale price'.tr()}: ${parsedPurchasePrice.toStringAsFixed(2)}',
                              helperStyle: TextStyle(
                                color: isBelowCost
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.color,
                                fontWeight: isBelowCost
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            onChanged: (_) => setDialogState(() {}),
                            validator: (value) {
                              final sale = parseFlexibleNumber(value ?? '');
                              final purchase = parseFlexibleNumber(
                                purchasePriceController.text,
                              );
                              if (sale != null &&
                                  purchase != null &&
                                  sale < purchase) {
                                return 'Sale price cannot be less than purchase price.'
                                    .tr();
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: veryDense ? 6 : 8),
                          TextFormField(
                            controller: salePriceHalfWholesaleController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9٠-٩.,٫٬]'),
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText: 'Half Wholesale Price'.tr(),
                              hintText: '0',
                              helperText: parsedPurchasePrice == null
                                  ? null
                                  : '${'Minimum sale price'.tr()}: ${parsedPurchasePrice.toStringAsFixed(2)}',
                              helperStyle: TextStyle(
                                color: isHalfWholesaleBelowCost
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.color,
                                fontWeight: isHalfWholesaleBelowCost
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            onChanged: (_) => setDialogState(() {}),
                            validator: (value) {
                              final sale = parseFlexibleNumber(value ?? '');
                              final purchase = parseFlexibleNumber(
                                purchasePriceController.text,
                              );
                              if (sale != null &&
                                  purchase != null &&
                                  sale < purchase) {
                                return 'Sale price cannot be less than purchase price.'
                                    .tr();
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: veryDense ? 6 : 8),
                          TextFormField(
                            controller: salePriceWholesaleController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9٠-٩.,٫٬]'),
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText: 'Wholesale Price'.tr(),
                              hintText: '0',
                              helperText: parsedPurchasePrice == null
                                  ? null
                                  : '${'Minimum sale price'.tr()}: ${parsedPurchasePrice.toStringAsFixed(2)}',
                              helperStyle: TextStyle(
                                color: isWholesaleBelowCost
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.color,
                                fontWeight: isWholesaleBelowCost
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            onChanged: (_) => setDialogState(() {}),
                            validator: (value) {
                              final sale = parseFlexibleNumber(value ?? '');
                              final purchase = parseFlexibleNumber(
                                purchasePriceController.text,
                              );
                              if (sale != null &&
                                  purchase != null &&
                                  sale < purchase) {
                                return 'Sale price cannot be less than purchase price.'
                                    .tr();
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: veryDense ? 6 : 8),
                          TextFormField(
                            controller: lowStockController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9٠-٩.,٫٬]'),
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText: 'Low Stock Threshold'.tr(),
                              hintText: '0',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            actions: [
              TextButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close_outlined),
                label: Text('Cancel'.tr()),
              ),
              FilledButton.icon(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;

                  final parsedSalePrice = parseFlexibleNumber(
                    salePriceRetailController.text,
                  );
                  final parsedSalePriceHalfWholesale = parseFlexibleNumber(
                    salePriceHalfWholesaleController.text,
                  );
                  final parsedSalePriceWholesale = parseFlexibleNumber(
                    salePriceWholesaleController.text,
                  );
                  final parsedPurchasePrice = parseFlexibleNumber(
                    purchasePriceController.text,
                  );

                  final hasInvalidRetailFormat =
                      salePriceRetailController.text.trim().isNotEmpty &&
                      parsedSalePrice == null;
                  final hasInvalidHalfWholesaleFormat =
                      salePriceHalfWholesaleController.text.trim().isNotEmpty &&
                      parsedSalePriceHalfWholesale == null;
                  final hasInvalidWholesaleFormat =
                      salePriceWholesaleController.text.trim().isNotEmpty &&
                      parsedSalePriceWholesale == null;
                  final hasInvalidPurchaseFormat =
                      purchasePriceController.text.trim().isNotEmpty &&
                      parsedPurchasePrice == null;

                  final hasAnyBelowCost =
                      parsedPurchasePrice != null &&
                      ((parsedSalePrice != null &&
                              parsedSalePrice < parsedPurchasePrice) ||
                          (parsedSalePriceHalfWholesale != null &&
                              parsedSalePriceHalfWholesale <
                                  parsedPurchasePrice) ||
                          (parsedSalePriceWholesale != null &&
                              parsedSalePriceWholesale < parsedPurchasePrice));

                  if (hasInvalidRetailFormat ||
                      hasInvalidHalfWholesaleFormat ||
                      hasInvalidWholesaleFormat ||
                      hasInvalidPurchaseFormat) {
                    if (!dialogContext.mounted) return;
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Please enter valid numeric values.'.tr(),
                        ),
                      ),
                    );
                    return;
                  }

                  if (hasAnyBelowCost) {
                    if (!dialogContext.mounted) return;
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Sale price cannot be less than purchase price.'.tr(),
                        ),
                      ),
                    );
                    return;
                  }

                  try {
                    final resolvedSalePrice =
                        parsedSalePrice ?? (existingProduct?.salePrice ?? 0);
                    final resolvedHalfWholesalePrice =
                        parsedSalePriceHalfWholesale ??
                        (existingProduct?.salePriceHalfWholesale ?? 0);
                    final resolvedWholesalePrice =
                        parsedSalePriceWholesale ??
                        (existingProduct?.salePriceWholesale ?? 0);
                    final resolvedPurchasePrice =
                        parsedPurchasePrice ??
                        (existingProduct?.purchasePrice ?? 0);

                    final payload = Product(
                      id: existingProduct?.id,
                      name: nameController.text.trim(),
                      barcode: barcodeController.text.trim().isEmpty
                          ? null
                          : barcodeController.text.trim(),
                      categoryId: existingProduct?.categoryId,
                      unitType: unit,
                      salePrice: resolvedSalePrice,
                      salePriceHalfWholesale: resolvedHalfWholesalePrice,
                      salePriceWholesale: resolvedWholesalePrice,
                      purchasePrice: resolvedPurchasePrice,
                      lowStockThreshold:
                          parseFlexibleNumber(lowStockController.text) ??
                          (existingProduct?.lowStockThreshold ?? 0),
                    );

                    if (existingProduct == null) {
                      final enteredQuantity =
                          parseFlexibleNumber(quantityController.text.trim()) ??
                          1;
                      final created = await onCreateProduct(payload);
                      await onRefreshSearch();
                      onCreatedAttachToCart(created, enteredQuantity);
                    } else {
                      await onUpdateProduct(payload);
                      await onRefreshSearch();
                      final existingId = existingProduct.id;
                      if (existingId != null && parsedPurchasePrice != null) {
                        onUpdatedSyncCart(existingId, parsedPurchasePrice);
                      }
                    }

                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  } catch (e) {
                    if (!dialogContext.mounted) return;
                    ScaffoldMessenger.of(
                      dialogContext,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                },
                icon: const Icon(Icons.check_circle_outline),
                label: Text('Save'.tr()),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          );
        },
      );
    } finally {
      _disposeControllersSafely(<TextEditingController>[
        nameController,
        barcodeController,
        salePriceRetailController,
        salePriceHalfWholesaleController,
        salePriceWholesaleController,
        purchasePriceController,
        quantityController,
        lowStockController,
      ]);
    }
  }
}
