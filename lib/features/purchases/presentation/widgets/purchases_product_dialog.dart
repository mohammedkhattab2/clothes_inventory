import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:delta_erp/core/config/company_settings_service.dart';
import 'package:delta_erp/features/products/domain/duplicate_product_barcode_exception.dart';
import 'package:delta_erp/features/products/domain/product.dart';
import 'package:delta_erp/features/products/domain/product_price_validators.dart';
import 'package:delta_erp/services/di/service_locator.dart';
import 'package:delta_erp/services/printing/product_barcode_label_printer.dart';
import 'package:printing/printing.dart';

class PurchasesProductDialog {
  const PurchasesProductDialog._();

  static const int _maxBarcodeLabelCopies = 500;

  static void _disposeDialogResources({
    required List<TextEditingController> controllers,
    List<FocusNode> focusNodes = const [],
  }) {
    // Defer disposal until after the dialog route finishes popping.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final node in focusNodes) {
          node.dispose();
        }
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
    Future<String> Function()? onGenerateBarcode,
    Future<void> Function({
      required String productName,
      required String barcode,
      required int quantity,
      double? amount,
    })?
    onPrintBarcode,
    ProductBarcodeLabelPrinter? barcodeLabelPrinter,
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
    final barcodeFocusNode = FocusNode();
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
    var generatingBarcode = false;
    var unit = existingProduct?.unitType ?? UnitType.piece;
    String normalizeDigits(String raw) {
      const arabicIndicDigits = {
        '٠': '0',
        '١': '1',
        '٢': '2',
        '٣': '3',
        '٤': '4',
        '٥': '5',
        '٦': '6',
        '٧': '7',
        '٨': '8',
        '٩': '9',
      };

      var normalized = raw;
      arabicIndicDigits.forEach((key, value) {
        normalized = normalized.replaceAll(key, value);
      });
      return normalized;
    }

    /// Same rules as [ProductFormDialog] short barcodes (leading letter uppercase).
    String normalizeBarcodeForSave(String raw) {
      final t = normalizeDigits(raw).trim();
      if (t.isEmpty) return '';
      if (t.length == 5 && RegExp(r'^[A-Za-z]\d{4}$').hasMatch(t)) {
        return '${t[0].toUpperCase()}${t.substring(1)}';
      }
      return t;
    }

    int requestedBarcodeLabelCopies() {
      final rawQuantity = existingProduct == null
          ? (parseFlexibleNumber(quantityController.text.trim()) ?? 1)
          : 1.0;
      return rawQuantity < 1 ? 1 : rawQuantity.round();
    }

    int effectiveBarcodeLabelCopies() =>
        requestedBarcodeLabelCopies().clamp(1, _maxBarcodeLabelCopies);

    void notifyIfBarcodeLabelCopiesCapped(BuildContext ctx) {
      if (requestedBarcodeLabelCopies() > _maxBarcodeLabelCopies &&
          ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(
              'purchases.barcode_labels_limited'.tr(
                namedArgs: {'max': '$_maxBarcodeLabelCopies'},
              ),
            ),
          ),
        );
      }
    }

    Future<void> tryAutoGenerateBarcode(
      BuildContext dialogContext,
      StateSetter setDialogState,
    ) async {
      if (existingProduct != null || onGenerateBarcode == null) {
        return;
      }
      if (generatingBarcode) return;

      setDialogState(() => generatingBarcode = true);
      try {
        final generated = await onGenerateBarcode();
        barcodeController.text = generated;
        barcodeController.selection = TextSelection.collapsed(
          offset: generated.length,
        );
      } catch (e) {
        if (!dialogContext.mounted) return;
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          SnackBar(content: Text('${'Failed to generate barcode'.tr()}: $e')),
        );
      } finally {
        if (dialogContext.mounted) {
          setDialogState(() => generatingBarcode = false);
        }
      }
    }

    final autoBarcodeOnce = <bool>[false];
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
                if (!autoBarcodeOnce[0] &&
                    existingProduct == null &&
                    onGenerateBarcode != null &&
                    barcodeController.text.trim().isEmpty) {
                  autoBarcodeOnce[0] = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!dialogContext.mounted) return;
                    tryAutoGenerateBarcode(dialogContext, setDialogState);
                  });
                }
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
                            focusNode: barcodeFocusNode,
                            textInputAction: TextInputAction.next,
                            maxLength: existingProduct == null ? 5 : null,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[A-Za-z0-9٠-٩]'),
                              ),
                            ],
                            onEditingComplete: () {
                              FocusScope.of(dialogContext).nextFocus();
                            },
                            validator: (value) {
                              final t = normalizeBarcodeForSave(value ?? '');
                              if (t.isEmpty) return null;
                              if (existingProduct == null &&
                                  !RegExp(r'^[A-Za-z]\d{4}$').hasMatch(t)) {
                                return 'products.barcode_short_invalid'.tr();
                              }
                              return null;
                            },
                            buildCounter: existingProduct == null
                                ? (_, {required currentLength,
                                    required isFocused,
                                    required maxLength}) =>
                                    null
                                : null,
                            decoration: InputDecoration(
                              labelText: 'Barcode (optional)'.tr(),
                              helperText: existingProduct == null
                                  ? 'products.barcode_short_helper'.tr()
                                  : null,
                              suffixIcon: generatingBarcode
                                  ? const Padding(
                                      padding: EdgeInsets.all(10),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : (existingProduct == null &&
                                          onGenerateBarcode != null
                                      ? IconButton(
                                          tooltip: 'Regenerate'.tr(),
                                          icon:
                                              const Icon(Icons.refresh_rounded),
                                          onPressed: () =>
                                              tryAutoGenerateBarcode(
                                                dialogContext,
                                                setDialogState,
                                              ),
                                        )
                                      : const Icon(Icons.qr_code_2_outlined)),
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
                              final purchase = parseFlexibleNumber(
                                purchasePriceController.text,
                              );
                              final msg = ProductPriceValidators
                                  .retailPriceValidator(
                                value,
                                (raw) => parseFlexibleNumber(raw),
                                requiredMessage:
                                    'products.retail_price_required'.tr(),
                                purchasePrice: purchase,
                                belowCostMessage:
                                    'Sale price cannot be less than purchase price.'
                                        .tr(),
                              );
                              return msg;
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
              if (barcodeLabelPrinter != null)
                OutlinedButton.icon(
                  onPressed: generatingBarcode
                      ? null
                      : () async {
                          final productName = nameController.text.trim();
                          final productBarcode =
                              normalizeBarcodeForSave(barcodeController.text);
                          if (productName.isEmpty || productBarcode.isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Enter product name and barcode first'.tr(),
                                ),
                              ),
                            );
                            return;
                          }

                          notifyIfBarcodeLabelCopiesCapped(dialogContext);
                          final copies = effectiveBarcodeLabelCopies();
                          final printer = barcodeLabelPrinter;

                          final salePrice = parseFlexibleNumber(
                            salePriceRetailController.text,
                          );
                          final companyName =
                              getIt<CompanySettingsService>().settings.name;

                          try {
                            final bytes = await printer.buildLabelPdfBytes(
                              productName: productName,
                              barcodeValue: productBarcode,
                              companyName: companyName,
                              amount: salePrice,
                              copies: copies,
                            );
                            if (!dialogContext.mounted) return;
                            await showDialog<void>(
                              context: dialogContext,
                              builder: (ctx) => Dialog(
                                insetPadding: const EdgeInsets.all(16),
                                child: SizedBox(
                                  width: 420,
                                  height: 560,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          12,
                                          10,
                                          8,
                                          8,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'purchases.barcode_labels_preview_title'
                                                    .tr(
                                                      namedArgs: {
                                                        'count': '$copies',
                                                      },
                                                    ),
                                                style: Theme.of(ctx)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () =>
                                                  Navigator.of(ctx).pop(),
                                              icon: const Icon(Icons.close),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Divider(height: 1),
                                      Expanded(
                                        child: PdfPreview(
                                          padding: EdgeInsets.zero,
                                          build: (format) async => bytes,
                                          canChangeOrientation: false,
                                          canChangePageFormat: false,
                                          canDebug: false,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!dialogContext.mounted) return;
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${'Preview failed'.tr()}: $e',
                                ),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.visibility_outlined),
                  label: Text('Preview'.tr()),
                ),
              if (onPrintBarcode != null)
                OutlinedButton.icon(
                  onPressed: generatingBarcode
                      ? null
                      : () async {
                          final productName = nameController.text.trim();
                          final productBarcode =
                              normalizeBarcodeForSave(barcodeController.text);
                          if (productName.isEmpty || productBarcode.isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Enter product name and barcode first'.tr(),
                                ),
                              ),
                            );
                            return;
                          }

                          notifyIfBarcodeLabelCopiesCapped(dialogContext);
                          final printQuantity = effectiveBarcodeLabelCopies();
                          final salePrice = parseFlexibleNumber(
                            salePriceRetailController.text,
                          );
                          await onPrintBarcode(
                            productName: productName,
                            barcode: productBarcode,
                            quantity: printQuantity,
                            amount: salePrice,
                          );
                        },
                  icon: const Icon(Icons.print_outlined),
                  label: Text('Print Barcode'.tr()),
                ),
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
                  if (ProductPriceValidators.isRetailPriceMissing(
                    parsedSalePrice,
                  )) {
                    return;
                  }
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
                    final resolvedSalePrice = existingProduct == null
                        ? parsedSalePrice!
                        : (parsedSalePrice ?? existingProduct.salePrice);
                    final resolvedHalfWholesalePrice =
                        parsedSalePriceHalfWholesale ??
                        (existingProduct?.salePriceHalfWholesale ?? 0);
                    final resolvedWholesalePrice =
                        parsedSalePriceWholesale ??
                        (existingProduct?.salePriceWholesale ?? 0);
                    final resolvedPurchasePrice =
                        parsedPurchasePrice ??
                        (existingProduct?.purchasePrice ?? 0);

                    final normalizedBarcode =
                        normalizeBarcodeForSave(barcodeController.text);

                    final payload = Product(
                      id: existingProduct?.id,
                      name: nameController.text.trim(),
                      barcode:
                          normalizedBarcode.isEmpty ? null : normalizedBarcode,
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
                      onCreatedAttachToCart(created, enteredQuantity);
                      unawaited(onRefreshSearch());
                    } else {
                      await onUpdateProduct(payload);
                      final existingId = existingProduct.id;
                      if (existingId != null && parsedPurchasePrice != null) {
                        onUpdatedSyncCart(existingId, parsedPurchasePrice);
                      }
                      unawaited(onRefreshSearch());
                    }

                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  } on DuplicateProductBarcodeException {
                    if (!dialogContext.mounted) return;
                    ScaffoldMessenger.of(
                      dialogContext,
                    ).showSnackBar(
                      SnackBar(
                        content: Text('products.duplicate_barcode'.tr()),
                      ),
                    );
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
      _disposeDialogResources(
        focusNodes: [barcodeFocusNode],
        controllers: [
          nameController,
          barcodeController,
          salePriceRetailController,
          salePriceHalfWholesaleController,
          salePriceWholesaleController,
          purchasePriceController,
          quantityController,
          lowStockController,
        ],
      );
    }
  }
}
