import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:clothes_inventory/features/products/presentation/widgets/products_summary_chip.dart';

class ProductsSummarySection extends StatelessWidget {
  const ProductsSummarySection({
    super.key,
    required this.isVeryDenseViewport,
    required this.totalProductsCount,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.selectionMode,
    required this.selectedCount,
    required this.onToggleSelectionMode,
    required this.onDeleteSelected,
  });

  final bool isVeryDenseViewport;
  final int totalProductsCount;
  final int lowStockCount;
  final int outOfStockCount;
  final bool selectionMode;
  final int selectedCount;
  final VoidCallback onToggleSelectionMode;
  final Future<void> Function() onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: isVeryDenseViewport ? 6 : 8,
      runSpacing: isVeryDenseViewport ? 6 : 8,
      children: [
        ProductsSummaryChip(
          label: 'Total Products'.tr(),
          value: totalProductsCount.toString(),
          compact: isVeryDenseViewport,
        ),
        ProductsSummaryChip(
          label: 'Low Stock'.tr(),
          value: lowStockCount.toString(),
          color: colorScheme.errorContainer,
          valueColor: colorScheme.onErrorContainer,
          compact: isVeryDenseViewport,
        ),
        ProductsSummaryChip(
          label: 'Out of Stock'.tr(),
          value: outOfStockCount.toString(),
          color: colorScheme.error,
          valueColor: colorScheme.onError,
          compact: isVeryDenseViewport,
        ),
        OutlinedButton.icon(
          onPressed: onToggleSelectionMode,
          icon: Icon(
            selectionMode
                ? Icons.check_box_outlined
                : Icons.check_box_outline_blank,
          ),
          label: Text(
            selectionMode ? 'Exit selection'.tr() : 'Select products'.tr(),
          ),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        if (selectionMode)
          FilledButton.icon(
            onPressed: selectedCount == 0
                ? null
                : () async {
                    await onDeleteSelected();
                  },
            icon: const Icon(Icons.delete_sweep_outlined),
            label: Text('${'Delete selected'.tr()} ($selectedCount)'),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
          ),
      ],
    );
  }
}
