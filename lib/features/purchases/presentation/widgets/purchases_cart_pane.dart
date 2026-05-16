import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:clothes_inventory/features/accounts/data/accounts_repository.dart';
import 'package:clothes_inventory/features/sales/domain/sale_models.dart';

class PurchasesCartPane extends StatelessWidget {
  const PurchasesCartPane({
    super.key,
    required this.veryDense,
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
    this.invoiceAmendmentMode = false,
    this.onCancelInvoiceAmendment,
  });

  final bool veryDense;
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
  final bool invoiceAmendmentMode;
  final VoidCallback? onCancelInvoiceAmendment;

  InputDecoration _paidFieldDecoration(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return InputDecoration(
      labelText: 'Paid amount'.tr(),
      hintText: '0',
      filled: true,
      fillColor: colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.35),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: colorScheme.primary,
          width: 1.6,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final compactGap = veryDense ? 6.0 : 8.0;
    final sectionGap = veryDense ? 8.0 : 10.0;
    const panelDuration = Duration(milliseconds: 220);

    final advancedChild = Column(
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
                enabled: !invoiceAmendmentMode,
              ),
            ),
            SizedBox(width: compactGap),
            OutlinedButton.icon(
              onPressed: invoiceAmendmentMode ? null : onAddSupplier,
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: Text('Add Supplier'.tr()),
            ),
          ],
        ),
        SizedBox(height: compactGap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: paymentStatusIndex,
                decoration: InputDecoration(
                  labelText: 'Payment Status'.tr(),
                ),
                items: paymentStatusItems,
                onChanged: invoiceAmendmentMode ? null : onPaymentStatusChanged,
              ),
            ),
            SizedBox(width: compactGap),
            Expanded(
              child: DropdownButtonFormField<PaymentMethod>(
                key: ValueKey(paymentMethod),
                isExpanded: true,
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
                  DropdownMenuItem(
                    value: PaymentMethod.visa,
                    child: Text('Visa'.tr()),
                  ),
                ],
                onChanged: (value) {
                  if (invoiceAmendmentMode) return;
                  if (value != null) {
                    onPaymentMethodChanged(value);
                  }
                },
              ),
            ),
          ],
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
                  if (invoiceAmendmentMode) return;
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
                      headerDiscountKind == InvoiceHeaderDiscountKind.percent
                      ? 'Discount %'.tr()
                      : 'Discount amount'.tr(),
                  hintText: '0',
                ),
                onChanged: invoiceAmendmentMode
                    ? null
                    : onHeaderDiscountValueChanged,
              ),
            ),
          ],
        ),
        SizedBox(height: compactGap),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: [
                colorScheme.tertiaryContainer.withValues(alpha: 0.28),
                colorScheme.primaryContainer.withValues(alpha: 0.2),
              ],
            ),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.85),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Discount value'.tr(),
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: veryDense ? 2 : 3),
                    Text(
                      headerDiscountAmount.toStringAsFixed(2),
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 36,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: colorScheme.outlineVariant.withValues(alpha: 0.55),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total after discount'.tr(),
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: veryDense ? 2 : 3),
                    Text(
                      total.toStringAsFixed(2),
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: colorScheme.primary,
                        fontFeatures: const [
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );

    Widget paidMoneyColumn() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primaryContainer.withValues(alpha: 0.5),
                  colorScheme.secondaryContainer.withValues(alpha: 0.32),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.16),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: paidController,
                focusNode: paidAmountFocusNode,
                enabled: paidFieldEnabled && !invoiceAmendmentMode,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9٠-٩.,٫٬]'),
                  ),
                ],
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                decoration: _paidFieldDecoration(
                  context,
                  colorScheme,
                ).copyWith(
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
                onChanged: onPaidChanged,
              ),
            ),
          ),
          SizedBox(height: compactGap),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  colorScheme.errorContainer.withValues(alpha: 0.35),
                  colorScheme.primaryContainer.withValues(alpha: 0.4),
                ],
              ),
              border: Border.all(
                color: colorScheme.error.withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.error.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: veryDense ? 10 : 12,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    color: colorScheme.onPrimaryContainer,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Outstanding'.tr(),
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          outstandingAmount.toStringAsFixed(2),
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final primaryButtons = FilledButton.icon(
      onPressed: loading || readOnlyMode ? null : onCompletePurchase,
      icon: const Icon(Icons.check_circle_outline),
      label: Text(
        loading
            ? 'Saving...'.tr()
            : invoiceAmendmentMode
                ? 'purchase.complete_amendment'.tr()
                : 'Complete Purchase'.tr(),
      ),
      style: FilledButton.styleFrom(
        elevation: 2,
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: veryDense ? 12 : 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );

    final canInteractActions = !(loading || readOnlyMode);

    final moreActionsMenu = PopupMenuButton<String>(
      enabled: canInteractActions,
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
          enabled: canInteractActions && !invoiceAmendmentMode,
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
          enabled: canInteractActions && !invoiceAmendmentMode,
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
              style: textTheme.labelLarge,
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );

    Widget paymentBlock({required bool stretchToMatch}) {
      final paymentColumn = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          paidMoneyColumn(),
          SizedBox(height: sectionGap),
          primaryButtons,
          SizedBox(height: compactGap + 2),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
                colors: [
                  colorScheme.tertiaryContainer.withValues(alpha: 0.28),
                  colorScheme.primaryContainer.withValues(alpha: 0.2),
                ],
              ),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.85),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primary.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    Icons.dashboard_customize_outlined,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invoice actions'.tr(),
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'cart.invoice_actions_hint_purchases'.tr(),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                moreActionsMenu,
              ],
            ),
          ),
        ],
      );

      final card = AnimatedContainer(
        duration: panelDuration,
        curve: Curves.easeOutCubic,
        width: double.infinity,
        padding: EdgeInsets.all(veryDense ? 12 : 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.outlineVariant,
          ),
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: stretchToMatch
            ? Align(
                alignment: AlignmentDirectional.topStart,
                child: paymentColumn,
              )
            : paymentColumn,
      );
      if (stretchToMatch) {
        return SizedBox.expand(child: card);
      }
      return card;
    }

    Widget sideRail({required bool fillHeight}) {
      final core = _AnimatedAdvancedSection(
        title: 'Advanced options'.tr(),
        initiallyExpanded: true,
        fillRemainingHeight: fillHeight,
        child: advancedChild,
      );
      if (fillHeight) {
        return SizedBox.expand(child: core);
      }
      return core;
    }

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
                  style: textTheme.titleMedium?.copyWith(
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
                    style: textTheme.labelLarge?.copyWith(
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
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (invoiceAmendmentMode)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colorScheme.secondaryContainer),
                  color: colorScheme.secondaryContainer.withValues(
                    alpha: 0.35,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.edit_note_outlined,
                      size: 20,
                      color: colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'purchase.invoice_amendment_banner'.tr(),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          readOnlyMode ? null : onCancelInvoiceAmendment,
                      child: Text('purchase.cancel_amendment'.tr()),
                    ),
                  ],
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
            LayoutBuilder(
              builder: (context, constraints) {
                final sideBySide = constraints.maxWidth >= 760;
                if (sideBySide) {
                  final gapW = compactGap + 4;
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 58,
                          child: paymentBlock(stretchToMatch: true),
                        ),
                        SizedBox(width: gapW),
                        Expanded(
                          flex: 42,
                          child: sideRail(fillHeight: true),
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    paymentBlock(stretchToMatch: false),
                    SizedBox(height: sectionGap),
                    sideRail(fillHeight: false),
                  ],
                );
              },
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
    this.enabled = true,
  });

  final List<AccountLookup> suppliers;
  final int? supplierId;
  final ValueChanged<int?> onSupplierSelected;
  final bool enabled;

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
        if (!widget.enabled) {
          return const Iterable<AccountLookup>.empty();
        }
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
          readOnly: !widget.enabled,
          enableInteractiveSelection: widget.enabled,
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
        if (!widget.enabled) return;
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
  const _AnimatedAdvancedSection({
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
    this.fillRemainingHeight = false,
  });

  final String title;
  final Widget child;
  final bool initiallyExpanded;
  final bool fillRemainingHeight;

  @override
  State<_AnimatedAdvancedSection> createState() =>
      _AnimatedAdvancedSectionState();
}

class _AnimatedAdvancedSectionState extends State<_AnimatedAdvancedSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final body = widget.fillRemainingHeight
        ? Expanded(
            child: ClipRect(
              child: AnimatedAlign(
                heightFactor: _expanded ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          )
        : AnimatedCrossFade(
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
          );

    final panel = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _expanded
              ? colorScheme.primary.withValues(alpha: 0.45)
              : colorScheme.outlineVariant,
        ),
        color: _expanded
            ? colorScheme.primaryContainer.withValues(alpha: 0.16)
            : colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(
              alpha: _expanded ? 0.08 : 0.03,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: widget.fillRemainingHeight
            ? MainAxisSize.max
            : MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
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
          body,
        ],
      ),
    );

    return panel;
  }
}
