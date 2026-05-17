import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:delta_erp/features/inventory/data/inventory_repository.dart';

class InventoryStockCard extends StatelessWidget {
  const InventoryStockCard({
    required this.row,
    required this.outOfStock,
    required this.isUltraDense,
    required this.formattedLowThreshold,
    required this.formattedCurrentStock,
    this.selectionMode = false,
    this.selected = false,
    this.onSelectionChanged,
    this.onEdit,
    this.onDelete,
    this.emphasizeBarcodeMatch = false,
    super.key,
  });

  final InventoryStockRow row;
  final bool outOfStock;
  final bool isUltraDense;
  final String formattedLowThreshold;
  final String formattedCurrentStock;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<bool>? onSelectionChanged;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool emphasizeBarcodeMatch;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final stockStyle = outOfStock
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.error,
            fontWeight: FontWeight.w700,
          )
        : Theme.of(context).textTheme.titleMedium;

    final cardTint = outOfStock
        ? colorScheme.errorContainer
        : (row.isLow
              ? Colors.orange.withValues(alpha: 0.12)
              : colorScheme.surfaceContainerLow);

    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: cardTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: emphasizeBarcodeMatch
              ? colorScheme.primary
              : (outOfStock
                    ? colorScheme.error.withValues(alpha: 0.45)
                    : colorScheme.outlineVariant),
          width: emphasizeBarcodeMatch ? 2.4 : 1,
        ),
        boxShadow: emphasizeBarcodeMatch
            ? [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isUltraDense ? 7 : 8,
          vertical: isUltraDense ? 2 : 3,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: isUltraDense ? 12 : 13,
                    ),
                  ),
                  SizedBox(height: isUltraDense ? 1 : 2),
                  Text(
                    '${'Unit'.tr()}: ${row.unitType} • ${'Low Stock Threshold'.tr()}: $formattedLowThreshold',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            if (selectionMode)
              Checkbox(
                value: selected,
                visualDensity: VisualDensity.compact,
                onChanged: (value) => onSelectionChanged?.call(value ?? false),
              ),
            if (selectionMode) const SizedBox(width: 2),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isUltraDense ? 5 : 6,
                vertical: isUltraDense ? 1 : 2,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Wrap(
                spacing: isUltraDense ? 4 : 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(
                    _statusIcon(outOfStock: outOfStock, isLow: row.isLow),
                    size: isUltraDense ? 14 : 16,
                    color: _statusColor(
                      context,
                      outOfStock: outOfStock,
                      isLow: row.isLow,
                    ),
                  ),
                  if (!isUltraDense)
                    Text(
                      _statusLabel(
                        outOfStock: outOfStock,
                        isLow: row.isLow,
                      ).tr(),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  Text(formattedCurrentStock, style: stockStyle),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Wrap(
              spacing: 2,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Edit'.tr(),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Delete'.tr(),
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel({required bool outOfStock, required bool isLow}) {
    if (outOfStock) return 'Out of Stock';
    if (isLow) return 'Low Stock';
    return 'In Stock';
  }

  IconData _statusIcon({required bool outOfStock, required bool isLow}) {
    if (outOfStock) return Icons.error_outline;
    if (isLow) return Icons.warning_amber_rounded;
    return Icons.check_circle_outline;
  }

  Color _statusColor(
    BuildContext context, {
    required bool outOfStock,
    required bool isLow,
  }) {
    if (outOfStock) return Theme.of(context).colorScheme.error;
    if (isLow) return Colors.orange;
    return Theme.of(context).colorScheme.primary;
  }
}
