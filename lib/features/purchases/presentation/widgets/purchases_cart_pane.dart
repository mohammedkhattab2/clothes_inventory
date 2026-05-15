import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:clothes_inventory/features/accounts/data/accounts_repository.dart';
import 'package:clothes_inventory/features/sales/domain/sale_models.dart';

class PurchasesCartPane extends StatelessWidget {
  const PurchasesCartPane({
    super.key,
    required this.total,
    required this.loading,
    required this.paymentStatusIndex,
    required this.paymentStatusItems,
    required this.cartContent,
    required this.suppliers,
    required this.supplierId,
    required this.headerDiscountKind,
    required this.headerDiscountValueController,
    required this.paidController,
    required this.paidAmountFocusNode,
    required this.headerDiscountAmount,
    required this.outstandingAmount,
    required this.paymentMethod,
    required this.paidFieldEnabled,
    required this.onAddSupplier,
    required this.onSupplierChanged,
    required this.onPaymentStatusChanged,
    required this.onHeaderDiscountKindChanged,
    required this.onHeaderDiscountValueChanged,
    required this.onPaidChanged,
    required this.onPaymentMethodChanged,
    required this.onCompletePurchase,
    required this.onReturnFromInvoice,
    required this.onCancelInvoice,
    required this.readOnlyMode,
    this.readOnlyMessage,
  });

  final double total;
  final bool loading;
  final int paymentStatusIndex;
  final List<DropdownMenuItem<int>> paymentStatusItems;
  final Widget cartContent;
  final List<AccountLookup> suppliers;
  final int? supplierId;
  final InvoiceHeaderDiscountKind headerDiscountKind;
  final TextEditingController headerDiscountValueController;
  final TextEditingController paidController;
  final FocusNode paidAmountFocusNode;
  final double headerDiscountAmount;
  final double outstandingAmount;
  final PaymentMethod paymentMethod;
  final bool paidFieldEnabled;
  final VoidCallback onAddSupplier;
  final ValueChanged<int?> onSupplierChanged;
  final ValueChanged<int?> onPaymentStatusChanged;
  final ValueChanged<InvoiceHeaderDiscountKind> onHeaderDiscountKindChanged;
  final ValueChanged<String> onHeaderDiscountValueChanged;
  final ValueChanged<String>? onPaidChanged;
  final ValueChanged<PaymentMethod> onPaymentMethodChanged;
  final VoidCallback onCompletePurchase;
  final VoidCallback onReturnFromInvoice;
  final VoidCallback onCancelInvoice;
  final bool readOnlyMode;
  final String? readOnlyMessage;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final veryDense = MediaQuery.sizeOf(context).height < 720;

    final compactGap = veryDense ? 6.0 : 8.0;
    final sectionGap = veryDense ? 8.0 : 10.0;
    const panelDuration = Duration(milliseconds: 220);
    return Card(
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(veryDense ? 10 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primaryContainer,
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    size: 18,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Cart'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${'Total after discount'.tr()}: ${total.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: compactGap),
            if (readOnlyMode)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade300),
                  color: Colors.orange.shade50,
                ),
                child: Text(
                  readOnlyMessage ?? 'license.read_only_banner'.tr(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Expanded(
              child: AnimatedContainer(
                duration: panelDuration,
                curve: Curves.easeOutCubic,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: readOnlyMode
                        ? colorScheme.outlineVariant
                        : colorScheme.primary.withValues(alpha: 0.32),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colorScheme.surface,
                      colorScheme.surfaceContainerLowest,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(
                        alpha: readOnlyMode ? 0.0 : 0.08,
                      ),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(8),
                child: cartContent,
              ),
            ),
            SizedBox(height: sectionGap),
            AnimatedContainer(
              duration: panelDuration,
              curve: Curves.easeOutCubic,
              width: double.infinity,
              padding: EdgeInsets.all(veryDense ? 10 : 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: outstandingAmount > 0
                      ? colorScheme.primary.withValues(alpha: 0.35)
                      : colorScheme.outlineVariant,
                ),
                color: outstandingAmount > 0
                    ? colorScheme.primaryContainer.withValues(alpha: 0.18)
                    : colorScheme.surface,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: paidController,
                    focusNode: paidAmountFocusNode,
                    enabled: paidFieldEnabled,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9٠-٩.,٫٬]'),
                      ),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Paid amount'.tr(),
                      hintText: '0',
                    ),
                    onChanged: onPaidChanged,
                  ),
                  SizedBox(height: compactGap),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${'Outstanding'.tr()}: ${outstandingAmount.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(height: compactGap),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: loading || readOnlyMode
                          ? null
                          : onCompletePurchase,
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(
                        loading ? 'Saving...'.tr() : 'Complete Purchase'.tr(),
                      ),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: veryDense ? 10 : 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: compactGap),
            _AnimatedAdvancedSection(
              title: 'Advanced options'.tr(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: PurchasesSupplierAutocomplete(
                          suppliers: suppliers,
                          supplierId: supplierId,
                          onSupplierSelected: onSupplierChanged,
                        ),
                      ),
                      SizedBox(width: compactGap),
                      OutlinedButton.icon(
                        onPressed: onAddSupplier,
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: Text('Add Supplier'.tr()),
                      ),
                    ],
                  ),
                  SizedBox(height: compactGap),
                  DropdownButtonFormField<int>(
                    initialValue: paymentStatusIndex,
                    decoration: InputDecoration(
                      labelText: 'Payment Status'.tr(),
                    ),
                    items: paymentStatusItems,
                    onChanged: onPaymentStatusChanged,
                  ),
                  SizedBox(height: compactGap),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<InvoiceHeaderDiscountKind>(
                          key: ValueKey(headerDiscountKind),
                          initialValue: headerDiscountKind,
                          decoration: InputDecoration(
                            labelText: 'Invoice discount type'.tr(),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: InvoiceHeaderDiscountKind.percent,
                              child: Text('Discount percent'.tr()),
                            ),
                            DropdownMenuItem(
                              value: InvoiceHeaderDiscountKind.fixed,
                              child: Text('Fixed discount amount'.tr()),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) onHeaderDiscountKindChanged(v);
                          },
                        ),
                      ),
                      SizedBox(width: compactGap),
                      Expanded(
                        child: TextField(
                          controller: headerDiscountValueController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9٠-٩.,٫٬]'),
                            ),
                          ],
                          decoration: InputDecoration(
                            labelText:
                                headerDiscountKind ==
                                    InvoiceHeaderDiscountKind.percent
                                ? 'Discount %'.tr()
                                : 'Discount amount'.tr(),
                            hintText: '0',
                          ),
                          onChanged: onHeaderDiscountValueChanged,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compactGap),
                  DropdownButtonFormField<PaymentMethod>(
                    key: ValueKey(paymentMethod),
                    initialValue: paymentMethod,
                    decoration: InputDecoration(
                      labelText: 'Payment method'.tr(),
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
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        onPaymentMethodChanged(value);
                      }
                    },
                  ),
                  SizedBox(height: compactGap),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(10),
                      color: colorScheme.surfaceContainerLowest,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${'Discount value'.tr()}: ${headerDiscountAmount.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${'Total after discount'.tr()}: ${total.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: compactGap),
            Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<String>(
                enabled: !(loading || readOnlyMode),
                tooltip: 'Invoice actions'.tr(),
                onSelected: (value) {
                  switch (value) {
                    case 'return':
                      onReturnFromInvoice();
                      return;
                    case 'cancel':
                      onCancelInvoice();
                      return;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'return',
                    child: Row(
                      children: [
                        const Icon(Icons.assignment_return_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text('Return From Invoice'.tr()),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'cancel',
                    child: Row(
                      children: [
                        const Icon(Icons.cancel_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text('Cancel Invoice'.tr()),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colorScheme.outlineVariant),
                    color: colorScheme.surface,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.more_horiz),
                      const SizedBox(width: 8),
                      Text(
                        'More actions'.tr(),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_drop_down, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PurchasesSupplierAutocomplete extends StatefulWidget {
  const PurchasesSupplierAutocomplete({
    super.key,
    required this.suppliers,
    required this.supplierId,
    required this.onSupplierSelected,
  });

  final List<AccountLookup> suppliers;
  final int? supplierId;
  final ValueChanged<int?> onSupplierSelected;

  @override
  State<PurchasesSupplierAutocomplete> createState() =>
      _PurchasesSupplierAutocompleteState();
}

class _PurchasesSupplierAutocompleteState
    extends State<PurchasesSupplierAutocomplete> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  String _nameForId(int? id) {
    if (id == null) return '';
    for (final s in widget.suppliers) {
      if (s.id == id) return s.name;
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _nameForId(widget.supplierId));
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant PurchasesSupplierAutocomplete oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.supplierId != oldWidget.supplierId ||
        widget.suppliers != oldWidget.suppliers) {
      final next = _nameForId(widget.supplierId);
      if (!_focusNode.hasFocus && _controller.text != next) {
        _controller.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<AccountLookup>(
      textEditingController: _controller,
      focusNode: _focusNode,
      displayStringForOption: (s) => s.name,
      optionsBuilder: (TextEditingValue value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) {
          return widget.suppliers;
        }
        return widget.suppliers
            .where((s) => s.name.toLowerCase().contains(q))
            .toList();
      },
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
        return TextField(
          controller: textEditingController,
          focusNode: focusNode,
          onSubmitted: (_) => onFieldSubmitted(),
          decoration: InputDecoration(
            labelText: 'Supplier (required)'.tr(),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final list = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 400),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final option = list[index];
                  return ListTile(
                    dense: true,
                    title: Text(option.name),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (AccountLookup s) {
        _controller.value = TextEditingValue(
          text: s.name,
          selection: TextSelection.collapsed(offset: s.name.length),
        );
        widget.onSupplierSelected(s.id);
      },
    );
  }
}

class _AnimatedAdvancedSection extends StatefulWidget {
  const _AnimatedAdvancedSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  State<_AnimatedAdvancedSection> createState() =>
      _AnimatedAdvancedSectionState();
}

class _AnimatedAdvancedSectionState extends State<_AnimatedAdvancedSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _expanded
              ? colorScheme.primary.withValues(alpha: 0.45)
              : colorScheme.outlineVariant,
        ),
        color: _expanded
            ? colorScheme.primaryContainer.withValues(alpha: 0.16)
            : colorScheme.surface,
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: const Icon(Icons.keyboard_arrow_down),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: widget.child,
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }
}
