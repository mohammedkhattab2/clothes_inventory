import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:clothes_inventory/features/sales/data/sales_repository.dart';

class SalesReturnLinePickerCard extends StatelessWidget {
  const SalesReturnLinePickerCard({
    super.key,
    required this.line,
    required this.isSelected,
    required this.qtyRaw,
    required this.error,
    required this.onSelectionChanged,
    required this.onQuantityChanged,
    required this.onUseRemaining,
  });

  final SalesInvoiceLine line;
  final bool isSelected;
  final String qtyRaw;
  final String? error;
  final ValueChanged<bool> onSelectionChanged;
  final ValueChanged<String> onQuantityChanged;
  final VoidCallback onUseRemaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: line.remainingQuantity <= 0
                    ? null
                    : (value) => onSelectionChanged(value ?? false),
              ),
              Expanded(
                child: Text(
                  '${line.productName} • ${'Qty'.tr()}: ${line.quantity.toStringAsFixed(0)} • ${'Return'.tr()}: ${line.returnedQuantity.toStringAsFixed(0)} • ${'Outstanding'.tr()}: ${line.remainingQuantity.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          TextField(
            enabled: isSelected,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩.,٫٬]')),
            ],
            controller: TextEditingController(text: qtyRaw)
              ..selection = TextSelection.collapsed(offset: qtyRaw.length),
            decoration: InputDecoration(
              labelText: 'Return Quantity'.tr(),
              helperText:
                  '${'Outstanding'.tr()}: ${line.remainingQuantity.toStringAsFixed(0)}',
              errorText: isSelected ? error : null,
            ),
            onChanged: onQuantityChanged,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: isSelected ? onUseRemaining : null,
              icon: const Icon(Icons.auto_fix_high_outlined),
              label: Text('Use Remaining'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}
