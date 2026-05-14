import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:clothes_inventory/core/widgets/app_brand_header.dart';
import 'package:clothes_inventory/core/widgets/app_empty_state.dart';
import 'package:clothes_inventory/core/widgets/app_error_banner.dart';
import 'package:clothes_inventory/core/widgets/app_loading_indicator.dart';
import 'package:clothes_inventory/core/widgets/app_page_shell.dart';
import 'package:clothes_inventory/features/accounts/data/accounts_repository.dart';
import 'package:clothes_inventory/features/dashboard/data/dashboard_repository.dart';
import 'package:clothes_inventory/services/di/service_locator.dart';

class AccountSettlementPage extends StatelessWidget {
  const AccountSettlementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AccountSettlementView();
  }
}

class _AccountSettlementView extends StatefulWidget {
  const _AccountSettlementView();

  @override
  State<_AccountSettlementView> createState() => _AccountSettlementViewState();
}

class _AccountSettlementViewState extends State<_AccountSettlementView> {
  late Future<List<AccountSummary>> _itemsFuture;
  final _searchController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final AccountsRepository _repo = getIt<AccountsRepository>();

  int? _selectedAccountId;
  int? _selectedInvoiceId;
  List<SettlementInvoiceOption> _selectedInvoices =
      const <SettlementInvoiceOption>[];
  _SettlementTypeFilter _typeFilter = _SettlementTypeFilter.all;
  String _searchQuery = '';
  String _selectedMethod = 'cash';
  bool _posting = false;
  bool _loadingInvoices = false;
  String? _error;

  double _signedAmountForAccount(
    AccountSummary account,
    double inputAbsAmount,
  ) {
    final normalized = inputAbsAmount.abs();
    return account.balance >= 0 ? normalized : -normalized;
  }

  @override
  void initState() {
    super.initState();
    _itemsFuture = getIt<AccountsRepository>()
        .getAccountSummariesWithTransactionsOnly();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoicesForAccount(int accountId) async {
    setState(() {
      _loadingInvoices = true;
      _selectedInvoices = const <SettlementInvoiceOption>[];
      _selectedInvoiceId = null;
    });

    try {
      final invoices = await _repo.listOutstandingInvoices(accountId);
      if (!mounted) return;
      setState(() {
        _selectedInvoices = invoices;
        _selectedInvoiceId = invoices.isEmpty ? null : invoices.first.id;
        if (invoices.isNotEmpty) {
          _amountController.text = invoices.first.outstanding.toStringAsFixed(
            2,
          );
        }
        _loadingInvoices = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingInvoices = false;
      });
    }
  }

  SettlementInvoiceOption? _selectedInvoice() {
    final id = _selectedInvoiceId;
    if (id == null) return null;
    for (final invoice in _selectedInvoices) {
      if (invoice.id == id) {
        return invoice;
      }
    }
    return null;
  }

  Future<void> _refresh() async {
    setState(() {
      _itemsFuture = getIt<AccountsRepository>()
          .getAccountSummariesWithTransactionsOnly();
    });
  }

  double? _parseFlexibleNumber(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    const arabicIndicDigits = {
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
    };

    var normalized = trimmed;
    arabicIndicDigits.forEach((key, value) {
      normalized = normalized.replaceAll(key, value);
    });

    normalized = normalized
        .replaceAll('٬', '')
        .replaceAll('٫', '.')
        .replaceAll(',', '.');

    return double.tryParse(normalized);
  }

  List<AccountSummary> _visibleItems(List<AccountSummary> source) {
    return source.where((item) {
      final isSupportedType =
          item.accountType == 'customer' || item.accountType == 'supplier';
      if (!isSupportedType) {
        return false;
      }

      final hasOutstandingBalance = item.balance.abs() > 0.000001;
      if (!hasOutstandingBalance) {
        return false;
      }

      final matchSearch =
          _searchQuery.isEmpty ||
          item.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchType = switch (_typeFilter) {
        _SettlementTypeFilter.all => true,
        _SettlementTypeFilter.customer => item.accountType == 'customer',
        _SettlementTypeFilter.supplier => item.accountType == 'supplier',
      };
      return matchSearch && matchType;
    }).toList();
  }

  Future<void> _settle(AccountSummary selected, {double? customAmount}) async {
    final amount = customAmount ?? selected.balance;
    if (amount == 0) {
      setState(() {
        _error = 'Account is already settled.'.tr();
      });
      return;
    }

    setState(() {
      _posting = true;
      _error = null;
    });

    try {
      await _repo.createStandalonePayment(
        accountId: selected.id,
        amount: amount,
        paymentMethod: _selectedMethod,
        targetInvoiceId: _selectedInvoiceId,
        notes: _noteController.text.trim().isEmpty
            ? '${'Settlement'.tr()} - ${selected.name}'
            : _noteController.text.trim(),
      );
      getIt<DashboardRepository>().invalidateSnapshotCache();
      if (!mounted) return;

      _amountController.clear();
      await _refresh();
      await _loadInvoicesForAccount(selected.id);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Settlement posted successfully.'.tr())),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _posting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 960;

    return AppPageShell(
      isCompact: isCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionPanel(
            emphasis: true,
            child: AppBrandHeader(
              pageTitle: 'Account Settlement'.tr(),
              description:
                  'Settle customer and supplier balances to zero with one step.'
                      .tr(),
              actions: [
                // Add actions here if needed, similar to AccountsPageContent
              ],
              isDense: isCompact,
            ),
          ),
          const SizedBox(height: 8),
          AppSectionPanel(
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search by name'.tr(),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                  onChanged: (value) =>
                      setState(() => _searchQuery = value.trim()),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      selected: _typeFilter == _SettlementTypeFilter.all,
                      onSelected: (_) => setState(
                        () => _typeFilter = _SettlementTypeFilter.all,
                      ),
                      label: Text('All'.tr()),
                    ),
                    ChoiceChip(
                      selected: _typeFilter == _SettlementTypeFilter.customer,
                      onSelected: (_) => setState(
                        () => _typeFilter = _SettlementTypeFilter.customer,
                      ),
                      label: Text('Customer'.tr()),
                    ),
                    ChoiceChip(
                      selected: _typeFilter == _SettlementTypeFilter.supplier,
                      onSelected: (_) => setState(
                        () => _typeFilter = _SettlementTypeFilter.supplier,
                      ),
                      label: Text('Supplier'.tr()),
                    ),
                    OutlinedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: Text('Refresh'.tr()),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<AccountSummary>>(
              future: _itemsFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return AppErrorBanner(
                    message: snapshot.error.toString(),
                    onRetry: _refresh,
                    retryLabel: 'Refresh'.tr(),
                  );
                }

                if (!snapshot.hasData) {
                  return AppLoadingIndicator(label: 'Loading accounts...'.tr());
                }

                final items = _visibleItems(snapshot.data!);
                if (items.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'No outstanding customer/supplier balances.'.tr(),
                    compact: true,
                  );
                }

                AccountSummary? selected;
                for (final item in items) {
                  if (item.id == _selectedAccountId) {
                    selected = item;
                    break;
                  }
                }

                selected ??= items.first;
                final selectedAccount = selected;
                if (_selectedAccountId != selectedAccount.id) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() {
                      _selectedAccountId = selectedAccount.id;
                    });
                    _loadInvoicesForAccount(selectedAccount.id);
                  });
                }

                final toneColor = selectedAccount.balance == 0
                    ? Colors.grey.shade700
                    : (selectedAccount.balance > 0
                          ? Colors.red.shade700
                          : Colors.green.shade700);
                final outstandingAbs = selectedAccount.balance.abs();
                final entered = _parseFlexibleNumber(_amountController.text);
                final enteredAbs = (entered ?? 0).abs();
                final remainingAbs = enteredAbs >= outstandingAbs
                    ? 0.0
                    : outstandingAbs - enteredAbs;
                final showRemaining =
                    entered != null && enteredAbs > 0 && outstandingAbs > 0;

                return Row(
                  children: [
                    Expanded(
                      flex: 3,
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
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final chosen = item.id == _selectedAccountId;
                            return ListTile(
                              selected: chosen,
                              selectedTileColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.35),
                              dense: true,
                              title: Text(item.name),
                              subtitle: Text(
                                '${'Type'.tr()}: ${item.accountType == 'customer' ? 'Customer'.tr() : 'Supplier'.tr()}',
                              ),
                              trailing: Text(
                                item.balance.toStringAsFixed(2),
                                style: TextStyle(
                                  color: item.balance == 0
                                      ? Colors.grey.shade700
                                      : (item.balance > 0
                                            ? Colors.red.shade700
                                            : Colors.green.shade700),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedAccountId = item.id;
                                  _amountController.text = item.balance
                                      .abs()
                                      .toStringAsFixed(2);
                                  _error = null;
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: AppSectionPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedAccount.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${'Current Balance'.tr()}: ${selectedAccount.balance.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: toneColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            if (_loadingInvoices)
                              const LinearProgressIndicator(minHeight: 2),
                            if (_selectedInvoices.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              DropdownButtonFormField<int>(
                                initialValue: _selectedInvoiceId,
                                decoration: InputDecoration(
                                  labelText: 'Target Invoice'.tr(),
                                ),
                                items: _selectedInvoices
                                    .map(
                                      (invoice) => DropdownMenuItem<int>(
                                        value: invoice.id,
                                        child: Text(
                                          '${invoice.invoiceNumber} | ${'Outstanding'.tr()}: ${invoice.outstanding.toStringAsFixed(2)}',
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged: _posting
                                    ? null
                                    : (value) {
                                        if (value == null) {
                                          return;
                                        }
                                        SettlementInvoiceOption?
                                        selectedInvoice;
                                        for (final invoice
                                            in _selectedInvoices) {
                                          if (invoice.id == value) {
                                            selectedInvoice = invoice;
                                            break;
                                          }
                                        }
                                        setState(() {
                                          _selectedInvoiceId = value;
                                          if (selectedInvoice != null) {
                                            _amountController.text =
                                                selectedInvoice.outstanding
                                                    .toStringAsFixed(2);
                                          }
                                        });
                                      },
                              ),
                            ],
                            TextField(
                              controller: _amountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: false,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9٠-٩.,٫٬]'),
                                ),
                              ],
                              decoration: InputDecoration(
                                labelText: 'Settlement Amount'.tr(),
                                hintText: selectedAccount.balance
                                    .abs()
                                    .toStringAsFixed(2),
                              ),
                            ),
                            if (showRemaining) ...[
                              const SizedBox(height: 6),
                              Text(
                                '${'Remaining After Posting'.tr()}: ${remainingAbs.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedMethod,
                              decoration: InputDecoration(
                                labelText: 'Method'.tr(),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'cash',
                                  child: Text('Cash'.tr()),
                                ),
                                DropdownMenuItem(
                                  value: 'vodafone_cash',
                                  child: Text('Vodafone Cash'.tr()),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _selectedMethod = value);
                                }
                              },
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _noteController,
                              decoration: InputDecoration(
                                labelText: 'Notes (optional)'.tr(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.icon(
                                  onPressed: _posting
                                      ? null
                                      : () => _settle(selectedAccount),
                                  icon: const Icon(Icons.balance_outlined),
                                  label: Text('Settle to Zero'.tr()),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _posting
                                      ? null
                                      : () {
                                          _amountController.text =
                                              selectedAccount.balance
                                                  .abs()
                                                  .toStringAsFixed(2);
                                          setState(() {
                                            _error = null;
                                          });
                                        },
                                  icon: const Icon(
                                    Icons.auto_fix_high_outlined,
                                  ),
                                  label: Text('Use Suggested Amount'.tr()),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed: _posting
                                      ? null
                                      : () {
                                          final parsed = _parseFlexibleNumber(
                                            _amountController.text,
                                          );
                                          final parsedAbs = (parsed ?? 0).abs();
                                          if (parsedAbs == 0) {
                                            setState(() {
                                              _error = 'Enter a valid amount.'
                                                  .tr();
                                            });
                                            return;
                                          }

                                          if (selectedAccount.balance == 0) {
                                            setState(() {
                                              _error =
                                                  'Account is already settled.'
                                                      .tr();
                                            });
                                            return;
                                          }

                                          final selectedInvoice =
                                              _selectedInvoice();
                                          if (selectedInvoice != null &&
                                              parsedAbs >
                                                  selectedInvoice.outstanding +
                                                      0.000001) {
                                            setState(() {
                                              _error =
                                                  'Amount cannot exceed selected invoice outstanding.'
                                                      .tr();
                                            });
                                            return;
                                          }

                                          if (parsedAbs >
                                              selectedAccount.balance.abs()) {
                                            setState(() {
                                              _error =
                                                  'Amount cannot exceed outstanding balance.'
                                                      .tr();
                                            });
                                            return;
                                          }

                                          _settle(
                                            selectedAccount,
                                            customAmount:
                                                _signedAmountForAccount(
                                                  selectedAccount,
                                                  parsedAbs,
                                                ),
                                          );
                                        },
                                  icon: const Icon(Icons.payments_outlined),
                                  label: Text('Post Custom Settlement'.tr()),
                                ),
                              ],
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 10),
                              AppErrorBanner(message: _error!),
                            ],
                          ],
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

enum _SettlementTypeFilter { all, customer, supplier }
