import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:delta_erp/core/widgets/app_loading_indicator.dart';
import 'package:delta_erp/features/invoices/presentation/invoice_payment_display.dart';
import 'package:delta_erp/features/invoices/presentation/widgets/invoice_hub_list_card.dart';
import 'package:delta_erp/features/purchases/data/purchases_repository.dart';

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

  String _statusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'completed':
        return 'Completed'.tr();
      case 'partial':
        return 'Credit (no immediate payment)'.tr();
      case 'pending':
        return 'Pending'.tr();
      case 'cancelled':
        return 'Cancelled'.tr();
      default:
        return status;
    }
  }

  Color _statusColor(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status.trim().toLowerCase()) {
      case 'completed':
        return Colors.green.shade700;
      case 'partial':
        return Colors.orange.shade700;
      case 'pending':
        return scheme.primary;
      case 'cancelled':
        return scheme.error;
      default:
        return scheme.onSurfaceVariant;
    }
  }

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
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      itemCount: invoiceRows.length,
                      itemBuilder: (context, index) {
                        final row = invoiceRows[index];
                        final highlighted = row.id == activeInvoiceId;
                        final statusText = _statusLabel(row.status);
                        final statusColor = _statusColor(context, row.status);
                        final payLabel =
                            invoicePaymentMethodsDisplayLabel(
                              row.paymentMethod,
                            );
                        final invLabel = invoiceLabelBuilder(
                          id: row.id,
                          rawInvoiceNumber: row.invoiceNumber,
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: InvoiceHubListCard(
                            invoiceNumberDisplay: invLabel,
                            accountName: row.accountName,
                            totalAmount: row.totalAmount,
                            statusRaw: row.status,
                            statusLabel: statusText,
                            statusColor: statusColor,
                            paymentMethodRaw: row.paymentMethod,
                            paymentLabel: payLabel,
                            createdAt: row.createdAt,
                            highlighted: highlighted,
                            onTap: () => onSelectInvoice(row),
                            createdByLine: 'invoices.hub.created_by'.tr(
                              namedArgs: {'name': row.createdByDisplay},
                            ),
                            lastModifiedByLine:
                                row.lastModifiedByDisplay == null
                                ? null
                                : 'invoices.hub.last_modified_by'.tr(
                                    namedArgs: {
                                      'name': row.lastModifiedByDisplay!,
                                    },
                                  ),
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
