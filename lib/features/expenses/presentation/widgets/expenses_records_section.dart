import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:clothes_inventory/core/utils/translation_utils.dart';
import 'package:clothes_inventory/core/widgets/app_empty_state.dart';
import 'package:clothes_inventory/core/widgets/app_error_banner.dart';
import 'package:clothes_inventory/core/widgets/app_loading_indicator.dart';
import 'package:clothes_inventory/core/widgets/app_page_shell.dart';
import 'package:clothes_inventory/features/expenses/data/expenses_repository.dart';

class ExpensesRecordsSection extends StatelessWidget {
  const ExpensesRecordsSection({
    super.key,
    required this.loading,
    required this.posting,
    required this.error,
    required this.records,
    required this.onEditExpense,
    required this.onDeleteExpense,
    required this.formatMoney,
    required this.compactErrorMessage,
  });

  final bool loading;
  final bool posting;
  final String? error;
  final List<ExpenseRecord> records;
  final ValueChanged<ExpenseRecord> onEditExpense;
  final ValueChanged<ExpenseRecord> onDeleteExpense;
  final String Function(double value) formatMoney;
  final String Function(String raw) compactErrorMessage;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          if (error != null) ...[
            AppErrorBanner(message: compactErrorMessage(error!)),
            const SizedBox(height: 10),
          ],
          Expanded(
            child: AppSectionPanel(
              child: loading
                  ? AppLoadingIndicator(label: 'Loading expenses...'.tr())
                  : records.isEmpty
                  ? AppEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No expenses found.'.tr(),
                    )
                  : ListView.separated(
                      itemCount: records.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final row = records[index];
                        final isReversal = row.amount < 0;
                        final colorScheme = Theme.of(context).colorScheme;
                        return ListTile(
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  trIfExists(row.accountName, context: context),
                                ),
                              ),
                              if (isReversal)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'Reversal'.tr(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color:
                                              colorScheme.onSecondaryContainer,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            '${DateFormat('yyyy-MM-dd HH:mm').format(row.createdAt)} | ${row.paymentMethod == 'cash' ? 'Cash'.tr() : 'Vodafone Cash'.tr()}${row.notes == null || row.notes!.isEmpty ? '' : ' | ${row.notes}'}',
                          ),
                          leading: isReversal
                              ? const Icon(Icons.undo_rounded)
                              : const Icon(Icons.receipt_long_outlined),
                          onLongPress: isReversal
                              ? null
                              : () => onEditExpense(row),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                formatMoney(row.amount),
                                style: TextStyle(
                                  color: row.amount >= 0
                                      ? Colors.red.shade700
                                      : Colors.green.shade700,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (!isReversal) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'Edit'.tr(),
                                  onPressed: posting
                                      ? null
                                      : () => onEditExpense(row),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Delete'.tr(),
                                  onPressed: posting
                                      ? null
                                      : () => onDeleteExpense(row),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
