import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:clothes_inventory/features/products/domain/product.dart';

/// Single-row purchase entry: product name autocomplete + barcode (LTR order).
class PurchasesCheckoutToolbar extends StatelessWidget {
  const PurchasesCheckoutToolbar({
    super.key,
    required this.veryDense,
    required this.colorScheme,
    required this.nameFocusNode,
    required this.nameSearchController,
    required this.barcodeController,
    required this.barcodeFocusNode,
    required this.searchProducts,
    required this.onProductSelected,
    required this.onBarcodeChanged,
    required this.onBarcodeSubmitted,
  });

  final bool veryDense;
  final ColorScheme colorScheme;
  final FocusNode nameFocusNode;
  final TextEditingController nameSearchController;
  final TextEditingController barcodeController;
  final FocusNode barcodeFocusNode;
  final Future<List<Product>> Function(String query) searchProducts;
  final ValueChanged<Product> onProductSelected;
  final ValueChanged<String> onBarcodeChanged;
  final ValueChanged<String> onBarcodeSubmitted;

  @override
  Widget build(BuildContext context) {
    final gap = veryDense ? 8.0 : 12.0;
    final radius = BorderRadius.circular(14);
    return Material(
      color: colorScheme.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(veryDense ? 10 : 14),
        child: Directionality(
          textDirection: ui.TextDirection.ltr,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: RawAutocomplete<Product>(
                  textEditingController: nameSearchController,
                  focusNode: nameFocusNode,
                  displayStringForOption: (p) => p.name,
                  optionsBuilder: (tv) async {
                    final q = tv.text.trim();
                    if (q.isEmpty) {
                      return const Iterable<Product>.empty();
                    }
                    await Future<void>.delayed(
                      const Duration(milliseconds: 280),
                    );
                    if (tv.text.trim() != q) {
                      return const Iterable<Product>.empty();
                    }
                    return searchProducts(q);
                  },
                  onSelected: onProductSelected,
                  fieldViewBuilder: (
                    context,
                    textEditingController,
                    focusNode,
                    onFieldSubmitted,
                  ) {
                    return TextField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Search product by name'.tr(),
                        hintText: 'sales.checkout.type_to_search_products'.tr(),
                        border: OutlineInputBorder(borderRadius: radius),
                        filled: true,
                        fillColor: colorScheme.surface,
                      ),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: AlignmentDirectional.topStart,
                      child: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(12),
                        color: colorScheme.surfaceContainerHigh,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxHeight: 280,
                            minWidth: 280,
                          ),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final item = options.elementAt(index);
                              return ListTile(
                                dense: true,
                                title: Text(item.name),
                                subtitle: Text(
                                  '${item.unitType.name} • ${'Purchase Price'.tr()}: ${item.purchasePrice.toStringAsFixed(2)} • ${'Sale Price'.tr()}: ${item.salePrice.toStringAsFixed(2)}',
                                ),
                                onTap: () => onSelected(item),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                flex: 4,
                child: TextField(
                  controller: barcodeController,
                  focusNode: barcodeFocusNode,
                  decoration: InputDecoration(
                    labelText: 'sales.checkout.barcode_label'.tr(),
                    hintText: 'sales.checkout.barcode_hint'.tr(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      tooltip: 'sales.checkout.barcode_focus_tooltip'.tr(),
                      onPressed: barcodeFocusNode.requestFocus,
                    ),
                    border: OutlineInputBorder(borderRadius: radius),
                    filled: true,
                    fillColor: colorScheme.surface,
                  ),
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  enableSuggestions: false,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'[\r\n]')),
                  ],
                  onChanged: onBarcodeChanged,
                  onSubmitted: onBarcodeSubmitted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
