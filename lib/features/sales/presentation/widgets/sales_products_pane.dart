import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:clothes_inventory/features/products/domain/product.dart';

class SalesProductsPane extends StatelessWidget {
  const SalesProductsPane({
    super.key,
    required this.compact,
    required this.veryDense,
    required this.nameSearchController,
    required this.barcodeController,
    required this.searchResults,
    required this.onNameChanged,
    required this.onBarcodeChanged,
    required this.onAddProduct,
    this.bottomChild,
  });

  final bool compact;
  final bool veryDense;
  final TextEditingController nameSearchController;
  final TextEditingController barcodeController;
  final List<Product> searchResults;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onBarcodeChanged;
  final ValueChanged<Product> onAddProduct;
  final Widget? bottomChild;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final productsCard = Card(
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(veryDense ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sales POS'.tr(),
              style:
                  (veryDense
                          ? Theme.of(context).textTheme.headlineSmall
                          : Theme.of(context).textTheme.headlineMedium)
                      ?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
            ),
            SizedBox(height: veryDense ? 8 : 12),
            TextField(
              controller: nameSearchController,
              decoration: InputDecoration(
                labelText: 'Search product by name'.tr(),
              ),
              onChanged: onNameChanged,
            ),
            SizedBox(height: veryDense ? 6 : 8),
            TextField(
              controller: barcodeController,
              decoration: InputDecoration(labelText: 'Barcode (instant)'.tr()),
              onChanged: onBarcodeChanged,
            ),
            SizedBox(height: veryDense ? 8 : 12),
            Expanded(
              child: ListView.builder(
                itemCount: searchResults.length,
                itemBuilder: (context, index) {
                  final item = searchResults[index];
                  final outOfStock = item.currentStock <= 0.000001;
                  return ListTile(
                    dense: true,
                    title: Text(item.name),
                    subtitle: Text(
                      '${item.unitType.name} | ${'Retail'.tr()}: ${item.salePrice.toStringAsFixed(2)} | ${'Half Wholesale'.tr()}: ${item.salePriceHalfWholesale.toStringAsFixed(2)} | ${'Wholesale'.tr()}: ${item.salePriceWholesale.toStringAsFixed(2)} | ${'Available'.tr()}: ${item.currentStock.toStringAsFixed(0)}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      color: colorScheme.primary,
                      onPressed: outOfStock ? null : () => onAddProduct(item),
                      tooltip: outOfStock ? 'Out of Stock'.tr() : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (compact) {
      return productsCard;
    }

    return Column(
      children: [
        Expanded(flex: 6, child: productsCard),
        if (bottomChild != null) ...[
          const SizedBox(height: 12),
          Expanded(flex: 5, child: bottomChild!),
        ],
      ],
    );
  }
}
