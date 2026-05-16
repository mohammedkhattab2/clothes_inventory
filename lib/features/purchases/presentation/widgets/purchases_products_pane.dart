import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:clothes_inventory/features/products/domain/product.dart';

class PurchasesProductsPane extends StatelessWidget {
  const PurchasesProductsPane({
    super.key,
    required this.compact,
    this.showTitle = true,
    required this.searchController,
    required this.searchResults,
    required this.onSearchChanged,
    required this.onAddProduct,
    required this.onImportItems,
    required this.onDownloadTemplate,
    required this.onEditProduct,
    required this.onDeleteProduct,
    required this.onAddToCart,
    this.importing = false,
    this.savingTemplate = false,
    this.bottomChild,
  });

  final bool compact;
  final bool showTitle;
  final TextEditingController searchController;
  final List<Product> searchResults;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAddProduct;
  final VoidCallback onImportItems;
  final VoidCallback onDownloadTemplate;
  final ValueChanged<Product> onEditProduct;
  final ValueChanged<Product> onDeleteProduct;
  final ValueChanged<Product> onAddToCart;
  final bool importing;
  final bool savingTemplate;
  final Widget? bottomChild;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final veryDense = MediaQuery.sizeOf(context).height < 720;
    final compactActions = MediaQuery.sizeOf(context).width < 760;

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
            if (showTitle) ...[
              Text(
                'Purchase Entry'.tr(),
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
            ],
            if (compactActions)
              Column(
                children: [
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      labelText: 'Search product by name'.tr(),
                    ),
                    onChanged: onSearchChanged,
                  ),
                  SizedBox(height: veryDense ? 6 : 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onAddProduct,
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.add_box_outlined),
                          label: Text('Add Product'.tr()),
                        ),
                      ),
                      SizedBox(width: veryDense ? 6 : 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: importing ? null : onImportItems,
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: importing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.upload_file_outlined),
                          label: Text('Import Items'.tr()),
                        ),
                      ),
                      SizedBox(width: veryDense ? 6 : 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: savingTemplate ? null : onDownloadTemplate,
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: savingTemplate
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.download_outlined),
                          label: Text('Download Template'.tr()),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        labelText: 'Search product by name'.tr(),
                      ),
                      onChanged: onSearchChanged,
                    ),
                  ),
                  SizedBox(width: veryDense ? 6 : 8),
                  OutlinedButton.icon(
                    onPressed: onAddProduct,
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.add_box_outlined),
                    label: Text('Add Product'.tr()),
                  ),
                  SizedBox(width: veryDense ? 6 : 8),
                  OutlinedButton.icon(
                    onPressed: importing ? null : onImportItems,
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: importing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file_outlined),
                    label: Text('Import Items'.tr()),
                  ),
                  SizedBox(width: veryDense ? 6 : 8),
                  OutlinedButton.icon(
                    onPressed: savingTemplate ? null : onDownloadTemplate,
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: savingTemplate
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined),
                    label: Text('Download Template'.tr()),
                  ),
                ],
              ),
            SizedBox(height: veryDense ? 6 : 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                'Import columns hint'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: veryDense ? 8 : 12),
            Expanded(
              child: ListView.builder(
                itemCount: searchResults.length,
                itemBuilder: (context, index) {
                  final product = searchResults[index];
                  return ListTile(
                    dense: true,
                    title: Text(product.name),
                    subtitle: Text(
                      '${product.unitType.name} • ${'Purchase Price'.tr()}: ${product.purchasePrice.toStringAsFixed(2)} • ${'Sale Price'.tr()}: ${product.salePrice.toStringAsFixed(2)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit Product'.tr(),
                          icon: const Icon(Icons.sell_outlined),
                          onPressed: () => onEditProduct(product),
                        ),
                        IconButton(
                          tooltip: 'Delete'.tr(),
                          icon: const Icon(Icons.delete_outline),
                          color: colorScheme.error,
                          onPressed: () => onDeleteProduct(product),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => onAddToCart(product),
                        ),
                      ],
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
