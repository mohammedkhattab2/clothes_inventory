import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:clothes_inventory/features/accounts/data/accounts_repository.dart';
import 'package:clothes_inventory/features/sales/domain/sale_models.dart';

class SalesCartPane extends StatelessWidget {
  const SalesCartPane({
    super.key,
    required this.veryDense,
    required this.total,
    required this.effectivePaidTotal,
    required this.loading,
    required this.hasInvalidInlineDrafts,
    required this.successInvoiceId,
    required this.priceTierSelector,
    required this.cartContent,
    required this.customers,
    required this.customerId,
    required this.newCustomerController,
    required this.headerDiscountKind,
    required this.headerDiscountValueController,
    required this.paidController,
    required this.paidWalletController,
    required this.paidAmount,
    required this.paidWalletAmount,
    required this.headerDiscountAmount,
    required this.paymentMethod,
    required this.onCustomerChanged,
    required this.onNewCustomerNameChanged,
    required this.onHeaderDiscountKindChanged,
    required this.onHeaderDiscountValueChanged,
    required this.onPaidChanged,
    required this.onPaidWalletChanged,
    required this.onPaymentMethodChanged,
    required this.onCompleteSale,
    required this.onSavePendingSale,
    required this.onReturnFromInvoice,
    required this.onCancelInvoice,
    required this.onGeneratePdf,
    required this.readOnlyMode,
    this.readOnlyMessage,
    this.invoiceAmendmentMode = false,
    this.onCancelInvoiceAmendment,
  });

  final bool veryDense;
  final double total;
  /// Sum of paid portions (cash + wallet when split) for outstanding display.
  final double effectivePaidTotal;
  final bool loading;
  final bool hasInvalidInlineDrafts;
  final int? successInvoiceId;
  final Widget priceTierSelector;
  final Widget cartContent;
  final List<AccountLookup> customers;
  final int? customerId;
  final TextEditingController newCustomerController;
  final InvoiceHeaderDiscountKind headerDiscountKind;
  final TextEditingController headerDiscountValueController;
  final TextEditingController paidController;
  final TextEditingController paidWalletController;
  final double paidAmount;
  final double paidWalletAmount;
  final double headerDiscountAmount;
  final PaymentMethod paymentMethod;
  final ValueChanged<int?> onCustomerChanged;
  final ValueChanged<String> onNewCustomerNameChanged;
  final ValueChanged<InvoiceHeaderDiscountKind> onHeaderDiscountKindChanged;
  final ValueChanged<String> onHeaderDiscountValueChanged;
  final ValueChanged<String> onPaidChanged;
  final ValueChanged<String> onPaidWalletChanged;
  final ValueChanged<PaymentMethod> onPaymentMethodChanged;
  final VoidCallback onCompleteSale;
  final VoidCallback onSavePendingSale;
  final VoidCallback onReturnFromInvoice;
  final VoidCallback onCancelInvoice;
  final VoidCallback onGeneratePdf;
  final bool readOnlyMode;
  final String? readOnlyMessage;

  /// Editing an issued invoice in cart (loads from return flow).
  final bool invoiceAmendmentMode;
  final VoidCallback? onCancelInvoiceAmendment;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lockCustPay = invoiceAmendmentMode;
    final compactGap = veryDense ? 6.0 : 8.0;
    final sectionGap = veryDense ? 8.0 : 10.0;
    const panelDuration = Duration(milliseconds: 220);
    final uniqueCustomers = <int, AccountLookup>{
      for (final customer in customers) customer.id: customer,
    }.values.toList(growable: false);
    final selectedCustomerId =
        customerId != null &&
            uniqueCustomers.any((customer) => customer.id == customerId)
        ? customerId
        : null;
    final decimalInputFormatters = <TextInputFormatter>[
      FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩.,٫٬]')),
    ];

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
                    Icons.shopping_bag_outlined,
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
                        'sale.invoice_amendment_banner'.tr(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          readOnlyMode ? null : onCancelInvoiceAmendment,
                      child: Text('sale.cancel_amendment'.tr()),
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
            AnimatedContainer(
              duration: panelDuration,
              curve: Curves.easeOutCubic,
              width: double.infinity,
              padding: EdgeInsets.all(veryDense ? 10 : 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasInvalidInlineDrafts
                      ? colorScheme.error.withValues(alpha: 0.5)
                      : colorScheme.outlineVariant,
                ),
                color: hasInvalidInlineDrafts
                    ? colorScheme.errorContainer.withValues(alpha: 0.3)
                    : colorScheme.surface,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IgnorePointer(
                    ignoring: lockCustPay,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (paymentMethod == PaymentMethod.cashAndWallet)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: paidController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: decimalInputFormatters,
                                  decoration: InputDecoration(
                                    labelText: 'Paid cash amount'.tr(),
                                    hintText: '0',
                                  ),
                                  onChanged: onPaidChanged,
                                ),
                              ),
                              SizedBox(width: compactGap),
                              Expanded(
                                child: TextField(
                                  controller: paidWalletController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: decimalInputFormatters,
                                  decoration: InputDecoration(
                                    labelText: 'Paid wallet amount'.tr(),
                                    hintText: '0',
                                  ),
                                  onChanged: onPaidWalletChanged,
                                ),
                              ),
                            ],
                          )
                        else
                          TextField(
                            controller: paidController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                            inputFormatters: decimalInputFormatters,
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
                            '${'Outstanding'.tr()}: ${(total - effectivePaidTotal).clamp(0.0, total).toStringAsFixed(2)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: compactGap),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          loading || hasInvalidInlineDrafts || readOnlyMode
                          ? null
                          : onCompleteSale,
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(
                        loading
                            ? 'Saving...'.tr()
                            : invoiceAmendmentMode
                                ? 'sale.complete_amendment'.tr()
                                : 'Complete Sale'.tr(),
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
                  SizedBox(height: compactGap),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          loading ||
                              hasInvalidInlineDrafts ||
                              readOnlyMode ||
                              invoiceAmendmentMode
                          ? null
                          : onSavePendingSale,
                      icon: const Icon(Icons.pause_circle_outline),
                      label: Text('Save as Pending Invoice'.tr()),
                    ),
                  ),
                ],
              ),
            ),
            if (hasInvalidInlineDrafts)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Fix invalid cart quantities before completing sale.'.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            SizedBox(height: compactGap),
            _AnimatedAdvancedSection(
              title: 'Advanced options'.tr(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  priceTierSelector,
                  SizedBox(height: compactGap),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          key: ValueKey(
                            'cust_${selectedCustomerId ?? 'walkin'}',
                          ),
                          isExpanded: true,
                          initialValue: selectedCustomerId,
                          decoration: InputDecoration(
                            labelText: 'Customer (optional)'.tr(),
                          ),
                          items: [
                            DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Walk-in / No customer'.tr()),
                            ),
                            ...uniqueCustomers.map(
                              (c) => DropdownMenuItem<int?>(
                                value: c.id,
                                child: Text(
                                  c.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: lockCustPay ? null : onCustomerChanged,
                        ),
                      ),
                      SizedBox(width: compactGap),
                      Expanded(
                        child: TextField(
                          controller: newCustomerController,
                          readOnly: lockCustPay,
                          decoration: InputDecoration(
                            labelText:
                                'Or create customer name during sale'.tr(),
                          ),
                          onChanged: onNewCustomerNameChanged,
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
                            if (v != null) onHeaderDiscountKindChanged(v);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                              value: PaymentMethod.cashAndWallet,
                              child: Text('Cash + Wallet'.tr()),
                            ),
                          ],
                          onChanged: lockCustPay
                              ? null
                              : (value) {
                                  if (value != null) {
                                    onPaymentMethodChanged(value);
                                  }
                                },
                        ),
                      ),
                      SizedBox(width: compactGap),
                      Expanded(
                        child: Container(
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
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: compactGap),
            Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<String>(
                enabled:
                    !(loading && successInvoiceId == null) &&
                    (!(loading || readOnlyMode) || successInvoiceId != null),
                tooltip: 'Invoice actions'.tr(),
                onSelected: (value) {
                  switch (value) {
                    case 'return':
                      onReturnFromInvoice();
                      return;
                    case 'cancel':
                      onCancelInvoice();
                      return;
                    case 'pdf':
                      onGeneratePdf();
                      return;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'return',
                    enabled: !(loading || readOnlyMode || invoiceAmendmentMode),
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
                    enabled: !(loading || readOnlyMode || invoiceAmendmentMode),
                    child: Row(
                      children: [
                        const Icon(Icons.cancel_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text('Cancel Invoice'.tr()),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'pdf',
                    enabled: successInvoiceId != null,
                    child: Row(
                      children: [
                        const Icon(Icons.picture_as_pdf_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Generate A4 Invoice PDF (Last Sale)'.tr(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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
