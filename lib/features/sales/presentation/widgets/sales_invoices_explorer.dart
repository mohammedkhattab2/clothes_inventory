import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:clothes_inventory/core/widgets/app_loading_indicator.dart';
import 'package:clothes_inventory/features/sales/data/sales_repository.dart';

enum SalesInvoiceTypeFilter { all, completed, credit, pending }

class SalesInvoicesExplorer extends StatelessWidget {
  const SalesInvoicesExplorer({
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
    required this.canCompletePendingSelected,
    required this.activeSaleItemId,
    required this.selectedTypeFilter,
    required this.invoiceTypeCounts,
    required this.invoicePage,
    required this.invoicePageSize,
    required this.onSelectInvoice,
    required this.onReturnSelected,
    required this.onCancelSelected,
    required this.onShowDetails,
    required this.onGeneratePdfSelected,
    required this.onCompletePendingSelected,
    required this.onTypeFilterChanged,
    required this.onPreviousPage,
    required this.onNextPage,
  });

  final DateTime? fromDate;
  final DateTime? toDate;
  final int? accountId;
  final int? categoryId;
  final bool loadingInvoices;
  final List<SalesInvoiceSummary> invoiceRows;
  final ScrollController invoiceScrollController;
  final int? activeInvoiceId;
  final String? activeInvoiceNumber;
  final bool canCompletePendingSelected;
  final int? activeSaleItemId;
  final SalesInvoiceTypeFilter selectedTypeFilter;
  final Map<SalesInvoiceTypeFilter, int> invoiceTypeCounts;
  final int invoicePage;
  final int invoicePageSize;
  final ValueChanged<SalesInvoiceSummary> onSelectInvoice;
  final VoidCallback onReturnSelected;
  final VoidCallback onCancelSelected;
  final VoidCallback onShowDetails;
  final VoidCallback onGeneratePdfSelected;
  final VoidCallback onCompletePendingSelected;
  final ValueChanged<SalesInvoiceTypeFilter> onTypeFilterChanged;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;

  String _filterLabel(SalesInvoiceTypeFilter filter) {
    final count = invoiceTypeCounts[filter] ?? 0;
    switch (filter) {
      case SalesInvoiceTypeFilter.all:
        return '${'All'.tr()} ($count)';
      case SalesInvoiceTypeFilter.completed:
        return '${'Completed'.tr()} ($count)';
      case SalesInvoiceTypeFilter.credit:
        return '${'Credit (no immediate payment)'.tr()} ($count)';
      case SalesInvoiceTypeFilter.pending:
        return '${'Pending'.tr()} ($count)';
    }
  }

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
              'Sales Invoices'.tr(),
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SalesInvoiceTypeFilter.values
                  .map(
                    (filter) => ChoiceChip(
                      label: Text(_filterLabel(filter)),
                      selected: selectedTypeFilter == filter,
                      onSelected: (_) => onTypeFilterChanged(filter),
                    ),
                  )
                  .toList(growable: false),
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
                        final statusText = _statusLabel(row.status);
                        final statusColor = _statusColor(context, row.status);
                        return Container(
                          color: highlighted
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                          child: ListTile(
                            dense: true,
                            onTap: () => onSelectInvoice(row),
                            title: Text(
                              '${row.invoiceNumber} • ${row.accountName}',
                            ),
                            subtitle: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  DateFormat(
                                    'yyyy-MM-dd HH:mm',
                                  ).format(row.createdAt),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: statusColor.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                    color: statusColor.withValues(alpha: 0.1),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: statusColor,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                                Text(row.totalAmount.toStringAsFixed(2)),
                              ],
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
                    onPressed: canCompletePendingSelected
                        ? onCompletePendingSelected
                        : null,
                    icon: const Icon(Icons.play_circle_outline),
                    label: Text('Complete Pending'.tr()),
                  ),
                  FilledButton.icon(
                    onPressed: activeInvoiceId == null
                        ? null
                        : onReturnSelected,
                    icon: const Icon(Icons.assignment_return_outlined),
                    label: Text('Return Selected'.tr()),
                  ),
                  FilledButton.icon(
                    onPressed: activeInvoiceId == null
                        ? null
                        : onCancelSelected,
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text('Cancel Selected'.tr()),
                  ),
                  OutlinedButton.icon(
                    onPressed: activeInvoiceId == null ? null : onShowDetails,
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: Text('Details'.tr()),
                  ),
                  OutlinedButton.icon(
                    onPressed: activeInvoiceId == null
                        ? null
                        : onGeneratePdfSelected,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: Text('PDF Selected'.tr()),
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
                    const SizedBox(width: 8),
                    Expanded(child: actionButtons[3]),
                    const SizedBox(width: 8),
                    Expanded(child: actionButtons[4]),
                  ],
                );
              },
            ),
            if (activeInvoiceId != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${'Selected'.tr()}: ${activeInvoiceNumber ?? '#$activeInvoiceId'}${activeSaleItemId == null ? '' : ' • ${'Item'.tr()} $activeSaleItemId'}',
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
