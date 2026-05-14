import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:clothes_inventory/features/sales/data/sales_repository.dart';

class SalesInvoiceLineTile extends StatelessWidget {
  const SalesInvoiceLineTile({
    super.key,
    required this.line,
    required this.selected,
    required this.onTap,
  });

  final SalesInvoiceLine line;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = line.remainingQuantity <= 0
      ? colorScheme.onSurfaceVariant
      : (line.returnedQuantity > 0 ? colorScheme.primary : colorScheme.tertiary);
    final statusLabel = line.remainingQuantity <= 0
        ? 'Fully Returned'.tr()
        : (line.returnedQuantity > 0 ? 'Partial Return'.tr() : 'Open'.tr());
    final statusIcon = line.remainingQuantity <= 0
        ? Icons.block_outlined
        : (line.returnedQuantity > 0
              ? Icons.change_circle_outlined
              : Icons.check_circle_outline);

    return ListTile(
      dense: true,
      selected: selected,
      selectedTileColor: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: 0.45),
      leading: Icon(
        selected ? Icons.radio_button_checked : statusIcon,
        size: 18,
        color: selected ? Theme.of(context).colorScheme.primary : statusColor,
      ),
      title: Text(line.productName),
      subtitle: Text(
        'Item ${line.id} • Qty ${line.quantity.toStringAsFixed(0)} • Returned ${line.returnedQuantity.toStringAsFixed(0)} • Remaining ${line.remainingQuantity.toStringAsFixed(0)}',
      ),
      trailing: SizedBox(
        width: 150,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(line.lineTotal.toStringAsFixed(2)),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: statusColor.withValues(alpha: 0.35)),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      onTap: onTap,
    );
  }
}
