import 'package:flutter/material.dart';
import 'package:clothes_inventory/core/widgets/app_page_shell.dart';
import 'package:clothes_inventory/features/accounts/data/accounts_repository.dart';
import 'package:clothes_inventory/features/expenses/data/expenses_repository.dart';
import 'package:clothes_inventory/features/expenses/presentation/widgets/expenses_entry_section.dart';
import 'package:clothes_inventory/features/expenses/presentation/widgets/expenses_filters_section.dart';
import 'package:clothes_inventory/features/expenses/presentation/widgets/expenses_header_section.dart';
import 'package:clothes_inventory/features/expenses/presentation/widgets/expenses_pagination_section.dart';
import 'package:clothes_inventory/features/expenses/presentation/widgets/expenses_records_section.dart';

class ExpensesPageLayout extends StatelessWidget {
  const ExpensesPageLayout({
    super.key,
    required this.isCompact,
    required this.loading,
    required this.posting,
    required this.exportingCsv,
    required this.exportingPdf,
    required this.printing,
    required this.error,
    required this.lastExportPath,
    required this.fromDate,
    required this.toDate,
    required this.paymentMethod,
    required this.showReversals,
    required this.searchController,
    required this.amountController,
    required this.notesController,
    required this.searchQuery,
    required this.sortIndex,
    required this.pageSize,
    required this.expenseAccounts,
    required this.records,
    required this.selectedEntryExpenseAccountId,
    required this.selectedFilterExpenseAccountId,
    required this.totalCount,
    required this.grossTotal,
    required this.netTotal,
    required this.safePage,
    required this.totalPages,
    required this.showingFrom,
    required this.showingTo,
    required this.onPrintReport,
    required this.onExportPdf,
    required this.onExportCsv,
    required this.onOpenExportFolder,
    required this.onRefresh,
    required this.onEntryAccountChanged,
    required this.onPaymentMethodChanged,
    required this.onAddExpense,
    required this.onPickFromDate,
    required this.onPickToDate,
    required this.onClearDateFilters,
    required this.onToggleReversals,
    required this.onSearchChanged,
    required this.onFilterAccountChanged,
    required this.onSortChanged,
    required this.onPageSizeChanged,
    required this.onEditExpense,
    required this.onDeleteExpense,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.formatMoney,
    required this.compactErrorMessage,
  });

  final bool isCompact;
  final bool loading;
  final bool posting;
  final bool exportingCsv;
  final bool exportingPdf;
  final bool printing;
  final String? error;
  final String? lastExportPath;
  final DateTime? fromDate;
  final DateTime? toDate;
  final String paymentMethod;
  final bool showReversals;
  final TextEditingController searchController;
  final TextEditingController amountController;
  final TextEditingController notesController;
  final String searchQuery;
  final int sortIndex;
  final int pageSize;
  final List<AccountLookup> expenseAccounts;
  final List<ExpenseRecord> records;
  final int? selectedEntryExpenseAccountId;
  final int? selectedFilterExpenseAccountId;
  final int totalCount;
  final double grossTotal;
  final double netTotal;
  final int safePage;
  final int totalPages;
  final int showingFrom;
  final int showingTo;

  final VoidCallback onPrintReport;
  final VoidCallback onExportPdf;
  final VoidCallback onExportCsv;
  final VoidCallback onOpenExportFolder;
  final VoidCallback onRefresh;
  final ValueChanged<int?> onEntryAccountChanged;
  final ValueChanged<String> onPaymentMethodChanged;
  final VoidCallback onAddExpense;
  final VoidCallback onPickFromDate;
  final VoidCallback onPickToDate;
  final VoidCallback onClearDateFilters;
  final ValueChanged<bool> onToggleReversals;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int?> onFilterAccountChanged;
  final ValueChanged<int> onSortChanged;
  final ValueChanged<int> onPageSizeChanged;
  final ValueChanged<ExpenseRecord> onEditExpense;
  final ValueChanged<ExpenseRecord> onDeleteExpense;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;
  final String Function(double value) formatMoney;
  final String Function(String raw) compactErrorMessage;

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      isCompact: isCompact,
      child: Column(
        children: [
          ExpensesHeaderSection(
            isCompact: isCompact,
            loading: loading,
            printing: printing,
            exportingPdf: exportingPdf,
            exportingCsv: exportingCsv,
            lastExportPath: lastExportPath,
            onPrintReport: onPrintReport,
            onExportPdf: onExportPdf,
            onExportCsv: onExportCsv,
            onOpenExportFolder: onOpenExportFolder,
            onRefresh: onRefresh,
          ),
          const SizedBox(height: 10),
          ExpensesEntrySection(
            isCompact: isCompact,
            posting: posting,
            expenseAccounts: expenseAccounts,
            selectedEntryExpenseAccountId: selectedEntryExpenseAccountId,
            amountController: amountController,
            paymentMethod: paymentMethod,
            notesController: notesController,
            onEntryAccountChanged: onEntryAccountChanged,
            onPaymentMethodChanged: onPaymentMethodChanged,
            onAddExpense: onAddExpense,
          ),
          const SizedBox(height: 10),
          ExpensesFiltersSection(
            isCompact: isCompact,
            fromDate: fromDate,
            toDate: toDate,
            showReversals: showReversals,
            searchController: searchController,
            selectedFilterExpenseAccountId: selectedFilterExpenseAccountId,
            sortIndex: sortIndex,
            pageSize: pageSize,
            expenseAccounts: expenseAccounts,
            grossTotal: grossTotal,
            netTotal: netTotal,
            onPickFromDate: onPickFromDate,
            onPickToDate: onPickToDate,
            onClearDateFilters: onClearDateFilters,
            onToggleReversals: onToggleReversals,
            onSearchChanged: onSearchChanged,
            onFilterAccountChanged: onFilterAccountChanged,
            onSortChanged: onSortChanged,
            onPageSizeChanged: onPageSizeChanged,
            formatMoney: formatMoney,
          ),
          const SizedBox(height: 10),
          ExpensesRecordsSection(
            loading: loading,
            posting: posting,
            error: error,
            records: records,
            onEditExpense: onEditExpense,
            onDeleteExpense: onDeleteExpense,
            formatMoney: formatMoney,
            compactErrorMessage: compactErrorMessage,
          ),
          const SizedBox(height: 8),
          ExpensesPaginationSection(
            safePage: safePage,
            totalPages: totalPages,
            showingFrom: showingFrom,
            showingTo: showingTo,
            totalCount: totalCount,
            onPreviousPage: onPreviousPage,
            onNextPage: onNextPage,
          ),
        ],
      ),
    );
  }
}
