import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:clothes_inventory/core/config/company_settings_service.dart';
import 'package:clothes_inventory/core/widgets/app_empty_state.dart';
import 'package:clothes_inventory/features/invoices/domain/invoice_print_model.dart';
import 'package:clothes_inventory/features/sales/data/sales_repository.dart';
import 'package:clothes_inventory/features/sales/presentation/widgets/sales_invoice_details_header.dart';
import 'package:clothes_inventory/features/sales/presentation/widgets/sales_invoice_line_tile.dart';
import 'package:clothes_inventory/features/sales/presentation/widgets/sales_invoice_metric_card.dart';
import 'package:clothes_inventory/services/di/service_locator.dart';

class SalesInvoiceDetailsDialog extends StatefulWidget {
  const SalesInvoiceDetailsDialog({
    required this.invoiceId,
    required this.invoiceRows,
    required this.activeInvoiceLines,
    required this.activeInvoiceNumber,
    required this.activeSaleItemId,
    required this.dateFormat,
    required this.animateDialogEntrance,
    required this.loadInvoiceLines,
    required this.onSelectLine,
    required this.onPrintInvoice,
    required this.onApplyReturn,
    super.key,
  });

  final int invoiceId;
  final List<SalesInvoiceSummary> invoiceRows;
  final List<SalesInvoiceLine> activeInvoiceLines;
  final String? activeInvoiceNumber;
  final int? activeSaleItemId;
  final DateFormat dateFormat;

  final Widget Function(Widget child) animateDialogEntrance;
  final Future<List<SalesInvoiceLine>> Function(int invoiceId) loadInvoiceLines;
  final void Function(int lineId) onSelectLine;
  final Future<void> Function(InvoicePrintModel invoice) onPrintInvoice;
  final void Function(int saleItemId, double quantity) onApplyReturn;

  static Future<void> show(
    BuildContext context, {
    required int invoiceId,
    required List<SalesInvoiceSummary> invoiceRows,
    required List<SalesInvoiceLine> activeInvoiceLines,
    required String? activeInvoiceNumber,
    required int? activeSaleItemId,
    required DateFormat dateFormat,
    required Widget Function(Widget child) animateDialogEntrance,
    required Future<List<SalesInvoiceLine>> Function(int invoiceId)
    loadInvoiceLines,
    required void Function(int lineId) onSelectLine,
    required Future<void> Function(InvoicePrintModel invoice) onPrintInvoice,
    required void Function(int saleItemId, double quantity) onApplyReturn,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => SalesInvoiceDetailsDialog(
        invoiceId: invoiceId,
        invoiceRows: invoiceRows,
        activeInvoiceLines: activeInvoiceLines,
        activeInvoiceNumber: activeInvoiceNumber,
        activeSaleItemId: activeSaleItemId,
        dateFormat: dateFormat,
        animateDialogEntrance: animateDialogEntrance,
        loadInvoiceLines: loadInvoiceLines,
        onSelectLine: onSelectLine,
        onPrintInvoice: onPrintInvoice,
        onApplyReturn: onApplyReturn,
      ),
    );
  }

  @override
  State<SalesInvoiceDetailsDialog> createState() =>
      _SalesInvoiceDetailsDialogState();
}

class _SalesInvoiceDetailsDialogState extends State<SalesInvoiceDetailsDialog> {
  final ScrollController _dialogListController = ScrollController();

  SalesInvoiceSummary? _selectedInvoice;
  List<SalesInvoiceLine> _sortedLines = const [];
  SalesInvoiceLine? _selected;
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
    var lines = widget.activeInvoiceLines;
    if (lines.isEmpty) {
      lines = await widget.loadInvoiceLines(widget.invoiceId);
    }
    if (!mounted) return;
    setState(() {
      _sortedLines = [...lines]
        ..sort((a, b) => b.remainingQuantity.compareTo(a.remainingQuantity));
      _selected = _sortedLines.isEmpty ? null : _sortedLines.first;
      if (_selected != null && _selected!.remainingQuantity <= 0) {
        final firstAvailable = _sortedLines.where(
          (e) => e.remainingQuantity > 0,
        );
        if (firstAvailable.isNotEmpty) {
          _selected = firstAvailable.first;
        }
      }
    });
  }

  @override
  void dispose() {
    _dialogListController.dispose();
    super.dispose();
  }

  List<SalesInvoiceLine> _visibleLines() {
    return _showReturnableOnly
        ? _sortedLines.where((line) => line.remainingQuantity > 0).toList()
        : _sortedLines;
  }

  void _syncSelection(List<SalesInvoiceLine> linesForSelection) {
    final current = _selected;
    if (current == null ||
        !linesForSelection.any((line) => line.id == current.id)) {
      _selected = linesForSelection.isEmpty ? null : linesForSelection.first;
    }
    final selectedLine = _selected;
    if (selectedLine != null && widget.activeSaleItemId != selectedLine.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onSelectLine(selectedLine.id);
      });
    }
  }

  void _scrollSelectionIntoView(List<SalesInvoiceLine> linesForSelection) {
    final current = _selected;
    if (current == null) return;
    final index = linesForSelection.indexWhere((line) => line.id == current.id);
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

  String _buildSummaryText(
    double totalAmount,
    double paidAmount,
    double outstandingAmount,
    double paymentRatio,
    String paymentStatusLabel,
  ) {
    final invoiceNo =
        _selectedInvoice?.invoiceNumber ??
        (widget.activeInvoiceNumber ?? '#${widget.invoiceId}');
    final dateText = _selectedInvoice == null
        ? '-'
        : widget.dateFormat.format(_selectedInvoice!.createdAt);
    return '${'Invoice'.tr()}: $invoiceNo\n'
        '${'Customer'.tr()}: ${_selectedInvoice?.accountName ?? '-'}\n'
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
    final invoiceNo =
        _selectedInvoice?.invoiceNumber ??
        (widget.activeInvoiceNumber ?? '#${widget.invoiceId}');
    return InvoicePrintModel(
      companyName: company.name,
      address: company.address,
      phone: company.phonesText,
      invoiceNumber: invoiceNo,
      date: _selectedInvoice?.createdAt ?? DateTime.now(),
      customerName: _selectedInvoice?.accountName ?? 'Walk-in'.tr(),
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
      title: 'Sales Invoice'.tr(),
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
    final filteredLines = _visibleLines();
    _syncSelection(filteredLines);
    _scrollSelectionIntoView(filteredLines);

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SalesInvoiceDetailsHeader(
                  invoiceTitle:
                      _selectedInvoice?.invoiceNumber ??
                      (widget.activeInvoiceNumber ?? '#${widget.invoiceId}'),
                  accountName: _selectedInvoice?.accountName ?? '-',
                  paymentStatusLabel: paymentStatusLabel,
                  paymentStatusColor: paymentStatusColor,
                ),
                SizedBox(height: veryDense ? 8 : 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SalesInvoiceMetricCard(
                      label: 'Total'.tr(),
                      value: totalAmount.toStringAsFixed(2),
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                    SalesInvoiceMetricCard(
                      label: 'Paid amount'.tr(),
                      value: paidAmount.toStringAsFixed(2),
                      icon: Icons.payments_outlined,
                      tint: colorScheme.tertiary,
                    ),
                    SalesInvoiceMetricCard(
                      label: 'Outstanding'.tr(),
                      value: outstandingAmount.toStringAsFixed(2),
                      icon: Icons.pending_actions_outlined,
                      tint: colorScheme.primary,
                    ),
                    SalesInvoiceMetricCard(
                      label: 'Items Count'.tr(),
                      value: _sortedLines.length.toString(),
                      icon: Icons.inventory_2_outlined,
                      tint: colorScheme.secondary,
                    ),
                  ],
                ),
                SizedBox(height: veryDense ? 6 : 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
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
                    Text(
                      'Returnable $returnableCount/${_sortedLines.length}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    FilterChip(
                      selected: !_showReturnableOnly,
                      label: Text('All'.tr()),
                      onSelected: (_) =>
                          setState(() => _showReturnableOnly = false),
                    ),
                    FilterChip(
                      selected: _showReturnableOnly,
                      label: Text('Returnable Only'.tr()),
                      onSelected: (_) =>
                          setState(() => _showReturnableOnly = true),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _sortedLines.isEmpty
                      ? AppEmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'No line items found.'.tr(),
                          compact: true,
                        )
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                            color: colorScheme.surface,
                          ),
                          child: ListView.separated(
                            controller: _dialogListController,
                            itemCount: filteredLines.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final line = filteredLines[i];
                              final chosen = _selected?.id == line.id;

                              return SalesInvoiceLineTile(
                                line: line,
                                selected: chosen,
                                onTap: () {
                                  setState(() => _selected = line);
                                  widget.onSelectLine(line.id);
                                  _scrollSelectionIntoView(_visibleLines());
                                },
                              );
                            },
                          ),
                        ),
                ),
                SizedBox(height: veryDense ? 10 : 12),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
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
                              totalAmount,
                              paidAmount,
                              outstandingAmount,
                              paymentRatio,
                              paymentStatusLabel,
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
