import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:clothes_inventory/core/utils/translation_utils.dart';
import 'package:flutter/services.dart';
import 'package:clothes_inventory/features/purchases/data/purchases_repository.dart';

class PurchasesReturnDialog extends StatefulWidget {
  const PurchasesReturnDialog({
    required this.parseFlexibleInt,
    required this.parseFlexibleNumber,
    required this.formatInvoiceQuantity,
    required this.animateDialogEntrance,
    required this.loadInvoiceLines,
    required this.onReturnPurchaseItem,
    required this.onRefreshActiveInvoiceLines,
    required this.activeInvoiceId,
    required this.activeInvoiceLines,
    this.initialPurchaseId,
    this.initialPurchaseItemId,
    this.initialQuantity,
    super.key,
  });

  final int? initialPurchaseId;
  final int? initialPurchaseItemId;
  final double? initialQuantity;
  final int? activeInvoiceId;
  final List<PurchaseInvoiceLine> activeInvoiceLines;

  final int? Function(String value) parseFlexibleInt;
  final double? Function(String value) parseFlexibleNumber;
  final String Function(double value) formatInvoiceQuantity;
  final Widget Function(Widget child) animateDialogEntrance;

  final Future<List<PurchaseInvoiceLine>> Function(int purchaseId)
  loadInvoiceLines;

  final Future<String?> Function({
    required int purchaseId,
    required int purchaseItemId,
    required double quantity,
  })
  onReturnPurchaseItem;

  final Future<void> Function(int purchaseId, {int? preferredItemId})
  onRefreshActiveInvoiceLines;

  static Future<void> show(
    BuildContext context, {
    int? initialPurchaseId,
    int? initialPurchaseItemId,
    double? initialQuantity,
    required int? activeInvoiceId,
    required List<PurchaseInvoiceLine> activeInvoiceLines,
    required int? Function(String value) parseFlexibleInt,
    required double? Function(String value) parseFlexibleNumber,
    required String Function(double value) formatInvoiceQuantity,
    required Widget Function(Widget child) animateDialogEntrance,
    required Future<List<PurchaseInvoiceLine>> Function(int purchaseId)
    loadInvoiceLines,
    required Future<String?> Function({
      required int purchaseId,
      required int purchaseItemId,
      required double quantity,
    })
    onReturnPurchaseItem,
    required Future<void> Function(int purchaseId, {int? preferredItemId})
    onRefreshActiveInvoiceLines,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => PurchasesReturnDialog(
        initialPurchaseId: initialPurchaseId,
        initialPurchaseItemId: initialPurchaseItemId,
        initialQuantity: initialQuantity,
        activeInvoiceId: activeInvoiceId,
        activeInvoiceLines: activeInvoiceLines,
        parseFlexibleInt: parseFlexibleInt,
        parseFlexibleNumber: parseFlexibleNumber,
        formatInvoiceQuantity: formatInvoiceQuantity,
        animateDialogEntrance: animateDialogEntrance,
        loadInvoiceLines: loadInvoiceLines,
        onReturnPurchaseItem: onReturnPurchaseItem,
        onRefreshActiveInvoiceLines: onRefreshActiveInvoiceLines,
      ),
    );
  }

  @override
  State<PurchasesReturnDialog> createState() => _PurchasesReturnDialogState();
}

class _PurchasesReturnDialogState extends State<PurchasesReturnDialog> {
  late final TextEditingController _purchaseIdController;

  List<PurchaseInvoiceLine> _loadedInvoiceLines = const [];
  int? _loadedForPurchaseId;
  bool _loadingInvoiceItems = false;
  bool _attemptedInvoiceItemsLoad = false;
  String? _invoiceItemsLoadError;

  final Set<int> _selectedPurchaseItemIds = <int>{};
  final Map<int, String> _selectedQtyByItemId = <int, String>{};
  bool _submittingReturns = false;

  @override
  void initState() {
    super.initState();
    final resolvedInitialPurchaseId =
        widget.initialPurchaseId ?? widget.activeInvoiceId;
    _purchaseIdController = TextEditingController(
      text: resolvedInitialPurchaseId?.toString() ?? '',
    );
    _primeInitialState(resolvedInitialPurchaseId);
  }

  Future<void> _primeInitialState(int? resolvedInitialPurchaseId) async {
    if (resolvedInitialPurchaseId == null) return;

    if (resolvedInitialPurchaseId == widget.activeInvoiceId) {
      _loadedInvoiceLines = widget.activeInvoiceLines;
      _loadedForPurchaseId = resolvedInitialPurchaseId;
      _syncSelectionForLines(_loadedInvoiceLines);
      if (mounted) setState(() {});
      return;
    }

    _attemptedInvoiceItemsLoad = true;
    try {
      final fetched = await widget.loadInvoiceLines(resolvedInitialPurchaseId);
      if (!mounted) return;
      setState(() {
        _loadedInvoiceLines = fetched;
        _loadedForPurchaseId = resolvedInitialPurchaseId;
        _invoiceItemsLoadError = null;
        _syncSelectionForLines(fetched);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadedInvoiceLines = const [];
        _loadedForPurchaseId = resolvedInitialPurchaseId;
        _invoiceItemsLoadError = 'Failed to load purchase items.'.tr();
      });
    }
  }

  void _syncSelectionForLines(List<PurchaseInvoiceLine> lines) {
    final availableIds = lines.map((line) => line.id).toSet();
    _selectedPurchaseItemIds.removeWhere((id) => !availableIds.contains(id));
    _selectedQtyByItemId.removeWhere((id, _) => !availableIds.contains(id));

    if (_selectedPurchaseItemIds.isEmpty && lines.isNotEmpty) {
      PurchaseInvoiceLine? seeded;
      if (widget.initialPurchaseItemId != null) {
        for (final line in lines) {
          if (line.id == widget.initialPurchaseItemId) {
            seeded = line;
            break;
          }
        }
      }
      seeded ??= lines.first;
      _selectedPurchaseItemIds.add(seeded.id);
      _selectedQtyByItemId[seeded.id] = widget.initialQuantity == null
          ? widget.formatInvoiceQuantity(seeded.remainingQuantity)
          : widget.formatInvoiceQuantity(widget.initialQuantity!);
    }

    for (final line in lines) {
      if (!_selectedPurchaseItemIds.contains(line.id)) continue;
      _selectedQtyByItemId.putIfAbsent(
        line.id,
        () => widget.formatInvoiceQuantity(line.remainingQuantity),
      );
    }
  }

  Future<void> _loadItemsForPurchase(int id) async {
    setState(() {
      _loadingInvoiceItems = true;
      _attemptedInvoiceItemsLoad = true;
      _invoiceItemsLoadError = null;
    });

    try {
      final fetched = await widget.loadInvoiceLines(id);
      if (!mounted) return;
      setState(() {
        _loadingInvoiceItems = false;
        _loadedInvoiceLines = fetched;
        _loadedForPurchaseId = id;
        _invoiceItemsLoadError = null;
        if (fetched.isEmpty) {
          _selectedPurchaseItemIds.clear();
          _selectedQtyByItemId.clear();
          return;
        }
        _syncSelectionForLines(fetched);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingInvoiceItems = false;
        _loadedInvoiceLines = const [];
        _loadedForPurchaseId = id;
        _selectedPurchaseItemIds.clear();
        _selectedQtyByItemId.clear();
        _invoiceItemsLoadError = 'Failed to load purchase items.'.tr();
      });
    }
  }

  String? _itemErrorFor(int lineId, double remainingQuantity) {
    if (!_selectedPurchaseItemIds.contains(lineId)) return null;
    final qtyRaw = _selectedQtyByItemId[lineId] ?? '';
    final qty = widget.parseFlexibleNumber(qtyRaw);
    if (qty == null || qty <= 0) {
      return 'Quantity must be greater than zero'.tr();
    }
    if (qty - remainingQuantity > 0.000001) {
      return 'Return quantity exceeds remaining quantity.'.tr();
    }
    return null;
  }

  @override
  void dispose() {
    _purchaseIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final veryDense = MediaQuery.sizeOf(context).height < 720;
    final purchaseId = widget.parseFlexibleInt(_purchaseIdController.text);
    final canUseInvoicePicker =
        purchaseId != null && purchaseId == widget.activeInvoiceId;

    final invoiceLinesForPicker = canUseInvoicePicker
        ? widget.activeInvoiceLines
        : ((purchaseId != null && purchaseId == _loadedForPurchaseId)
              ? _loadedInvoiceLines
              : const <PurchaseInvoiceLine>[]);

    _syncSelectionForLines(invoiceLinesForPicker);

    final selectedLines = invoiceLinesForPicker
        .where((line) => _selectedPurchaseItemIds.contains(line.id))
        .toList();
    final hasLineErrors = selectedLines.any(
      (line) => _itemErrorFor(line.id, line.remainingQuantity) != null,
    );

    final canSubmit =
        purchaseId != null &&
        selectedLines.isNotEmpty &&
        !_loadingInvoiceItems &&
        !_submittingReturns &&
        !hasLineErrors;

    return widget.animateDialogEntrance(
      Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: (MediaQuery.sizeOf(context).width * 0.94).clamp(
              320.0,
              680.0,
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
                        colorScheme.tertiaryContainer.withValues(alpha: 0.7),
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
                        Icons.assignment_return_outlined,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Purchase Return (from original invoice)'.tr(),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                            ),
                            if (purchaseId != null)
                              Text(
                                '${'Purchase ID'.tr()}: $purchaseId',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onPrimaryContainer
                                          .withValues(alpha: 0.88),
                                    ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: veryDense ? 8 : 10),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (canUseInvoicePicker)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            child: Text(
                              '${'Purchase ID'.tr()}: $purchaseId',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          )
                        else ...[
                          TextField(
                            controller: _purchaseIdController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9٠-٩]'),
                              ),
                            ],
                            onTap: () {
                              _purchaseIdController.selection = TextSelection(
                                baseOffset: 0,
                                extentOffset: _purchaseIdController.text.length,
                              );
                            },
                            decoration: InputDecoration(
                              labelText: 'Purchase ID'.tr(),
                            ),
                            onChanged: (_) {
                              setState(() {
                                _selectedPurchaseItemIds.clear();
                                _selectedQtyByItemId.clear();
                                _invoiceItemsLoadError = null;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed:
                                  purchaseId == null || _loadingInvoiceItems
                                  ? null
                                  : () => _loadItemsForPurchase(purchaseId),
                              icon: _loadingInvoiceItems
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.sync_outlined),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              label: Text('Load Purchase Items'.tr()),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (invoiceLinesForPicker.isNotEmpty)
                          Column(
                            children: invoiceLinesForPicker.map((line) {
                              final isSelected = _selectedPurchaseItemIds
                                  .contains(line.id);
                              final qtyRaw =
                                  _selectedQtyByItemId[line.id] ?? '';
                              final error = _itemErrorFor(
                                line.id,
                                line.remainingQuantity,
                              );

                              return Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: colorScheme.outlineVariant,
                                  ),
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
                                              : (value) {
                                                  final selected =
                                                      value ?? false;
                                                  if (selected) {
                                                    _selectedPurchaseItemIds
                                                        .add(line.id);
                                                    _selectedQtyByItemId.putIfAbsent(
                                                      line.id,
                                                      () => widget
                                                          .formatInvoiceQuantity(
                                                            line.remainingQuantity,
                                                          ),
                                                    );
                                                  } else {
                                                    _selectedPurchaseItemIds
                                                        .remove(line.id);
                                                    _selectedQtyByItemId.remove(
                                                      line.id,
                                                    );
                                                  }
                                                  setState(() {});
                                                },
                                        ),
                                        Expanded(
                                          child: Text(
                                            '${line.productName} • ${'Purchased Quantity'.tr()}: ${widget.formatInvoiceQuantity(line.quantity)} • ${'Return'.tr()}: ${widget.formatInvoiceQuantity(line.returnedQuantity)} • ${'Outstanding'.tr()}: ${widget.formatInvoiceQuantity(line.remainingQuantity)}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ),
                                      ],
                                    ),
                                    TextField(
                                      enabled: isSelected,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'[0-9٠-٩.,٫٬]'),
                                        ),
                                      ],
                                      controller:
                                          TextEditingController(text: qtyRaw)
                                            ..selection =
                                                TextSelection.collapsed(
                                                  offset: qtyRaw.length,
                                                ),
                                      decoration: InputDecoration(
                                        labelText: 'Return Quantity'.tr(),
                                        helperText:
                                            '${'Outstanding'.tr()}: ${widget.formatInvoiceQuantity(line.remainingQuantity)}',
                                        errorText: isSelected ? error : null,
                                      ),
                                      onChanged: (value) {
                                        _selectedQtyByItemId[line.id] = value;
                                        setState(() {});
                                      },
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: isSelected
                                            ? () {
                                                _selectedQtyByItemId[line
                                                    .id] = widget
                                                    .formatInvoiceQuantity(
                                                      line.remainingQuantity,
                                                    );
                                                setState(() {});
                                              }
                                            : null,
                                        icon: const Icon(
                                          Icons.auto_fix_high_outlined,
                                        ),
                                        label: Text('Use Remaining'.tr()),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          )
                        else if (_invoiceItemsLoadError != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                _invoiceItemsLoadError!,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                              ),
                            ),
                          )
                        else if (!_loadingInvoiceItems &&
                            _attemptedInvoiceItemsLoad)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'No items loaded for this purchase.'.tr(),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
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
                  runSpacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_outlined),
                      label: Text('Cancel'.tr()),
                    ),
                    FilledButton.icon(
                      onPressed: canSubmit
                          ? () async {
                              setState(() => _submittingReturns = true);
                              final selected = selectedLines
                                  .where(
                                    (line) => _selectedPurchaseItemIds.contains(
                                      line.id,
                                    ),
                                  )
                                  .toList();
                              for (final line in selected) {
                                final qty = widget.parseFlexibleNumber(
                                  _selectedQtyByItemId[line.id] ?? '',
                                );
                                if (qty == null || qty <= 0) {
                                  continue;
                                }
                                final error = await widget.onReturnPurchaseItem(
                                  purchaseId: purchaseId,
                                  purchaseItemId: line.id,
                                  quantity: qty,
                                );
                                if (error != null) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          trIfExists(error, context: context),
                                        ),
                                      ),
                                    );
                                  }
                                  setState(() => _submittingReturns = false);
                                  return;
                                }
                              }
                              await widget.onRefreshActiveInvoiceLines(
                                purchaseId,
                                preferredItemId: selected.first.id,
                              );
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            }
                          : null,
                      icon: const Icon(Icons.assignment_return_outlined),
                      label: Text(
                        _submittingReturns
                            ? 'Applying...'.tr()
                            : 'Apply Return'.tr(),
                      ),
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
