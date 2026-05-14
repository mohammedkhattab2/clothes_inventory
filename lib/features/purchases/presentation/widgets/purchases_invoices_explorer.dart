import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:clothes_inventory/core/widgets/app_loading_indicator.dart';
import 'package:clothes_inventory/features/purchases/data/purchases_repository.dart';

class PurchasesInvoicesExplorer extends StatelessWidget {
  const PurchasesInvoicesExplorer({
    super.key,
    required this.fromDate,
    required this.toDate,
    required this.accountId,
    required this.categoryId,
    required this.loadingInvoices,
    required this.invoiceRows,
    required this.invoiceScrollController,
    required this.activeInvoiceId,
    required this.activeInvoiceNumber,
    required this.activePurchaseItemId,
    required this.invoicePage,
    required this.invoicePageSize,
    required this.invoiceLabelBuilder,
    required this.onSelectInvoice,
    required this.onReturnSelected,
    required this.onShowDetails,
    required this.onCancelSelected,
    required this.onPreviousPage,
    required this.onNextPage,
  });

  final DateTime? fromDate;
  final DateTime? toDate;
  final int? accountId;
  final int? categoryId;
  final bool loadingInvoices;
  final List<PurchaseInvoiceSummary> invoiceRows;
  final ScrollController invoiceScrollController;
  final int? activeInvoiceId;
  final String? activeInvoiceNumber;
  final int? activePurchaseItemId;
  final int invoicePage;
  final int invoicePageSize;
  final String Function({required int id, String? rawInvoiceNumber})
  invoiceLabelBuilder;
  final ValueChanged<PurchaseInvoiceSummary> onSelectInvoice;
  final VoidCallback onReturnSelected;
  final VoidCallback onShowDetails;
  final VoidCallback onCancelSelected;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Purchase Invoices'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${'Filters'.tr()}: ${fromDate == null ? 'Any date'.tr() : DateFormat('yyyy-MM-dd').format(fromDate!)} '
              '- ${toDate == null ? 'Any date'.tr() : DateFormat('yyyy-MM-dd').format(toDate!)} '
              '| ${'Account'.tr()}: ${accountId?.toString() ?? 'All'.tr()} '
              '| ${'Category'.tr()}: ${categoryId?.toString() ?? 'All'.tr()}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: loadingInvoices
                  ? AppLoadingIndicator(label: 'Loading invoices...'.tr())
                  : ListView.builder(
                      controller: invoiceScrollController,
                      itemCount: invoiceRows.length,
                      itemBuilder: (context, index) {
                        final row = invoiceRows[index];
                        final highlighted = row.id == activeInvoiceId;
                        return Container(
                          color: highlighted
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                          child: ListTile(
                            dense: true,
                            onTap: () => onSelectInvoice(row),
                            title: Text(
                              '${invoiceLabelBuilder(id: row.id, rawInvoiceNumber: row.invoiceNumber)} • ${row.accountName}',
                            ),
                            subtitle: Text(
                              '${DateFormat('yyyy-MM-dd HH:mm').format(row.createdAt)} • ${row.status} • ${row.totalAmount.toStringAsFixed(2)}',
                            ),
                            trailing: highlighted
                                ? const Icon(Icons.pin_drop_outlined)
                                : null,
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 900;
                final actionButtons = [
                  FilledButton.icon(
                    onPressed: activeInvoiceId == null
                        ? null
                        : onReturnSelected,
                    icon: const Icon(Icons.assignment_return_outlined),
                    label: Text('Return Selected'.tr()),
                  ),
                  OutlinedButton.icon(
                    onPressed: activeInvoiceId == null ? null : onShowDetails,
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: Text('Details'.tr()),
                  ),
                  FilledButton.icon(
                    onPressed: activeInvoiceId == null
                        ? null
                        : onCancelSelected,
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text('Cancel Selected'.tr()),
                  ),
                ];

                if (compact) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: actionButtons,
                  );
                }

                return Row(
                  children: [
                    Expanded(child: actionButtons[0]),
                    const SizedBox(width: 8),
                    Expanded(child: actionButtons[1]),
                    const SizedBox(width: 8),
                    Expanded(child: actionButtons[2]),
                  ],
                );
              },
            ),
            if (activeInvoiceId != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${'Selected'.tr()}: ${invoiceLabelBuilder(id: activeInvoiceId!, rawInvoiceNumber: activeInvoiceNumber)}${activePurchaseItemId == null ? '' : ' • ${'Item'.tr()} $activePurchaseItemId'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: invoicePage > 0 ? onPreviousPage : null,
                  icon: const Icon(Icons.chevron_left),
                  label: Text('Previous'.tr()),
                ),
                Text('${'Page'.tr()} ${invoicePage + 1}'),
                OutlinedButton.icon(
                  onPressed: invoiceRows.length == invoicePageSize
                      ? onNextPage
                      : null,
                  icon: const Icon(Icons.chevron_right),
                  label: Text('Next'.tr()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
