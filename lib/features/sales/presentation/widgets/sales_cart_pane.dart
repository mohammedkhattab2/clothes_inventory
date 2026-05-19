import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:delta_erp/features/accounts/data/accounts_repository.dart';
import 'package:delta_erp/features/sales/domain/sale_models.dart';

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
    required this.customerPhoneController,
    required this.headerDiscountKind,
    required this.headerDiscountValueController,
    required this.paidController,
    required this.paidWalletController,
    required this.headerDiscountAmount,
    required this.paymentMethod,
    required this.onCustomerChanged,
    required this.onNewCustomerNameChanged,
    required this.onCustomerPhoneChanged,
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
  final TextEditingController customerPhoneController;
  final InvoiceHeaderDiscountKind headerDiscountKind;
  final TextEditingController headerDiscountValueController;
  final TextEditingController paidController;
  final TextEditingController paidWalletController;
  final double headerDiscountAmount;
  final PaymentMethod paymentMethod;
  final ValueChanged<int?> onCustomerChanged;
  final ValueChanged<String> onNewCustomerNameChanged;
  final ValueChanged<String> onCustomerPhoneChanged;
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

  InputDecoration _paidFieldDecoration(
    BuildContext context,
    ColorScheme colorScheme,
    String label,
  ) {
    return InputDecoration(
      labelText: label,
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
    final lockNewCustomer = lockCustPay || selectedCustomerId != null;
    final decimalInputFormatters = <TextInputFormatter>[
      FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩.,٫٬]')),
    ];
    final outstanding =
        (total - effectivePaidTotal).clamp(0.0, total);

    final advancedChild = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        priceTierSelector,
        SizedBox(height: compactGap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DropdownButtonFormField<int?>(
                key: ValueKey('cust_${selectedCustomerId ?? 'walkin'}'),
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
                readOnly: lockNewCustomer,
                decoration: InputDecoration(
                  labelText: 'Or create customer name during sale'.tr(),
                ),
                onChanged: lockNewCustomer ? null : onNewCustomerNameChanged,
              ),
            ),
          ],
        ),
        SizedBox(height: compactGap),
        TextField(
          controller: customerPhoneController,
          readOnly: lockCustPay,
          keyboardType: TextInputType.phone,
          textAlign: TextAlign.left,
          decoration: InputDecoration(
            labelText: 'Customer phone'.tr(),
          ),
          onChanged: onCustomerPhoneChanged,
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
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9٠-٩.,٫٬]'),
                  ),
                ],
                decoration: InputDecoration(
                  labelText: headerDiscountKind ==
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
      return IgnorePointer(
        ignoring: lockCustPay,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (paymentMethod == PaymentMethod.cashAndWallet)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.primaryContainer
                                .withValues(alpha: 0.45),
                            colorScheme.tertiaryContainer
                                .withValues(alpha: 0.28),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary
                                .withValues(alpha: 0.14),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: TextField(
                          controller: paidController,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: decimalInputFormatters,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                          decoration: _paidFieldDecoration(
                            context,
                            colorScheme,
                            'Paid cash amount'.tr(),
                          ),
                          onChanged: onPaidChanged,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: compactGap),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.tertiaryContainer
                                .withValues(alpha: 0.45),
                            colorScheme.primaryContainer
                                .withValues(alpha: 0.22),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.tertiary
                                .withValues(alpha: 0.14),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: TextField(
                          controller: paidWalletController,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: decimalInputFormatters,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                          decoration: _paidFieldDecoration(
                            context,
                            colorScheme,
                            'Paid wallet amount'.tr(),
                          ),
                          onChanged: onPaidWalletChanged,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primaryContainer.withValues(alpha: 0.5),
                      colorScheme.secondaryContainer
                          .withValues(alpha: 0.32),
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
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: decimalInputFormatters,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    decoration: _paidFieldDecoration(
                      context,
                      colorScheme,
                      'Paid amount'.tr(),
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
                padding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: veryDense ? 10 : 12),
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
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            outstanding.toStringAsFixed(2),
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: colorScheme.onSurface,
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
        ),
      );
    }

    final primaryButtons = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: loading || hasInvalidInlineDrafts || readOnlyMode
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
            elevation: 2,
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: veryDense ? 12 : 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        SizedBox(height: compactGap),
        OutlinedButton.icon(
          onPressed: loading ||
                  hasInvalidInlineDrafts ||
                  readOnlyMode ||
                  invoiceAmendmentMode
              ? null
              : onSavePendingSale,
          icon: const Icon(Icons.pause_circle_outline),
          label: Text('Save as Pending Invoice'.tr()),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: veryDense ? 10 : 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            side: BorderSide(
              color: colorScheme.primary.withValues(alpha: 0.5),
            ),
          ),
        ),
      ],
    );

    final canInteractActions =
        !(loading && successInvoiceId == null) &&
            (!(loading || readOnlyMode) || successInvoiceId != null);

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
          case 'pdf':
            onGeneratePdf();
            return;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'return',
          enabled:
              canInteractActions && !(loading || readOnlyMode || invoiceAmendmentMode),
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
          enabled:
              canInteractActions && !(loading || readOnlyMode || invoiceAmendmentMode),
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
          enabled: canInteractActions && successInvoiceId != null,
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
                        'cart.invoice_actions_hint'.tr(),
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
            color: hasInvalidInlineDrafts
                ? colorScheme.error.withValues(alpha: 0.5)
                : colorScheme.outlineVariant,
          ),
          color: hasInvalidInlineDrafts
              ? colorScheme.errorContainer.withValues(alpha: 0.3)
              : colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(
                alpha: hasInvalidInlineDrafts ? 0.0 : 0.06,
              ),
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
                    Icons.shopping_bag_outlined,
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
                        'sale.invoice_amendment_banner'.tr(),
                        style: textTheme.bodySmall?.copyWith(
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
            LayoutBuilder(
              builder: (context, constraints) {
                final sideBySide = constraints.maxWidth >= 760;
                if (sideBySide) {
                  final gapW = compactGap + 4;
                  // Column gives unbounded max height to non-flex children; IntrinsicHeight
                  // bounds the row so CrossAxisAlignment.stretch + SizedBox.expand are valid.
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
            if (hasInvalidInlineDrafts)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Fix invalid cart quantities before completing sale.'.tr(),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
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
