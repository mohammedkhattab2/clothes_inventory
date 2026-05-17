import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:delta_erp/core/utils/translation_utils.dart';
import 'package:delta_erp/core/widgets/app_page_shell.dart';
import 'package:delta_erp/features/accounts/data/accounts_repository.dart';

class ExpensesFiltersSection extends StatelessWidget {
  const ExpensesFiltersSection({
    super.key,
    required this.isCompact,
    required this.fromDate,
    required this.toDate,
    required this.showReversals,
    required this.searchController,
    required this.selectedFilterExpenseAccountId,
    required this.sortIndex,
    required this.pageSize,
    required this.expenseAccounts,
    required this.grossTotal,
    required this.netTotal,
    required this.onPickFromDate,
    required this.onPickToDate,
    required this.onClearDateFilters,
    required this.onToggleReversals,
    required this.onSearchChanged,
    required this.onFilterAccountChanged,
    required this.onSortChanged,
    required this.onPageSizeChanged,
    required this.formatMoney,
  });

  final bool isCompact;
  final DateTime? fromDate;
  final DateTime? toDate;
  final bool showReversals;
  final TextEditingController searchController;
  final int? selectedFilterExpenseAccountId;
  final int sortIndex;
  final int pageSize;
  final List<AccountLookup> expenseAccounts;
  final double grossTotal;
  final double netTotal;
  final VoidCallback onPickFromDate;
  final VoidCallback onPickToDate;
  final VoidCallback onClearDateFilters;
  final ValueChanged<bool> onToggleReversals;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int?> onFilterAccountChanged;
  final ValueChanged<int> onSortChanged;
  final ValueChanged<int> onPageSizeChanged;
  final String Function(double value) formatMoney;

  @override
  Widget build(BuildContext context) {
    return AppSectionPanel(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: onPickFromDate,
            icon: const Icon(Icons.date_range_outlined),
            label: Text(
              fromDate == null
                  ? '${'From'.tr()}: ${'Any date'.tr()}'
                  : '${'From'.tr()}: ${DateFormat('yyyy-MM-dd').format(fromDate!)}',
            ),
          ),
          OutlinedButton.icon(
            onPressed: onPickToDate,
            icon: const Icon(Icons.event_outlined),
            label: Text(
              toDate == null
                  ? '${'To'.tr()}: ${'Any date'.tr()}'
                  : '${'To'.tr()}: ${DateFormat('yyyy-MM-dd').format(toDate!)}',
            ),
          ),
          TextButton(
            onPressed: onClearDateFilters,
            child: Text('Clear Filters'.tr()),
          ),
          FilterChip(
            selected: showReversals,
            onSelected: onToggleReversals,
            label: Text('Show reversals'.tr()),
          ),
          SizedBox(
            width: isCompact ? double.infinity : 260,
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Search expenses'.tr(),
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: onSearchChanged,
            ),
          ),
          SizedBox(
            width: isCompact ? double.infinity : 240,
            child: DropdownButtonFormField<int?>(
              initialValue: selectedFilterExpenseAccountId,
              decoration: InputDecoration(labelText: 'Filter by category'.tr()),
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text('All categories'.tr()),
                ),
                ...expenseAccounts.map(
                  (a) => DropdownMenuItem<int?>(
                    value: a.id,
                    child: Text(trIfExists(a.name, context: context)),
                  ),
                ),
              ],
              onChanged: onFilterAccountChanged,
            ),
          ),
          SizedBox(
            width: isCompact ? double.infinity : 240,
            child: DropdownButtonFormField<int>(
              initialValue: sortIndex,
              decoration: InputDecoration(labelText: 'Sort by'.tr()),
              items: [
                DropdownMenuItem(value: 0, child: Text('Newest'.tr())),
                DropdownMenuItem(value: 1, child: Text('Oldest'.tr())),
                DropdownMenuItem(
                  value: 2,
                  child: Text('Amount High to Low'.tr()),
                ),
                DropdownMenuItem(
                  value: 3,
                  child: Text('Amount Low to High'.tr()),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  onSortChanged(value);
                }
              },
            ),
          ),
          SizedBox(
            width: isCompact ? double.infinity : 160,
            child: DropdownButtonFormField<int>(
              initialValue: pageSize,
              decoration: InputDecoration(labelText: 'rows/page'.tr()),
              items: const [25, 50, 100]
                  .map(
                    (v) => DropdownMenuItem<int>(value: v, child: Text('$v')),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  onPageSizeChanged(value);
                }
              },
            ),
          ),
          Chip(
            label: Text(
              '${'Gross Expenses'.tr()}: ${formatMoney(grossTotal)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Chip(
            label: Text(
              '${'Net Expenses'.tr()}: ${formatMoney(netTotal)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
