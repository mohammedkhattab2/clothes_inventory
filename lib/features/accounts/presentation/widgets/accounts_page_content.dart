import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:clothes_inventory/core/widgets/app_empty_state.dart';
import 'package:clothes_inventory/core/widgets/app_error_banner.dart';
import 'package:clothes_inventory/core/widgets/app_inline_loading_indicator.dart';
import 'package:clothes_inventory/core/widgets/app_loading_indicator.dart';
import 'package:clothes_inventory/core/widgets/app_page_shell.dart';
import 'package:clothes_inventory/features/accounts/data/accounts_repository.dart';

class AccountsPageContent extends StatelessWidget {
  const AccountsPageContent({
    required this.isCompact,
    required this.isDenseViewport,
    required this.itemsFuture,
    required this.amountController,
    required this.searchController,
    required this.selectedAccountId,
    required this.selectedMethod,
    required this.searchQuery,
    required this.typeFilterIndex,
    required this.balanceFilterIndex,
    required this.sortAscending,
    required this.sortLabel,
    required this.posting,
    required this.postError,
    required this.amountInputError,
    required this.onQuickAddAccount,
    required this.onSettlement,
    required this.onRefreshAccounts,
    required this.onSelectedAccountChanged,
    required this.onAmountChanged,
    required this.onSelectedMethodChanged,
    required this.onPostStandalonePayment,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onTypeFilterChanged,
    required this.onBalanceFilterChanged,
    required this.onToggleSortKey,
    required this.onToggleSortAscending,
    required this.visibleAccountsBuilder,
    required this.displayBalance,
    required this.favorBalance,
    required this.onOpenStatement,
    required this.onCopyAccountName,
    required this.onCopyAccountBalance,
    required this.onCopyAccountsCsv,
    super.key,
  });

  final bool isCompact;
  final bool isDenseViewport;
  final Future<List<AccountSummary>> itemsFuture;
  final TextEditingController amountController;
  final TextEditingController searchController;
  final int? selectedAccountId;
  final String selectedMethod;
  final String searchQuery;
  final int typeFilterIndex;
  final int balanceFilterIndex;
  final bool sortAscending;
  final String sortLabel;
  final bool posting;
  final String? postError;
  final String? amountInputError;

  final VoidCallback onQuickAddAccount;
  final VoidCallback onSettlement;
  final VoidCallback onRefreshAccounts;
  final ValueChanged<int?> onSelectedAccountChanged;
  final ValueChanged<String> onAmountChanged;
  final ValueChanged<String> onSelectedMethodChanged;
  final VoidCallback onPostStandalonePayment;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<int> onTypeFilterChanged;
  final ValueChanged<int> onBalanceFilterChanged;
  final VoidCallback onToggleSortKey;
  final VoidCallback onToggleSortAscending;

  final List<AccountSummary> Function(List<AccountSummary>)
  visibleAccountsBuilder;
  final double Function(AccountSummary item) displayBalance;
  final double Function(AccountSummary item) favorBalance;

  final ValueChanged<int> onOpenStatement;
  final ValueChanged<String> onCopyAccountName;
  final ValueChanged<double> onCopyAccountBalance;
  final ValueChanged<List<AccountSummary>> onCopyAccountsCsv;

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      isCompact: isCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Accounts & Ledger'.tr(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Balances are derived from ledger transactions only.'.tr(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: isDenseViewport ? 10 : 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primary,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onPressed: onQuickAddAccount,
                    icon: Icon(
                      Icons.person_add_alt_1_outlined,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    label: Text(
                      'Add Account'.tr(),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.primary,
                      side: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onPressed: onSettlement,
                    icon: Icon(
                      Icons.balance_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    label: Text(
                      'Settlement'.tr(),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<AccountSummary>>(
            future: itemsFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return AppErrorBanner(
                  message: snapshot.error.toString(),
                  onRetry: onRefreshAccounts,
                  retryLabel: 'Refresh'.tr(),
                );
              }

              final accounts = snapshot.data ?? const <AccountSummary>[];
              final accountField = DropdownButtonFormField<int>(
                initialValue: selectedAccountId,
                decoration: InputDecoration(
                  labelText: 'Standalone Payment Account'.tr(),
                ),
                items: accounts
                    .map(
                      (a) => DropdownMenuItem<int>(
                        value: a.id,
                        child: Text('${a.name} (${a.accountType})'),
                      ),
                    )
                    .toList(),
                onChanged: onSelectedAccountChanged,
              );

              final amountField = TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩.,٫٬-]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Amount'.tr(),
                  errorText: amountInputError,
                ),
                onChanged: onAmountChanged,
              );

              final methodField = DropdownButtonFormField<String>(
                initialValue: selectedMethod,
                decoration: InputDecoration(labelText: 'Method'.tr()),
                items: [
                  DropdownMenuItem(value: 'cash', child: Text('Cash'.tr())),
                  DropdownMenuItem(
                    value: 'vodafone_cash',
                    child: Text('Vodafone Cash'.tr()),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    onSelectedMethodChanged(value);
                  }
                },
              );

              final postButton = FilledButton.icon(
                onPressed: posting ? null : onPostStandalonePayment,
                icon: posting
                    ? const AppInlineLoadingIndicator()
                    : const Icon(Icons.payments_outlined),
                label: Text('Post'.tr()),
              );

              return AppSectionPanel(
                child: Column(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 900;
                        if (compact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              accountField,
                              const SizedBox(height: 8),
                              amountField,
                              const SizedBox(height: 8),
                              methodField,
                              const SizedBox(height: 8),
                              postButton,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: accountField),
                            const SizedBox(width: 8),
                            Expanded(child: amountField),
                            const SizedBox(width: 8),
                            Expanded(child: methodField),
                            const SizedBox(width: 8),
                            postButton,
                          ],
                        );
                      },
                    ),
                    if (postError != null) ...[
                      const SizedBox(height: 8),
                      AppErrorBanner(
                        message: postError!,
                        onRetry: onPostStandalonePayment,
                        retryLabel: 'Post'.tr(),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          AppSectionPanel(
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    labelText: 'Search by name'.tr(),
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    suffixIcon: searchQuery.isEmpty
                        ? null
                        : IconButton(
                            onPressed: onClearSearch,
                            icon: const Icon(Icons.close),
                          ),
                  ),
                  onChanged: onSearchChanged,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ChoiceChip(
                      selected: typeFilterIndex == 0,
                      label: Text('All'.tr()),
                      onSelected: (_) => onTypeFilterChanged(0),
                    ),
                    ChoiceChip(
                      selected: typeFilterIndex == 1,
                      label: Text('Customer'.tr()),
                      onSelected: (_) => onTypeFilterChanged(1),
                    ),
                    ChoiceChip(
                      selected: typeFilterIndex == 2,
                      label: Text('Supplier'.tr()),
                      onSelected: (_) => onTypeFilterChanged(2),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      selected: balanceFilterIndex == 0,
                      label: Text('Any Balance'.tr()),
                      onSelected: (_) => onBalanceFilterChanged(0),
                    ),
                    ChoiceChip(
                      selected: balanceFilterIndex == 1,
                      label: Text('Positive'.tr()),
                      onSelected: (_) => onBalanceFilterChanged(1),
                    ),
                    ChoiceChip(
                      selected: balanceFilterIndex == 2,
                      label: Text('Negative'.tr()),
                      onSelected: (_) => onBalanceFilterChanged(2),
                    ),
                    ChoiceChip(
                      selected: balanceFilterIndex == 3,
                      label: Text('Zero'.tr()),
                      onSelected: (_) => onBalanceFilterChanged(3),
                    ),
                    OutlinedButton.icon(
                      onPressed: onRefreshAccounts,
                      icon: const Icon(Icons.refresh),
                      label: Text('Refresh'.tr()),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: onToggleSortKey,
                      icon: Icon(
                        sortAscending
                            ? Icons.north_rounded
                            : Icons.south_rounded,
                      ),
                      label: Text(sortLabel),
                    ),
                    IconButton(
                      tooltip: 'Toggle sort direction'.tr(),
                      onPressed: onToggleSortAscending,
                      icon: Icon(
                        sortAscending
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<AccountSummary>>(
              future: itemsFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: AppErrorBanner(
                        message: snapshot.error.toString(),
                        onRetry: onRefreshAccounts,
                        retryLabel: 'Refresh'.tr(),
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return AppLoadingIndicator(label: 'Loading accounts...'.tr());
                }

                final items = visibleAccountsBuilder(snapshot.data!);
                if (items.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'No accounts found.'.tr(),
                  );
                }

                final customerCount = items
                    .where((item) => item.accountType == 'customer')
                    .length;
                final supplierCount = items
                    .where((item) => item.accountType == 'supplier')
                    .length;

                final positiveTotal = items.fold<double>(0, (sum, item) {
                  final displayed = displayBalance(item);
                  return displayed > 0 ? sum + displayed : sum;
                });
                final negativeTotal = items.fold<double>(0, (sum, item) {
                  final displayed = displayBalance(item);
                  return displayed < 0 ? sum + displayed : sum;
                });
                final netTotal = items.fold<double>(
                  0,
                  (sum, item) => sum + displayBalance(item),
                );

                return Column(
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _StatChip(label: 'Accounts'.tr(), value: items.length),
                        _StatChip(label: 'Customer'.tr(), value: customerCount),
                        _StatChip(label: 'Supplier'.tr(), value: supplierCount),
                        _MoneyChip(
                          label: 'Positive Total'.tr(),
                          amount: positiveTotal,
                          color: Colors.green.shade700,
                        ),
                        _MoneyChip(
                          label: 'Negative Total'.tr(),
                          amount: negativeTotal,
                          color: Colors.red.shade700,
                        ),
                        _MoneyChip(
                          label: 'Net Total'.tr(),
                          amount: netTotal,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => onCopyAccountsCsv(items),
                          icon: const Icon(Icons.table_view_outlined),
                          label: Text('Copy CSV'.tr()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final isCustomer = item.accountType == 'customer';
                            final displayedBalance = displayBalance(item);
                            final directionBalance = favorBalance(item);
                            final color = directionBalance < 0
                                ? Colors.red.shade700
                                : (directionBalance > 0
                                      ? Colors.green.shade700
                                      : Theme.of(context).colorScheme.outline);

                            return ListTile(
                              dense: true,
                              onTap: () => onOpenStatement(item.id),
                              leading: Icon(
                                isCustomer
                                    ? Icons.person_outline
                                    : Icons.business_outlined,
                              ),
                              title: Text(item.name),
                              subtitle: Text(
                                '${'Type'.tr()}: ${isCustomer ? 'Customer'.tr() : 'Supplier'.tr()}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    displayedBalance.toStringAsFixed(2),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: color,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                  ),
                                  PopupMenuButton<String>(
                                    tooltip: 'Actions'.tr(),
                                    onSelected: (value) async {
                                      if (value == 'open_statement') {
                                        onOpenStatement(item.id);
                                        return;
                                      }
                                      if (value == 'copy_name') {
                                        onCopyAccountName(item.name);
                                        return;
                                      }
                                      if (value == 'copy_balance') {
                                        onCopyAccountBalance(displayedBalance);
                                      }
                                    },
                                    itemBuilder: (menuContext) => [
                                      PopupMenuItem<String>(
                                        value: 'open_statement',
                                        child: Text('Open Statement'.tr()),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'copy_name',
                                        child: Text('Copy Name'.tr()),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'copy_balance',
                                        child: Text('Copy Balance'.tr()),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MoneyChip extends StatelessWidget {
  const _MoneyChip({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.12),
            colorScheme.surfaceContainerHigh,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label: ${amount.toStringAsFixed(2)}',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
