import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:clothes_inventory/core/widgets/app_inline_loading_indicator.dart';
import 'package:clothes_inventory/features/invoices/domain/invoice_suggestion.dart';
import 'package:clothes_inventory/features/invoices/presentation/widgets/invoice_return_raw_autocomplete.dart';

class SalesReturnSaleIdSection extends StatelessWidget {
  const SalesReturnSaleIdSection({
    super.key,
    required this.canUseInvoicePicker,
    this.activeInvoiceNumber,
    required this.resolvedSaleId,
    required this.saleIdController,
    required this.loadingInvoiceItems,
    required this.searchSuggestions,
    required this.onInvoiceQueryActivity,
    required this.onSuggestionChosen,
    required this.onLoadSaleItems,
  });

  final bool canUseInvoicePicker;
  /// Label for the invoice when the picker is locked to [activeInvoiceId].
  final String? activeInvoiceNumber;
  final int? resolvedSaleId;
  final TextEditingController saleIdController;
  final bool loadingInvoiceItems;
  final Future<List<InvoiceSuggestion>> Function(String prefix) searchSuggestions;
  final VoidCallback onInvoiceQueryActivity;
  final ValueChanged<InvoiceSuggestion> onSuggestionChosen;
  final VoidCallback onLoadSaleItems;

  @override
  Widget build(BuildContext context) {
    if (canUseInvoicePicker) {
      final id = resolvedSaleId;
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${'invoice_return.active_invoice_hint'.tr()}: '
              '${activeInvoiceNumber ?? '—'} (#$id)',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InvoiceReturnRawAutocomplete(
          controller: saleIdController,
          searchSuggestions: searchSuggestions,
          onSuggestionSelected: onSuggestionChosen,
          onTextEdited: onInvoiceQueryActivity,
          labelText: 'invoice_return.search_invoice_label_sale'.tr(),
          hintText: 'invoice_return.search_invoice_hint_prefix'.tr(),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: resolvedSaleId == null || loadingInvoiceItems
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
