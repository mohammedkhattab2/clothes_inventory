import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:clothes_inventory/core/config/company_settings_service.dart';
import 'package:clothes_inventory/core/widgets/app_empty_state.dart';
import 'package:clothes_inventory/features/invoices/domain/invoice_print_model.dart';
import 'package:clothes_inventory/features/purchases/data/purchases_repository.dart';
import 'package:clothes_inventory/services/di/service_locator.dart';

class PurchasesInvoiceDetailsDialog extends StatefulWidget {
  const PurchasesInvoiceDetailsDialog({
    required this.invoiceId,
    required this.invoiceRows,
    required this.activeInvoiceNumber,
    required this.activePurchaseItemId,
    required this.dateFormat,
    required this.purchaseInvoiceLabel,
    required this.formatInvoiceQuantity,
    required this.animateDialogEntrance,
    required this.loadInvoiceLines,
    required this.onPrintInvoice,
    required this.onApplyReturn,
    super.key,
  });

  final int invoiceId;
  final List<PurchaseInvoiceSummary> invoiceRows;
  final String? activeInvoiceNumber;
  final int? activePurchaseItemId;
  final DateFormat dateFormat;
  final String Function({required int id, String? rawInvoiceNumber})
  purchaseInvoiceLabel;
  final String Function(double value) formatInvoiceQuantity;
  final Widget Function(Widget child) animateDialogEntrance;
  final Future<List<PurchaseInvoiceLine>> Function(int purchaseId)
  loadInvoiceLines;
  final Future<void> Function(InvoicePrintModel invoice) onPrintInvoice;
  final void Function(int purchaseItemId, double initialQuantity) onApplyReturn;

  static Future<void> show(
    BuildContext context, {
    required int invoiceId,
    required List<PurchaseInvoiceSummary> invoiceRows,
    required String? activeInvoiceNumber,
    required int? activePurchaseItemId,
    required DateFormat dateFormat,
    required String Function({required int id, String? rawInvoiceNumber})
    purchaseInvoiceLabel,
    required String Function(double value) formatInvoiceQuantity,
    required Widget Function(Widget child) animateDialogEntrance,
    required Future<List<PurchaseInvoiceLine>> Function(int purchaseId)
    loadInvoiceLines,
    required Future<void> Function(InvoicePrintModel invoice) onPrintInvoice,
    required void Function(int purchaseItemId, double initialQuantity)
    onApplyReturn,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => PurchasesInvoiceDetailsDialog(
        invoiceId: invoiceId,
        invoiceRows: invoiceRows,
        activeInvoiceNumber: activeInvoiceNumber,
        activePurchaseItemId: activePurchaseItemId,
        dateFormat: dateFormat,
        purchaseInvoiceLabel: purchaseInvoiceLabel,
        formatInvoiceQuantity: formatInvoiceQuantity,
        animateDialogEntrance: animateDialogEntrance,
        loadInvoiceLines: loadInvoiceLines,
        onPrintInvoice: onPrintInvoice,
        onApplyReturn: onApplyReturn,
      ),
    );
  }

  @override
  State<PurchasesInvoiceDetailsDialog> createState() =>
      _PurchasesInvoiceDetailsDialogState();
}

class _PurchasesInvoiceDetailsDialogState
    extends State<PurchasesInvoiceDetailsDialog> {
  final ScrollController _dialogListController = ScrollController();

  PurchaseInvoiceSummary? _selectedInvoice;
  List<PurchaseInvoiceLine> _sortedLines = const [];
  PurchaseInvoiceLine? _selected;
  bool _showReturnableOnly = false;

  @override
  void initState() {
    super.initState();
    for (final row in widget.invoiceRows) {
      if (row.id == widget.invoiceId) {
        _selectedInvoice = row;
        break;
      }
    }
    _loadLines();
  }

  Future<void> _loadLines() async {
    final lines = await widget.loadInvoiceLines(widget.invoiceId);
    if (!mounted) return;

    final sortedLines = [...lines]
      ..sort((a, b) => b.remainingQuantity.compareTo(a.remainingQuantity));

    PurchaseInvoiceLine? selected = sortedLines.isEmpty
        ? null
        : sortedLines.first;
    if (selected != null && selected.remainingQuantity <= 0) {
      final firstAvailable = sortedLines.where((e) => e.remainingQuantity > 0);
      if (firstAvailable.isNotEmpty) {
        selected = firstAvailable.first;
      }
    }

    setState(() {
      _sortedLines = sortedLines;
      _selected = selected;
    });
  }

  @override
  void dispose() {
    _dialogListController.dispose();
    super.dispose();
  }

  String _buildSummaryText({
    required double totalAmount,
    required double paidAmount,
    required double outstandingAmount,
    required double paymentRatio,
    required String paymentStatusLabel,
  }) {
    final invoiceNo = widget.purchaseInvoiceLabel(
      id: widget.invoiceId,
      rawInvoiceNumber: widget.activeInvoiceNumber,
    );
    final dateText = _selectedInvoice == null
        ? '-'
        : widget.dateFormat.format(_selectedInvoice!.createdAt);
    return '${'Invoice'.tr()}: $invoiceNo\n'
        '${'Supplier'.tr()}: ${_selectedInvoice?.accountName ?? '-'}\n'
        '${'Date'.tr()}: $dateText\n'
        '${'Status'.tr()}: ${_selectedInvoice?.status ?? '-'}\n'
        '${'Total'.tr()}: ${totalAmount.toStringAsFixed(2)}\n'
        '${'Paid amount'.tr()}: ${paidAmount.toStringAsFixed(2)}\n'
        '${'Outstanding'.tr()}: ${outstandingAmount.toStringAsFixed(2)}\n'
        '${'Payment Progress'.tr()}: ${(paymentRatio * 100).toStringAsFixed(0)}%\n'
        '${'Payment Status'.tr()}: $paymentStatusLabel\n'
        '${'Items Count'.tr()}: ${_sortedLines.length}';
  }

  InvoicePrintModel _buildInvoicePrintModel(double totalAmount) {
    final company = getIt<CompanySettingsService>().settings;
    final invoiceNo = widget.purchaseInvoiceLabel(
      id: widget.invoiceId,
      rawInvoiceNumber: widget.activeInvoiceNumber,
    );
    return InvoicePrintModel(
      companyName: company.name,
      address: company.address,
      phone: company.phonesText,
      invoiceNumber: invoiceNo,
      date: _selectedInvoice?.createdAt ?? DateTime.now(),
      customerName: _selectedInvoice?.accountName ?? '-',
      items: _sortedLines
          .map(
            (line) => InvoiceItem(
              productName: line.productName,
              quantity: line.quantity,
              unitPrice: line.unitPrice,
            ),
          )
          .toList(growable: false),
      total: totalAmount,
      title: 'Purchase Invoice'.tr(),
    );
  }

  Widget _summaryCard({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    Color? tint,
  }) {
    final cardColor = tint ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: 156,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cardColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final veryDense = MediaQuery.sizeOf(context).height < 720;
    final paidAmount = _selectedInvoice?.paidAmount ?? 0;
    final totalAmount =
        _selectedInvoice?.totalAmount ??
        _sortedLines.fold<double>(0, (sum, line) => sum + line.lineTotal);
    final outstandingAmount =
        _selectedInvoice?.outstandingAmount ??
        (totalAmount - paidAmount).clamp(0, double.infinity);
    final paymentRatio = totalAmount <= 0
        ? 0.0
        : (paidAmount / totalAmount).clamp(0, 1).toDouble();
    final paymentStatusLabel = paymentRatio >= 0.999
        ? 'Full Payment'.tr()
        : (paymentRatio <= 0.001 ? 'Unpaid'.tr() : 'Partial Payment'.tr());
    final paymentStatusColor = paymentRatio >= 0.999
        ? colorScheme.tertiary
        : (paymentRatio <= 0.001 ? colorScheme.error : colorScheme.primary);

    final returnableCount = _sortedLines
        .where((line) => line.remainingQuantity > 0)
        .length;

    List<PurchaseInvoiceLine> visibleLines() => _showReturnableOnly
        ? _sortedLines.where((line) => line.remainingQuantity > 0).toList()
        : _sortedLines;

    void syncSelection(List<PurchaseInvoiceLine> linesForSelection) {
      final current = _selected;
      if (current == null ||
          !linesForSelection.any((line) => line.id == current.id)) {
        _selected = linesForSelection.isEmpty ? null : linesForSelection.first;
      }
    }

    void scrollSelectionIntoView(List<PurchaseInvoiceLine> linesForSelection) {
      final current = _selected;
      if (current == null) return;
      final index = linesForSelection.indexWhere(
        (line) => line.id == current.id,
      );
      if (index < 0) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_dialogListController.hasClients) return;
        const estimatedRowHeight = 72.0;
        final max = _dialogListController.position.maxScrollExtent;
        final offset = (index * estimatedRowHeight).clamp(0, max).toDouble();
        _dialogListController.animateTo(
          offset,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      });
    }

    final filteredLines = visibleLines();
    final totalPurchasedQty = _sortedLines.fold<double>(
      0,
      (sum, line) => sum + line.quantity,
    );
    final totalReturnedQty = _sortedLines.fold<double>(
      0,
      (sum, line) => sum + line.returnedQuantity,
    );
    final totalRemainingQty = _sortedLines.fold<double>(
      0,
      (sum, line) => sum + line.remainingQuantity,
    );
    syncSelection(filteredLines);
    scrollSelectionIntoView(filteredLines);

    return widget.animateDialogEntrance(
      Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: (MediaQuery.sizeOf(context).width * 0.94).clamp(
              320.0,
              760.0,
            ),
            maxHeight: (MediaQuery.sizeOf(context).height * 0.88).clamp(
              360.0,
              760.0,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(veryDense ? 12 : 16),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primaryContainer.withValues(alpha: 0.9),
                        colorScheme.secondaryContainer.withValues(alpha: 0.72),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Invoice Details'.tr(),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                            ),
                            Text(
                              '${widget.purchaseInvoiceLabel(id: widget.invoiceId, rawInvoiceNumber: widget.activeInvoiceNumber)} • ${_selectedInvoice?.accountName ?? '-'}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onPrimaryContainer
                                        .withValues(alpha: 0.88),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: paymentStatusColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: paymentStatusColor.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          paymentStatusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: paymentStatusColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: veryDense ? 8 : 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _summaryCard(
                      context: context,
                      label: 'Total'.tr(),
                      value: totalAmount.toStringAsFixed(2),
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                    _summaryCard(
                      context: context,
                      label: 'Paid amount'.tr(),
                      value: paidAmount.toStringAsFixed(2),
                      icon: Icons.payments_outlined,
                      tint: colorScheme.tertiary,
                    ),
                    _summaryCard(
                      context: context,
                      label: 'Outstanding'.tr(),
                      value: outstandingAmount.toStringAsFixed(2),
                      icon: Icons.pending_actions_outlined,
                      tint: colorScheme.primary,
                    ),
                    _summaryCard(
                      context: context,
                      label: 'Items Count'.tr(),
                      value: _sortedLines.length.toString(),
                      icon: Icons.inventory_2_outlined,
                      tint: colorScheme.secondary,
                    ),
                  ],
                ),
                SizedBox(height: veryDense ? 6 : 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    Text(
                      '${'Date'.tr()}: ${_selectedInvoice == null ? '-' : widget.dateFormat.format(_selectedInvoice!.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '${'Status'.tr()}: ${_selectedInvoice?.status ?? '-'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '${'Payment Progress'.tr()}: ${(paymentRatio * 100).toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                SizedBox(height: veryDense ? 10 : 12),
                Expanded(
                  child: SizedBox(
                    width: double.infinity,
                    child: _sortedLines.isEmpty
                        ? AppEmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: 'No line items found.'.tr(),
                            compact: true,
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  Text(
                                    '${'Purchased Quantity'.tr()}: ${widget.formatInvoiceQuantity(totalPurchasedQty)}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  Text(
                                    '${'Return'.tr()}: ${widget.formatInvoiceQuantity(totalReturnedQty)}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  Text(
                                    '${'Outstanding'.tr()}: ${widget.formatInvoiceQuantity(totalRemainingQty)}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'Returnable $returnableCount/${_sortedLines.length}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  FilterChip(
                                    selected: !_showReturnableOnly,
                                    label: Text('All'.tr()),
                                    onSelected: (_) => setState(
                                      () => _showReturnableOnly = false,
                                    ),
                                  ),
                                  FilterChip(
                                    selected: _showReturnableOnly,
                                    label: Text('Returnable Only'.tr()),
                                    onSelected: (_) => setState(
                                      () => _showReturnableOnly = true,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: ListView.separated(
                                  controller: _dialogListController,
                                  itemCount: filteredLines.length,
                                  separatorBuilder: (_, _) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, i) {
                                    final line = filteredLines[i];
                                    final chosen = _selected?.id == line.id;

                                    final statusColor =
                                        line.remainingQuantity <= 0
                                        ? colorScheme.onSurfaceVariant
                                        : (line.returnedQuantity > 0
                                              ? colorScheme.primary
                                              : colorScheme.tertiary);
                                    final statusLabel =
                                        line.remainingQuantity <= 0
                                        ? 'Fully Returned'.tr()
                                        : (line.returnedQuantity > 0
                                              ? 'Partial Return'.tr()
                                              : 'Open'.tr());
                                    final statusIcon =
                                        line.remainingQuantity <= 0
                                        ? Icons.block_outlined
                                        : (line.returnedQuantity > 0
                                              ? Icons.change_circle_outlined
                                              : Icons.check_circle_outline);

                                    return ListTile(
                                      selected: chosen,
                                      selectedTileColor: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                          .withValues(alpha: 0.45),
                                      leading: Icon(
                                        chosen
                                            ? Icons.radio_button_checked
                                            : statusIcon,
                                        size: 18,
                                        color: chosen
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : statusColor,
                                      ),
                                      title: Text(line.productName),
                                      subtitle: Text(
                                        '${'Item'.tr()} ${line.id}\n'
                                        '${'Purchased Quantity'.tr()}: ${widget.formatInvoiceQuantity(line.quantity)} • '
                                        '${'Return'.tr()}: ${widget.formatInvoiceQuantity(line.returnedQuantity)} • '
                                        '${'Outstanding'.tr()}: ${widget.formatInvoiceQuantity(line.remainingQuantity)}\n'
                                        '${'Line Total'.tr()}: ${line.lineTotal.toStringAsFixed(2)}',
                                      ),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color: statusColor.withValues(
                                              alpha: 0.35,
                                            ),
                                          ),
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
                                      onTap: () {
                                        setState(() => _selected = line);
                                        scrollSelectionIntoView(visibleLines());
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                SizedBox(height: veryDense ? 10 : 12),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final invoice = _buildInvoicePrintModel(totalAmount);
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          await widget.onPrintInvoice(invoice);
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${'Printing failed.'.tr()}: $e'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.print_outlined),
                      label: Text('Print Invoice'.tr()),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(
                            text: _buildSummaryText(
                              totalAmount: totalAmount,
                              paidAmount: paidAmount,
                              outstandingAmount: outstandingAmount,
                              paymentRatio: paymentRatio,
                              paymentStatusLabel: paymentStatusLabel,
                            ),
                          ),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Invoice summary copied.'.tr()),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_all_outlined),
                      label: Text('Copy Invoice Summary'.tr()),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Close'.tr()),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        final line = _selected;
                        if (line == null || line.remainingQuantity <= 0) {
                          return;
                        }
                        Navigator.of(context).pop();
                        widget.onApplyReturn(line.id, line.remainingQuantity);
                      },
                      icon: const Icon(Icons.assignment_return_outlined),
                      label: Text('Apply Return'.tr()),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
