import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:clothes_inventory/core/utils/translation_utils.dart';
import 'package:clothes_inventory/features/invoices/domain/invoice_suggestion.dart';
import 'package:clothes_inventory/features/sales/data/sales_repository.dart';
import 'package:clothes_inventory/features/sales/domain/sale_models.dart';
import 'package:clothes_inventory/features/sales/presentation/widgets/sales_return_dialog_actions.dart';
import 'package:clothes_inventory/features/sales/presentation/widgets/sales_return_dialog_header.dart';
import 'package:clothes_inventory/features/sales/presentation/widgets/sales_return_line_picker_card.dart';
import 'package:clothes_inventory/features/sales/presentation/widgets/sales_return_sale_id_section.dart';

class SalesReturnDialog extends StatefulWidget {
  const SalesReturnDialog({
    required this.parseFlexibleInt,
    required this.parseFlexibleNumber,
    required this.lookupSaleInvoiceSuggestion,
    required this.searchSaleInvoicesForReturn,
    required this.loadInvoiceLines,
    required this.onReturnSaleItem,
    required this.onRefreshInvoiceLines,
    required this.animateDialogEntrance,
    required this.activeInvoiceId,
    this.activeInvoiceDisplayNumber,
    required this.activeInvoiceLines,
    this.canAmendInvoiceForCart,
    this.onInvoiceAmendedInCart,
    this.initialSaleId,
    this.initialSaleItemId,
    this.initialQuantity,
    super.key,
  });

  /// When set and returns [true], the dialog shows “edit in cart”.
  final Future<bool> Function(int saleId)? canAmendInvoiceForCart;

  /// Invoked after the dialog is closed; loads the invoice into the cart.
  final Future<void> Function(int saleId)? onInvoiceAmendedInCart;

  final int? initialSaleId;
  final int? initialSaleItemId;
  final double? initialQuantity;
  final int? activeInvoiceId;
  final String? activeInvoiceDisplayNumber;
  final List<SalesInvoiceLine> activeInvoiceLines;

  final Future<InvoiceSuggestion?> Function(int saleId) lookupSaleInvoiceSuggestion;
  final Future<List<InvoiceSuggestion>> Function(String prefix)
      searchSaleInvoicesForReturn;

  final int? Function(String value) parseFlexibleInt;
  final double? Function(String value) parseFlexibleNumber;
  final Future<List<SalesInvoiceLine>> Function(int saleId) loadInvoiceLines;
  final Future<String?> Function({
    required int saleId,
    required int saleItemId,
    required double quantity,
    required PaymentMethod paymentMethod,
  })
  onReturnSaleItem;
  final Future<void> Function(int saleId, {int? preferredItemId})
  onRefreshInvoiceLines;
  final Widget Function(Widget child) animateDialogEntrance;

  static Future<void> show(
    BuildContext context, {
    required Future<InvoiceSuggestion?> Function(int saleId)
        lookupSaleInvoiceSuggestion,
    required Future<List<InvoiceSuggestion>> Function(String prefix)
        searchSaleInvoicesForReturn,
    required int? Function(String value) parseFlexibleInt,
    required double? Function(String value) parseFlexibleNumber,
    required Future<List<SalesInvoiceLine>> Function(int saleId)
    loadInvoiceLines,
    required Future<String?> Function({
      required int saleId,
      required int saleItemId,
      required double quantity,
      required PaymentMethod paymentMethod,
    })
    onReturnSaleItem,
    required Future<void> Function(int saleId, {int? preferredItemId})
    onRefreshInvoiceLines,
    required Widget Function(Widget child) animateDialogEntrance,
    required int? activeInvoiceId,
    String? activeInvoiceDisplayNumber,
    required List<SalesInvoiceLine> activeInvoiceLines,
    Future<bool> Function(int saleId)? canAmendInvoiceForCart,
    Future<void> Function(int saleId)? onInvoiceAmendedInCart,
    int? initialSaleId,
    int? initialSaleItemId,
    double? initialQuantity,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => SalesReturnDialog(
        parseFlexibleInt: parseFlexibleInt,
        parseFlexibleNumber: parseFlexibleNumber,
        lookupSaleInvoiceSuggestion: lookupSaleInvoiceSuggestion,
        searchSaleInvoicesForReturn: searchSaleInvoicesForReturn,
        loadInvoiceLines: loadInvoiceLines,
        onReturnSaleItem: onReturnSaleItem,
        onRefreshInvoiceLines: onRefreshInvoiceLines,
        animateDialogEntrance: animateDialogEntrance,
        activeInvoiceId: activeInvoiceId,
        activeInvoiceDisplayNumber: activeInvoiceDisplayNumber,
        activeInvoiceLines: activeInvoiceLines,
        canAmendInvoiceForCart: canAmendInvoiceForCart,
        onInvoiceAmendedInCart: onInvoiceAmendedInCart,
        initialSaleId: initialSaleId,
        initialSaleItemId: initialSaleItemId,
        initialQuantity: initialQuantity,
      ),
    );
  }

  @override
  State<SalesReturnDialog> createState() => _SalesReturnDialogState();
}

class _SalesReturnDialogState extends State<SalesReturnDialog> {
  late final TextEditingController _saleIdController;

  List<SalesInvoiceLine> _loadedInvoiceLines = const [];
  int? _loadedForSaleId;
  bool _loadingInvoiceItems = false;
  bool _attemptedInvoiceItemsLoad = false;
  String? _invoiceItemsLoadError;

  final Set<int> _selectedSaleItemIds = <int>{};
  final Map<int, String> _selectedQtyByItemId = <int, String>{};
  bool _submittingReturns = false;
  PaymentMethod _method = PaymentMethod.cash;

  bool _canAmendInCartCheck = false;
  bool _resolvingAmendEligibility = false;

  InvoiceSuggestion? _lockedSuggestion;

  int? _resolveSaleIdFromField() {
    final locked = _lockedSuggestion;
    final t = _saleIdController.text.trim();
    if (locked != null) {
      if (t == locked.invoiceNumber.trim()) {
        return locked.id;
      }
      final parsed = widget.parseFlexibleInt(t);
      if (parsed == locked.id) {
        return locked.id;
      }
    }
    return widget.parseFlexibleInt(t);
  }

  void _invalidateLockIfNeeded() {
    final locked = _lockedSuggestion;
    if (locked == null) return;
    final t = _saleIdController.text.trim();
    if (t.isEmpty) {
      setState(() => _lockedSuggestion = null);
      return;
    }
    if (t != locked.invoiceNumber.trim()) {
      final parsed = widget.parseFlexibleInt(t);
      if (parsed != locked.id) {
        setState(() => _lockedSuggestion = null);
      }
    }
  }

  Future<void> _refreshAmendEligibility(int saleId) async {
    final checker = widget.canAmendInvoiceForCart;
    if (checker == null) return;
    if (!mounted) return;
    setState(() {
      _resolvingAmendEligibility = true;
    });
    try {
      final ok = await checker(saleId);
      if (!mounted) return;
      setState(() {
        _canAmendInCartCheck = ok;
        _resolvingAmendEligibility = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _canAmendInCartCheck = false;
        _resolvingAmendEligibility = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    final resolvedInitialSaleId =
        widget.initialSaleId ?? widget.activeInvoiceId;
    _saleIdController = TextEditingController();

    if (resolvedInitialSaleId != null) {
      _prepareEntry(resolvedInitialSaleId);
    }
  }

  Future<void> _prepareEntry(int saleId) async {
    final suggestion = await widget.lookupSaleInvoiceSuggestion(saleId);
    if (!mounted) return;
    setState(() {
      if (suggestion != null) {
        _saleIdController.text = suggestion.invoiceNumber;
        _lockedSuggestion = suggestion;
      } else {
        _saleIdController.text = saleId.toString();
        _lockedSuggestion = null;
      }
    });
    await _primeInitialState(saleId);
  }

  Future<void> _primeInitialState(int? resolvedInitialSaleId) async {
    if (resolvedInitialSaleId == null) return;

    if (resolvedInitialSaleId == widget.activeInvoiceId) {
      _loadedInvoiceLines = widget.activeInvoiceLines;
      _loadedForSaleId = resolvedInitialSaleId;
      _syncSelectionForLines(_loadedInvoiceLines);
      if (_loadedInvoiceLines.isNotEmpty) {
        await _refreshAmendEligibility(resolvedInitialSaleId);
      }
      if (mounted) setState(() {});
      return;
    }

    _attemptedInvoiceItemsLoad = true;
    try {
      final fetched = await widget.loadInvoiceLines(resolvedInitialSaleId);
      if (!mounted) return;
      setState(() {
        _loadedInvoiceLines = fetched;
        _loadedForSaleId = resolvedInitialSaleId;
        _invoiceItemsLoadError = null;
        _syncSelectionForLines(fetched);
      });
      if (fetched.isNotEmpty) {
        await _refreshAmendEligibility(resolvedInitialSaleId);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadedInvoiceLines = const [];
        _loadedForSaleId = resolvedInitialSaleId;
        _invoiceItemsLoadError = 'Failed to load sale items.'.tr();
      });
    }
  }

  void _syncSelectionForLines(List<SalesInvoiceLine> lines) {
    final availableIds = lines.map((line) => line.id).toSet();
    _selectedSaleItemIds.removeWhere((id) => !availableIds.contains(id));
    _selectedQtyByItemId.removeWhere((id, _) => !availableIds.contains(id));

    if (_selectedSaleItemIds.isEmpty && lines.isNotEmpty) {
      SalesInvoiceLine? seeded;
      if (widget.initialSaleItemId != null) {
        for (final line in lines) {
          if (line.id == widget.initialSaleItemId) {
            seeded = line;
            break;
          }
        }
      }
      seeded ??= lines.first;
      _selectedSaleItemIds.add(seeded.id);
      _selectedQtyByItemId[seeded.id] = widget.initialQuantity == null
          ? seeded.remainingQuantity.toStringAsFixed(0)
          : widget.initialQuantity!.toStringAsFixed(0);
    }

    for (final line in lines) {
      if (!_selectedSaleItemIds.contains(line.id)) continue;
      _selectedQtyByItemId.putIfAbsent(
        line.id,
        () => line.remainingQuantity.toStringAsFixed(0),
      );
    }
  }

  Future<void> _loadItemsForSale(int id) async {
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
        _loadedForSaleId = id;
        _invoiceItemsLoadError = null;
        if (fetched.isEmpty) {
          _selectedSaleItemIds.clear();
          _selectedQtyByItemId.clear();
          _canAmendInCartCheck = false;
          return;
        }
        _syncSelectionForLines(fetched);
      });
      if (fetched.isNotEmpty) {
        await _refreshAmendEligibility(id);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingInvoiceItems = false;
        _loadedInvoiceLines = const [];
        _loadedForSaleId = id;
        _selectedSaleItemIds.clear();
        _selectedQtyByItemId.clear();
        _invoiceItemsLoadError = 'Failed to load sale items.'.tr();
        _canAmendInCartCheck = false;
      });
    }
  }

  String? _itemErrorFor(int lineId, double remainingQuantity) {
    if (!_selectedSaleItemIds.contains(lineId)) return null;
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
    _saleIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saleId = _resolveSaleIdFromField();
    final canUseInvoicePicker =
        saleId != null && saleId == widget.activeInvoiceId;

    final invoiceLinesForPicker = canUseInvoicePicker
        ? widget.activeInvoiceLines
        : ((saleId != null && saleId == _loadedForSaleId)
              ? _loadedInvoiceLines
              : const <SalesInvoiceLine>[]);

    _syncSelectionForLines(invoiceLinesForPicker);

    final selectedLines = invoiceLinesForPicker
        .where((line) => _selectedSaleItemIds.contains(line.id))
        .toList();
    final hasLineErrors = selectedLines.any(
      (line) => _itemErrorFor(line.id, line.remainingQuantity) != null,
    );

    final canSubmit =
        saleId != null &&
        selectedLines.isNotEmpty &&
        !_loadingInvoiceItems &&
        !_submittingReturns &&
        !hasLineErrors;

    final amendAvailable =
        widget.canAmendInvoiceForCart != null &&
        widget.onInvoiceAmendedInCart != null &&
        !_resolvingAmendEligibility &&
        !_loadingInvoiceItems;

    final canAmendLoaded =
        saleId != null &&
        invoiceLinesForPicker.isNotEmpty &&
        _canAmendInCartCheck;

    return widget.animateDialogEntrance(
      Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: (MediaQuery.sizeOf(context).width * 0.94).clamp(
              320.0,
              620.0,
            ),
            maxHeight: (MediaQuery.sizeOf(context).height * 0.9).clamp(
              360.0,
              760.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SalesReturnDialogHeader(
                  title: 'Sale Return (from original invoice)'.tr(),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SalesReturnSaleIdSection(
                          canUseInvoicePicker: canUseInvoicePicker,
                          activeInvoiceNumber:
                              widget.activeInvoiceDisplayNumber,
                          resolvedSaleId: saleId,
                          saleIdController: _saleIdController,
                          loadingInvoiceItems: _loadingInvoiceItems,
                          searchSuggestions: widget.searchSaleInvoicesForReturn,
                          onInvoiceQueryActivity: () {
                            _invalidateLockIfNeeded();
                            setState(() {
                              _selectedSaleItemIds.clear();
                              _selectedQtyByItemId.clear();
                              _invoiceItemsLoadError = null;
                            });
                          },
                          onSuggestionChosen: (suggestion) {
                            setState(() {
                              _lockedSuggestion = suggestion;
                              _selectedSaleItemIds.clear();
                              _selectedQtyByItemId.clear();
                              _invoiceItemsLoadError = null;
                            });
                          },
                          onLoadSaleItems: () => _loadItemsForSale(saleId!),
                        ),
                        if (invoiceLinesForPicker.isNotEmpty)
                          Column(
                            children: invoiceLinesForPicker.map((line) {
                              final isSelected = _selectedSaleItemIds.contains(
                                line.id,
                              );
                              final error = _itemErrorFor(
                                line.id,
                                line.remainingQuantity,
                              );
                              final qtyRaw =
                                  _selectedQtyByItemId[line.id] ?? '';

                              return SalesReturnLinePickerCard(
                                line: line,
                                isSelected: isSelected,
                                qtyRaw: qtyRaw,
                                error: error,
                                onSelectionChanged: (selectedValue) {
                                  if (selectedValue) {
                                    _selectedSaleItemIds.add(line.id);
                                    _selectedQtyByItemId.putIfAbsent(
                                      line.id,
                                      () => line.remainingQuantity
                                          .toStringAsFixed(0),
                                    );
                                  } else {
                                    _selectedSaleItemIds.remove(line.id);
                                    _selectedQtyByItemId.remove(line.id);
                                  }
                                  setState(() {});
                                },
                                onQuantityChanged: (value) {
                                  _selectedQtyByItemId[line.id] = value;
                                  setState(() {});
                                },
                                onUseRemaining: () {
                                  _selectedQtyByItemId[line.id] = line
                                      .remainingQuantity
                                      .toStringAsFixed(0);
                                  setState(() {});
                                },
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
                                'No items loaded for this sale.'.tr(),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<PaymentMethod>(
                          initialValue: _method,
                          decoration: InputDecoration(
                            labelText: 'Refund method'.tr(),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: PaymentMethod.cash,
                              child: Text('Cash'.tr()),
                            ),
                            DropdownMenuItem(
                              value: PaymentMethod.vodafoneCash,
                              child: Text('Vodafone Cash'.tr()),
                            ),
                            DropdownMenuItem(
                              value: PaymentMethod.visa,
                              child: Text('Visa'.tr()),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _method = value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SalesReturnDialogActions(
                  canSubmit: canSubmit,
                  submittingReturns: _submittingReturns,
                  showAmendInCart: amendAvailable,
                  canAmendInCart:
                      canAmendLoaded && !_submittingReturns,
                  onAmendInCart:
                      amendAvailable
                      ? () async {
                          final sid = saleId!;
                          Navigator.of(context).pop();
                          await widget.onInvoiceAmendedInCart?.call(sid);
                        }
                      : null,
                  onCancel: () => Navigator.of(context).pop(),
                  onApply: () async {
                    setState(() => _submittingReturns = true);
                    final selected = selectedLines
                        .where((line) => _selectedSaleItemIds.contains(line.id))
                        .toList();
                    for (final line in selected) {
                      final qty = widget.parseFlexibleNumber(
                        _selectedQtyByItemId[line.id] ?? '',
                      );
                      if (qty == null || qty <= 0) {
                        continue;
                      }
                      final error = await widget.onReturnSaleItem(
                        saleId: saleId!,
                        saleItemId: line.id,
                        quantity: qty,
                        paymentMethod: _method,
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
                    await widget.onRefreshInvoiceLines(
                      saleId!,
                      preferredItemId: selected.first.id,
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
