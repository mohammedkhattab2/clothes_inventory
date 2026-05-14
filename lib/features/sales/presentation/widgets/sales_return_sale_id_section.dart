import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:clothes_inventory/core/widgets/app_inline_loading_indicator.dart';

class SalesReturnSaleIdSection extends StatelessWidget {
  const SalesReturnSaleIdSection({
    super.key,
    required this.canUseInvoicePicker,
    required this.saleId,
    required this.saleIdController,
    required this.loadingInvoiceItems,
    required this.onSaleIdChanged,
    required this.onLoadSaleItems,
  });

  final bool canUseInvoicePicker;
  final int? saleId;
  final TextEditingController saleIdController;
  final bool loadingInvoiceItems;
  final ValueChanged<String> onSaleIdChanged;
  final VoidCallback onLoadSaleItems;

  @override
  Widget build(BuildContext context) {
    if (canUseInvoicePicker) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${'Sale ID'.tr()}: $saleId',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: saleIdController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩]')),
          ],
          decoration: InputDecoration(labelText: 'Sale ID'.tr()),
          onTap: () {
            saleIdController.selection = TextSelection(
              baseOffset: 0,
              extentOffset: saleIdController.text.length,
            );
          },
          onChanged: onSaleIdChanged,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: saleId == null || loadingInvoiceItems
                ? null
                : onLoadSaleItems,
            icon: loadingInvoiceItems
                ? const AppInlineLoadingIndicator(size: 16)
                : const Icon(Icons.sync_outlined),
            label: Text('Load Sale Items'.tr()),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
