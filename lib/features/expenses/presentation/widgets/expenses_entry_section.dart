import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:delta_erp/core/utils/translation_utils.dart';
import 'package:delta_erp/core/widgets/app_inline_loading_indicator.dart';
import 'package:delta_erp/core/widgets/app_page_shell.dart';
import 'package:delta_erp/features/accounts/data/accounts_repository.dart';

class ExpensesEntrySection extends StatelessWidget {
  const ExpensesEntrySection({
    super.key,
    required this.isCompact,
    required this.posting,
    required this.expenseAccounts,
    required this.selectedEntryExpenseAccountId,
    required this.amountController,
    required this.paymentMethod,
    required this.notesController,
    required this.onEntryAccountChanged,
    required this.onPaymentMethodChanged,
    required this.onAddExpense,
  });

  final bool isCompact;
  final bool posting;
  final List<AccountLookup> expenseAccounts;
  final int? selectedEntryExpenseAccountId;
  final TextEditingController amountController;
  final String paymentMethod;
  final TextEditingController notesController;
  final ValueChanged<int?> onEntryAccountChanged;
  final ValueChanged<String> onPaymentMethodChanged;
  final VoidCallback onAddExpense;

  @override
  Widget build(BuildContext context) {
    return AppSectionPanel(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: isCompact ? double.infinity : 220,
            child: DropdownButtonFormField<int>(
              initialValue: selectedEntryExpenseAccountId,
              decoration: InputDecoration(labelText: 'Expense Category'.tr()),
              items: expenseAccounts
                  .map(
                    (a) => DropdownMenuItem<int>(
                      value: a.id,
                      child: Text(trIfExists(a.name, context: context)),
                    ),
                  )
                  .toList(),
              onChanged: onEntryAccountChanged,
            ),
          ),
          SizedBox(
            width: isCompact ? double.infinity : 160,
            child: TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: 'Amount'.tr()),
            ),
          ),
          SizedBox(
            width: isCompact ? double.infinity : 180,
            child: DropdownButtonFormField<String>(
              initialValue: paymentMethod,
              decoration: InputDecoration(labelText: 'Payment method'.tr()),
              items: [
                DropdownMenuItem(value: 'cash', child: Text('Cash'.tr())),
                DropdownMenuItem(
                  value: 'vodafone_cash',
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
          SizedBox(
            width: isCompact ? double.infinity : 280,
            child: TextField(
              controller: notesController,
              decoration: InputDecoration(labelText: 'Notes (optional)'.tr()),
            ),
          ),
          FilledButton.icon(
            onPressed: posting ? null : onAddExpense,
            icon: posting
                ? const AppInlineLoadingIndicator()
                : const Icon(Icons.add_rounded),
            label: Text('Add Expense'.tr()),
          ),
        ],
      ),
    );
  }
}
