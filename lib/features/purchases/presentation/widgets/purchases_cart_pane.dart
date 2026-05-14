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
    required this.taxPercentController,
    required this.paidController,
    required this.paidAmountFocusNode,
    required this.taxAmount,
    required this.outstandingAmount,
    required this.paymentMethod,
    required this.paidFieldEnabled,
    required this.onAddSupplier,
    required this.onSupplierChanged,
    required this.onPaymentStatusChanged,
    required this.onTaxChanged,
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
  final TextEditingController taxPercentController;
  final TextEditingController paidController;
  final FocusNode paidAmountFocusNode;
  final double taxAmount;
  final double outstandingAmount;
  final PaymentMethod paymentMethod;
  final bool paidFieldEnabled;
  final VoidCallback onAddSupplier;
  final ValueChanged<int?> onSupplierChanged;
  final ValueChanged<int?> onPaymentStatusChanged;
  final ValueChanged<String> onTaxChanged;
  final ValueChanged<String>? onPaidChanged;
  final ValueChanged<PaymentMethod> onPaymentMethodChanged;
  final VoidCallback onCompletePurchase;
  final VoidCallback onReturnFromInvoice;
  final VoidCallback onCancelInvoice;
  final bool readOnlyMode;
  final String? readOnlyMessage;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).height < 720 ? 12 : 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Cart'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '${'Total with Tax'.tr()}: ${total.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.sizeOf(context).height < 720 ? 6 : 8),
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
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: supplierId,
                    decoration: InputDecoration(
                      labelText: 'Supplier (required)'.tr(),
                    ),
                    items: suppliers
                        .map(
                          (s) => DropdownMenuItem<int>(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        )
                        .toList(),
                    onChanged: onSupplierChanged,
                  ),
                ),
                SizedBox(
                  width: MediaQuery.sizeOf(context).height < 720 ? 6 : 8,
                ),
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
            SizedBox(height: MediaQuery.sizeOf(context).height < 720 ? 6 : 8),
            DropdownButtonFormField<int>(
              initialValue: paymentStatusIndex,
              decoration: InputDecoration(labelText: 'Payment Status'.tr()),
              items: paymentStatusItems,
              onChanged: onPaymentStatusChanged,
            ),
            SizedBox(height: MediaQuery.sizeOf(context).height < 720 ? 6 : 8),
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
                SizedBox(
                  width: MediaQuery.sizeOf(context).height < 720 ? 6 : 8,
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      color: Theme.of(context).colorScheme.surface,
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
            SizedBox(height: MediaQuery.sizeOf(context).height < 720 ? 6 : 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
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
                ),
                SizedBox(
                  width: MediaQuery.sizeOf(context).height < 720 ? 6 : 8,
                ),
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
            SizedBox(height: MediaQuery.sizeOf(context).height < 720 ? 6 : 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${'Outstanding'.tr()}: ${outstandingAmount.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: MediaQuery.sizeOf(context).height < 720 ? 8 : 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: loading || readOnlyMode ? null : onCompletePurchase,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  loading ? 'Saving...'.tr() : 'Complete Purchase'.tr(),
                ),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: MediaQuery.sizeOf(context).height < 720 ? 10 : 12,
                  ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.sizeOf(context).height < 720 ? 6 : 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final compactActions = constraints.maxWidth < 520;
                if (compactActions) {
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
          ],
        ),
      ),
    );
  }
}
