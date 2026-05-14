import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:clothes_inventory/core/widgets/app_error_banner.dart';
import 'package:clothes_inventory/core/widgets/app_inline_loading_indicator.dart';
import 'package:clothes_inventory/features/accounts/data/accounts_repository.dart';
import 'package:clothes_inventory/features/accounts/presentation/widgets/accounts_page_content.dart';
import 'package:clothes_inventory/services/di/service_locator.dart';

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AccountsView();
  }
}

class _AccountsView extends StatefulWidget {
  const _AccountsView();

  @override
  State<_AccountsView> createState() => _AccountsViewState();
}

class _AccountsViewState extends State<_AccountsView> {
  late Future<List<AccountSummary>> _itemsFuture;
  final _amountController = TextEditingController();
  final _searchController = TextEditingController();
  int? _selectedAccountId;
  String _selectedMethod = 'cash';
  String _searchQuery = '';
  _AccountTypeFilter _typeFilter = _AccountTypeFilter.all;
  _BalanceFilter _balanceFilter = _BalanceFilter.all;
  _AccountSortKey _sortKey = _AccountSortKey.balance;
  bool _sortAscending = false;
  bool _posting = false;
  String? _postError;
  String? _amountInputError;

  @override
  void initState() {
    super.initState();
    _itemsFuture = getIt<AccountsRepository>()
        .getAccountSummariesWithTransactionsOnly();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _refreshAccounts() {
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

  Future<void> _postStandalonePayment() async {
    final accountId = _selectedAccountId;
    final amount = _parseFlexibleNumber(_amountController.text);

    if (accountId == null) {
      setState(() {
        _postError = 'Select an account.'.tr();
      });
      return;
    }

    if (amount == null || amount == 0) {
      setState(() {
        _amountInputError = 'Enter a valid amount.'.tr();
        _postError = 'Enter a valid amount.'.tr();
      });
      return;
    }

    setState(() {
      _posting = true;
      _postError = null;
    });

    try {
      await getIt<AccountsRepository>().createStandalonePayment(
        accountId: accountId,
        amount: amount,
        paymentMethod: _selectedMethod,
      );
      if (!mounted) return;
      setState(() {
        _amountController.clear();
        _amountInputError = null;
      });
      _refreshAccounts();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment posted successfully.'.tr())),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _postError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _posting = false;
        });
      }
    }
  }

  Future<void> _showQuickAddAccountDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    var accountType = 'customer';
    String? formError;
    var saving = false;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        final veryDense = MediaQuery.sizeOf(dialogContext).height < 720;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog.fullscreen(
              child: Scaffold(
                appBar: AppBar(
                  title: Text('Add Account'.tr()),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                    ),
                  ],
                ),
                body: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          margin: EdgeInsets.zero,
                          color: colorScheme.surfaceContainerLow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: colorScheme.outlineVariant),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(veryDense ? 12 : 16),
                            child: Column(
                              children: [
                                TextField(
                                  controller: nameController,
                                  decoration: InputDecoration(
                                    labelText: 'Account Name'.tr(),
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                                SizedBox(height: veryDense ? 10 : 16),
                                DropdownButtonFormField<String>(
                                  initialValue: accountType,
                                  decoration: InputDecoration(
                                    labelText: 'Account Type'.tr(),
                                    border: const OutlineInputBorder(),
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: 'customer',
                                      child: Text('Customer'.tr()),
                                    ),
                                    DropdownMenuItem(
                                      value: 'supplier',
                                      child: Text('Supplier'.tr()),
                                    ),
                                    DropdownMenuItem(
                                      value: 'expense',
                                      child: Text('Expense'.tr()),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setDialogState(() => accountType = value);
                                    }
                                  },
                                ),
                                SizedBox(height: veryDense ? 10 : 16),
                                TextField(
                                  controller: phoneController,
                                  decoration: InputDecoration(
                                    labelText: 'Phone'.tr(),
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                                SizedBox(height: veryDense ? 10 : 16),
                                TextField(
                                  controller: addressController,
                                  maxLines: 2,
                                  decoration: InputDecoration(
                                    labelText: 'Address'.tr(),
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (formError != null) ...[
                          SizedBox(height: veryDense ? 10 : 16),
                          AppErrorBanner(message: formError!),
                        ],
                      ],
                    ),
                  ),
                ),
                bottomNavigationBar: Padding(
                  padding: EdgeInsets.all(veryDense ? 12 : 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: saving
                            ? null
                            : () => Navigator.of(dialogContext).pop(false),
                        icon: const Icon(Icons.close_outlined),
                        label: Text('Cancel'.tr()),
                      ),
                      SizedBox(width: veryDense ? 10 : 16),
                      FilledButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                final name = nameController.text.trim();
                                if (name.isEmpty) {
                                  setDialogState(
                                    () => formError = 'Name is required.'.tr(),
                                  );
                                  return;
                                }

                                setDialogState(() {
                                  saving = true;
                                  formError = null;
                                });

                                try {
                                  await getIt<AccountsRepository>()
                                      .createAccount(
                                        name: name,
                                        accountType: accountType,
                                        phone:
                                            phoneController.text.trim().isEmpty
                                            ? null
                                            : phoneController.text.trim(),
                                        address:
                                            addressController.text
                                                .trim()
                                                .isEmpty
                                            ? null
                                            : addressController.text.trim(),
                                      );
                                  if (!dialogContext.mounted) return;
                                  Navigator.of(dialogContext).pop(true);
                                } catch (e) {
                                  setDialogState(() {
                                    saving = false;
                                    formError = e.toString();
                                  });
                                }
                              },
                        icon: saving
                            ? const AppInlineLoadingIndicator()
                            : const Icon(Icons.add_rounded),
                        label: Text('Add'.tr()),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();

    if (created == true && mounted) {
      _refreshAccounts();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Account created successfully.'.tr())),
      );
    }
  }

  double _displayBalance(AccountSummary item) {
    return _favorBalance(item);
  }

  double _favorBalance(AccountSummary item) {
    // Positive means money in our favor, negative means money against us.
    return item.accountType == 'supplier' ? -item.balance : item.balance;
  }

  List<AccountSummary> _visibleAccounts(List<AccountSummary> source) {
    final filtered = source.where((item) {
      final matchSearch =
          _searchQuery.isEmpty ||
          item.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchType = switch (_typeFilter) {
        _AccountTypeFilter.all => true,
        _AccountTypeFilter.customer => item.accountType == 'customer',
        _AccountTypeFilter.supplier => item.accountType == 'supplier',
      };
      final matchBalance = switch (_balanceFilter) {
        _BalanceFilter.all => true,
        _BalanceFilter.positive => _displayBalance(item) > 0,
        _BalanceFilter.negative => _displayBalance(item) < 0,
        _BalanceFilter.zero => _displayBalance(item) == 0,
      };
      return matchSearch && matchType && matchBalance;
    }).toList();

    filtered.sort((a, b) {
      int cmp;
      switch (_sortKey) {
        case _AccountSortKey.name:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case _AccountSortKey.balance:
          cmp = _displayBalance(a).compareTo(_displayBalance(b));
          break;
      }

      if (cmp == 0) {
        cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      return _sortAscending ? cmp : -cmp;
    });
    return filtered;
  }

  void _toggleSortKey() {
    setState(() {
      _sortKey = _sortKey == _AccountSortKey.balance
          ? _AccountSortKey.name
          : _AccountSortKey.balance;
    });
  }

  String _sortLabel(BuildContext context) {
    return _sortKey == _AccountSortKey.balance
        ? 'Current Balance'.tr()
        : 'Name'.tr();
  }

  String _escapeCsvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    if (escaped.contains(',') ||
        escaped.contains('"') ||
        escaped.contains('\n')) {
      return '"$escaped"';
    }
    return escaped;
  }

  String _buildAccountsCsv(List<AccountSummary> items) {
    final buffer = StringBuffer();
    buffer.writeln('id,name,type,balance');
    for (final item in items) {
      buffer.writeln(
        '${item.id},${_escapeCsvCell(item.name)},${item.accountType},${_displayBalance(item).toStringAsFixed(2)}',
      );
    }
    return buffer.toString();
  }

  Future<void> _copyAccountsCsv(List<AccountSummary> items) async {
    final csv = _buildAccountsCsv(items);
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Accounts CSV copied to clipboard.'.tr())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 900;
    final isDenseViewport = size.height < 820 || size.width < 1180;
    return AccountsPageContent(
      isCompact: isCompact,
      isDenseViewport: isDenseViewport,
      itemsFuture: _itemsFuture,
      amountController: _amountController,
      searchController: _searchController,
      selectedAccountId: _selectedAccountId,
      selectedMethod: _selectedMethod,
      searchQuery: _searchQuery,
      typeFilterIndex: _typeFilter.index,
      balanceFilterIndex: _balanceFilter.index,
      sortAscending: _sortAscending,
      sortLabel: _sortLabel(context),
      posting: _posting,
      postError: _postError,
      amountInputError: _amountInputError,
      onQuickAddAccount: _showQuickAddAccountDialog,
      onSettlement: () => context.go('/accounts/settlement'),
      onRefreshAccounts: _refreshAccounts,
      onSelectedAccountChanged: (value) {
        setState(() => _selectedAccountId = value);
      },
      onAmountChanged: (value) {
        setState(() {
          final parsed = _parseFlexibleNumber(value);
          if (value.trim().isEmpty) {
            _amountInputError = null;
          } else if (parsed == null || parsed == 0) {
            _amountInputError = 'Enter a valid amount.'.tr();
          } else {
            _amountInputError = null;
            _postError = null;
          }
        });
      },
      onSelectedMethodChanged: (value) {
        setState(() => _selectedMethod = value);
      },
      onPostStandalonePayment: _postStandalonePayment,
      onSearchChanged: (value) {
        setState(() => _searchQuery = value.trim());
      },
      onClearSearch: () {
        _searchController.clear();
        setState(() => _searchQuery = '');
      },
      onTypeFilterChanged: (index) {
        setState(() => _typeFilter = _AccountTypeFilter.values[index]);
      },
      onBalanceFilterChanged: (index) {
        setState(() => _balanceFilter = _BalanceFilter.values[index]);
      },
      onToggleSortKey: _toggleSortKey,
      onToggleSortAscending: () {
        setState(() => _sortAscending = !_sortAscending);
      },
      visibleAccountsBuilder: _visibleAccounts,
      displayBalance: _displayBalance,
      favorBalance: _favorBalance,
      onOpenStatement: (id) => context.go('/accounts/statement/$id'),
      onCopyAccountName: (name) async {
        await Clipboard.setData(ClipboardData(text: name));
        if (!mounted) return;
        ScaffoldMessenger.of(
          this.context,
        ).showSnackBar(SnackBar(content: Text('Account name copied.'.tr())));
      },
      onCopyAccountBalance: (balance) async {
        await Clipboard.setData(
          ClipboardData(text: balance.toStringAsFixed(2)),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          this.context,
        ).showSnackBar(SnackBar(content: Text('Account balance copied.'.tr())));
      },
      onCopyAccountsCsv: _copyAccountsCsv,
    );
  }
}

enum _AccountTypeFilter { all, customer, supplier }

enum _BalanceFilter { all, positive, negative, zero }

enum _AccountSortKey { name, balance }
