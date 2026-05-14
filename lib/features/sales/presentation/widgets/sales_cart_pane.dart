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
    required this.loading,
    required this.hasInvalidInlineDrafts,
    required this.successInvoiceId,
    required this.priceTierSelector,
    required this.cartContent,
    required this.customers,
    required this.customerId,
    required this.newCustomerController,
    required this.taxPercentController,
    required this.paidController,
    required this.paidAmount,
    required this.taxAmount,
    required this.paymentMethod,
    required this.onCustomerChanged,
    required this.onNewCustomerNameChanged,
    required this.onTaxChanged,
    required this.onPaidChanged,
    required this.onPaymentMethodChanged,
    required this.onCompleteSale,
    required this.onSavePendingSale,
    required this.onReturnFromInvoice,
    required this.onCancelInvoice,
    required this.onGeneratePdf,
    required this.readOnlyMode,
    this.readOnlyMessage,
  });

  final bool veryDense;
  final double total;
  final bool loading;
  final bool hasInvalidInlineDrafts;
  final int? successInvoiceId;
  final Widget priceTierSelector;
  final Widget cartContent;
  final List<AccountLookup> customers;
  final int? customerId;
  final TextEditingController newCustomerController;
  final TextEditingController taxPercentController;
  final TextEditingController paidController;
  final double paidAmount;
  final double taxAmount;
  final PaymentMethod paymentMethod;
  final ValueChanged<int?> onCustomerChanged;
  final ValueChanged<String> onNewCustomerNameChanged;
  final ValueChanged<String> onTaxChanged;
  final ValueChanged<String> onPaidChanged;
  final ValueChanged<PaymentMethod> onPaymentMethodChanged;
  final VoidCallback onCompleteSale;
  final VoidCallback onSavePendingSale;
  final VoidCallback onReturnFromInvoice;
  final VoidCallback onCancelInvoice;
  final VoidCallback onGeneratePdf;
  final bool readOnlyMode;
  final String? readOnlyMessage;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final uniqueCustomers = <int, AccountLookup>{
      for (final customer in customers) customer.id: customer,
    }.values.toList(growable: false);
    final selectedCustomerId = customerId != null &&
            uniqueCustomers.any((customer) => customer.id == customerId)
        ? customerId
        : null;

    return Card(
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(veryDense ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Cart'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '${'Total with Tax'.tr()}: ${total.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            SizedBox(height: veryDense ? 6 : 8),
            priceTierSelector,
            SizedBox(height: veryDense ? 6 : 8),
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
            Expanded(child: cartContent),
            const Divider(),
            DropdownButtonFormField<int?>(
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
                  (c) =>
                      DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
                ),
              ],
              onChanged: onCustomerChanged,
            ),
            SizedBox(height: veryDense ? 6 : 8),
            TextField(
              controller: newCustomerController,
              decoration: InputDecoration(
                labelText: 'Or create customer name during sale'.tr(),
              ),
              onChanged: onNewCustomerNameChanged,
            ),
            SizedBox(height: veryDense ? 6 : 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: taxPercentController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9٠-٩.,٫٬]'),
                      ),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Tax %'.tr(),
                      hintText: '0',
                    ),
                    onChanged: onTaxChanged,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(10),
                      color: colorScheme.surface,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${'Tax Amount'.tr()}: ${taxAmount.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${'Total with Tax'.tr()}: ${total.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: veryDense ? 6 : 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: paidController,
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
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<PaymentMethod>(
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
                ),
              ],
            ),
            SizedBox(height: veryDense ? 8 : 10),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${'Outstanding'.tr()}: ${(total - paidAmount).clamp(0, total).toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: veryDense ? 8 : 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: loading || hasInvalidInlineDrafts || readOnlyMode
                    ? null
                    : onCompleteSale,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(loading ? 'Saving...'.tr() : 'Complete Sale'.tr()),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: veryDense ? 10 : 12,
                  ),
                ),
              ),
            ),
            SizedBox(height: veryDense ? 6 : 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: loading || hasInvalidInlineDrafts || readOnlyMode
                    ? null
                    : onSavePendingSale,
                icon: const Icon(Icons.pause_circle_outline),
                label: Text('Save as Pending Invoice'.tr()),
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
            SizedBox(height: veryDense ? 6 : 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
                if (compact) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: loading || readOnlyMode
                            ? null
                            : onReturnFromInvoice,
                        icon: const Icon(Icons.assignment_return_outlined),
                        label: Text('Return From Invoice'.tr()),
                      ),
                      OutlinedButton.icon(
                        onPressed: loading || readOnlyMode
                            ? null
                            : onCancelInvoice,
                        icon: const Icon(Icons.cancel_outlined),
                        label: Text('Cancel Invoice'.tr()),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: loading || readOnlyMode
                            ? null
                            : onReturnFromInvoice,
                        icon: const Icon(Icons.assignment_return_outlined),
                        label: Text('Return From Invoice'.tr()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: loading || readOnlyMode
                            ? null
                            : onCancelInvoice,
                        icon: const Icon(Icons.cancel_outlined),
                        label: Text('Cancel Invoice'.tr()),
                      ),
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: veryDense ? 6 : 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: successInvoiceId == null ? null : onGeneratePdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Generate A4 Invoice PDF (Last Sale)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
