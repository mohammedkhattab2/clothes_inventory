import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delta_erp/core/widgets/app_empty_state.dart';
import 'package:delta_erp/core/widgets/app_loading_indicator.dart';
import 'package:delta_erp/core/widgets/app_page_shell.dart';
import 'package:delta_erp/features/expenses/data/expenses_repository.dart';
import 'package:delta_erp/features/accounts/data/cash_box_repository.dart';
import 'package:delta_erp/features/purchases/data/purchases_repository.dart';
import 'package:delta_erp/features/sales/data/sales_repository.dart';
import 'package:delta_erp/services/di/service_locator.dart';

enum _InvoiceStatusFilter { all, completed, partial }

enum _QuickRange { today, thisWeek, thisMonth }

enum _CashFlowView { operational, financing }

enum _FinancingTypeFilter { all, capitalInjection, ownerWithdrawal, adjustment }

class StatementPage extends StatefulWidget {
  const StatementPage({super.key});

  @override
  State<StatementPage> createState() => _StatementPageState();
}

class _StatementPageState extends State<StatementPage> {
  final _salesRepo = getIt<SalesRepository>();
  final _purchasesRepo = getIt<PurchasesRepository>();
  final _cashBoxRepo = getIt<CashBoxRepository>();
  final _expensesRepo = getIt<ExpensesRepository>();

  final _salesSearchController = TextEditingController();
  final _purchasesSearchController = TextEditingController();

  bool _loading = false;
  String? _error;
  DateTime? _fromDate;
  DateTime? _toDate;
  _InvoiceStatusFilter _salesStatusFilter = _InvoiceStatusFilter.all;
  _InvoiceStatusFilter _purchasesStatusFilter = _InvoiceStatusFilter.all;
  _CashFlowView _cashFlowView = _CashFlowView.operational;
  _FinancingTypeFilter _financingTypeFilter = _FinancingTypeFilter.all;
  bool _showAdvancedFilters = false;

  List<SalesInvoiceSummary> _salesRows = const <SalesInvoiceSummary>[];
  List<PurchaseInvoiceSummary> _purchaseRows = const <PurchaseInvoiceSummary>[];
  List<ExpenseRecord> _expenseRows = const <ExpenseRecord>[];
  List<StandaloneCashMovement> _standaloneRows =
      const <StandaloneCashMovement>[];
  double _expensePaymentsTotal = 0;

  double _rawOpeningBalance = 0;
  double _openingBalance = 0;
  double _standaloneInTotal = 0;
  double _standaloneOutTotal = 0;

  String _formatMoney(BuildContext context, double value) {
    final locale = context.locale;
    final localeName = locale.countryCode == null || locale.countryCode!.isEmpty
        ? locale.languageCode
        : '${locale.languageCode}_${locale.countryCode}';
    final formatter = NumberFormat.currency(
      locale: localeName,
      symbol: '',
      decimalDigits: 2,
    );
    return formatter.format(value).trim();
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _salesSearchController.dispose();
    _purchasesSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await Future.wait([
        _salesRepo.listInvoices(
          fromDate: _fromDate,
          toDate: _toDate,
          limit: 1000,
        ),
        _purchasesRepo.listInvoices(
          fromDate: _fromDate,
          toDate: _toDate,
          limit: 1000,
        ),
        _expensesRepo.listExpenses(
          fromDate: _fromDate,
          toDate: _toDate,
          limit: 1000,
        ),
        _cashBoxRepo.listStandaloneMovements(
          fromDate: _fromDate,
          toDate: _toDate,
          limit: 1000,
        ),
      ]);

      var rawOpening = 0.0;
      if (_fromDate != null) {
        final boundary = DateTime(
          _fromDate!.year,
          _fromDate!.month,
          _fromDate!.day,
        ).subtract(const Duration(days: 1));

        final openingRows = await Future.wait([
          _salesRepo.listInvoices(toDate: boundary, limit: 100000),
          _purchasesRepo.listInvoices(toDate: boundary, limit: 100000),
          _expensesRepo.listExpenses(toDate: boundary, limit: 100000),
          _cashBoxRepo.sumStandaloneNet(toDate: boundary),
        ]);

        final prevSales = openingRows[0] as List<SalesInvoiceSummary>;
        final prevPurchases = openingRows[1] as List<PurchaseInvoiceSummary>;
        final prevExpenses = (openingRows[2] as List<ExpenseRecord>)
            .fold<double>(0, (sum, item) => sum + item.amount);
        final prevIn = prevSales.fold<double>(
          0,
          (sum, item) => sum + item.paidAmount,
        );
        final prevOut = prevPurchases.fold<double>(
          0,
          (sum, item) => sum + item.paidAmount,
        );
        final prevStandaloneNet = (openingRows[3] as num).toDouble();
        rawOpening = prevIn - (prevOut + prevExpenses) + prevStandaloneNet;
      }

      final offset = await _cashBoxRepo.getOpeningBalanceOffset();
      final adjustedOpening = rawOpening - offset;
      final expenses = rows[2] as List<ExpenseRecord>;
      final expensesTotal = expenses.fold<double>(
        0,
        (sum, item) => sum + item.amount,
      );
      final standaloneRows = rows[3] as List<StandaloneCashMovement>;
      final standaloneInTotal = standaloneRows
          .where((row) => row.amount > 0)
          .fold<double>(0, (sum, row) => sum + row.amount);
      final standaloneOutTotal = standaloneRows
          .where((row) => row.amount < 0)
          .fold<double>(0, (sum, row) => sum + row.amount.abs());

      if (!mounted) return;
      setState(() {
        _salesRows = rows[0] as List<SalesInvoiceSummary>;
        _purchaseRows = rows[1] as List<PurchaseInvoiceSummary>;
        _expenseRows = expenses;
        _standaloneRows = standaloneRows;
        _expensePaymentsTotal = expensesTotal;
        _rawOpeningBalance = rawOpening;
        _openingBalance = adjustedOpening.abs() < 0.0001 ? 0 : adjustedOpening;
        _standaloneInTotal = standaloneInTotal;
        _standaloneOutTotal = standaloneOutTotal;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickFromDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() => _fromDate = picked);
    _loadData();
  }

  Future<void> _pickToDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() => _toDate = picked);
    _loadData();
  }

  void _applyQuickRange(_QuickRange range) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime from;
    DateTime to;

    switch (range) {
      case _QuickRange.today:
        from = today;
        to = today;
      case _QuickRange.thisWeek:
        from = today.subtract(Duration(days: today.weekday - 1));
        to = now;
      case _QuickRange.thisMonth:
        from = DateTime(now.year, now.month, 1);
        to = now;
    }

    setState(() {
      _fromDate = from;
      _toDate = to;
    });
    _loadData();
  }

  Future<void> _resetOpeningBalance() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        final veryDense = MediaQuery.sizeOf(dialogContext).height < 720;
        return AlertDialog(
          backgroundColor: colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          title: Text('Reset Opening Balance'.tr()),
          content: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: colorScheme.error.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              'This action cannot be undone.'.tr(),
              style: Theme.of(
                dialogContext,
              ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              icon: const Icon(Icons.close_outlined),
              label: Text('Cancel'.tr()),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.restart_alt),
              label: Text('Reset'.tr()),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.symmetric(
                  horizontal: veryDense ? 10 : 12,
                  vertical: veryDense ? 8 : 10,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _cashBoxRepo.setOpeningBalanceOffset(_rawOpeningBalance);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Opening balance reset.'.tr())));
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${'Save failed'.tr()}: $e')));
    }
  }

  Future<void> _setOpeningBalance() async {
    final amountController = TextEditingController(
      text: _openingBalance == 0 ? '' : _openingBalance.toStringAsFixed(2),
    );
    String? inputError;

    final desiredOpening = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              title: Text('Set Opening Balance'.tr()),
              content: SizedBox(
                width: math.min(
                  420,
                  MediaQuery.sizeOf(dialogContext).width * 0.9,
                ),
                child: TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Opening Balance'.tr(),
                    errorText: inputError,
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text('Cancel'.tr()),
                ),
                FilledButton(
                  onPressed: () {
                    final value = _parseFlexibleNumber(amountController.text);
                    if (value == null) {
                      setDialogState(() {
                        inputError = 'Enter a valid amount.'.tr();
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(value);
                  },
                  child: Text('Save Opening Balance'.tr()),
                ),
              ],
            );
          },
        );
      },
    );

    amountController.dispose();
    if (desiredOpening == null) return;

    try {
      final offset = _rawOpeningBalance - desiredOpening;
      await _cashBoxRepo.setOpeningBalanceOffset(offset);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Opening balance saved.'.tr())));
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${'Save failed'.tr()}: $e')));
    }
  }

  Future<void> _postOwnerMovement({required bool isInflow}) async {
    final amountController = TextEditingController();
    final notesController = TextEditingController(
      text: isInflow ? 'Capital Injection'.tr() : 'Owner Withdrawal'.tr(),
    );
    String method = 'cash';
    String? inputError;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              title: Text(
                isInflow
                    ? 'Add Owner Funding'.tr()
                    : 'Record Owner Withdrawal'.tr(),
              ),
              content: SizedBox(
                width: math.min(
                  460,
                  MediaQuery.sizeOf(dialogContext).width * 0.9,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Amount'.tr(),
                        errorText: inputError,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: method,
                      decoration: InputDecoration(labelText: 'Method'.tr()),
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
                          setDialogState(() => method = value);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesController,
                      decoration: InputDecoration(
                        labelText: 'Notes (optional)'.tr(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text('Cancel'.tr()),
                ),
                FilledButton(
                  onPressed: () {
                    final amount = _parseFlexibleNumber(amountController.text);
                    if (amount == null || amount <= 0) {
                      setDialogState(() {
                        inputError = 'Enter a valid amount.'.tr();
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: Text('Save'.tr()),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) {
      amountController.dispose();
      notesController.dispose();
      return;
    }

    try {
      final amount = _parseFlexibleNumber(amountController.text)!;
      await _cashBoxRepo.addStandaloneMovement(
        isInflow: isInflow,
        amount: amount,
        paymentMethod: method,
        notes: notesController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cash adjustment saved.'.tr())));
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${'Save failed'.tr()}: $e')));
    } finally {
      amountController.dispose();
      notesController.dispose();
    }
  }

  Widget _buildMoreActionsButton(BuildContext context) {
    return PopupMenuButton<String>(
      enabled: !_loading,
      tooltip: 'More actions'.tr(),
      onSelected: (value) {
        switch (value) {
          case 'set-opening':
            _setOpeningBalance();
            return;
          case 'capital-injection':
            _postOwnerMovement(isInflow: true);
            return;
          case 'owner-withdrawal':
            _postOwnerMovement(isInflow: false);
            return;
          case 'reset-opening':
            _resetOpeningBalance();
            return;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'set-opening',
          child: Row(
            children: [
              const Icon(Icons.edit_note_outlined, size: 18),
              const SizedBox(width: 8),
              Text('Set Opening Balance'.tr()),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'capital-injection',
          child: Row(
            children: [
              const Icon(Icons.add_card_outlined, size: 18),
              const SizedBox(width: 8),
              Text('Capital Injection'.tr()),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'owner-withdrawal',
          child: Row(
            children: [
              const Icon(Icons.money_off_csred_outlined, size: 18),
              const SizedBox(width: 8),
              Text('Owner Withdrawal'.tr()),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'reset-opening',
          child: Row(
            children: [
              const Icon(Icons.restart_alt, size: 18),
              const SizedBox(width: 8),
              Text('Reset Opening Balance'.tr()),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.more_horiz),
            const SizedBox(width: 6),
            Text(
              'More actions'.tr(),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }

  List<SalesInvoiceSummary> _filteredSales() {
    final query = _salesSearchController.text.trim().toLowerCase();
    return _salesRows
        .where((row) {
          final matchesQuery =
              query.isEmpty ||
              row.productsSummary.toLowerCase().contains(query) ||
              row.accountName.toLowerCase().contains(query);

          final matchesStatus = switch (_salesStatusFilter) {
            _InvoiceStatusFilter.all => true,
            _InvoiceStatusFilter.completed => row.status == 'completed',
            _InvoiceStatusFilter.partial => row.status == 'partial',
          };

          return matchesQuery && matchesStatus;
        })
        .toList(growable: false);
  }

  List<PurchaseInvoiceSummary> _filteredPurchases() {
    final query = _purchasesSearchController.text.trim().toLowerCase();
    return _purchaseRows
        .where((row) {
          final matchesQuery =
              query.isEmpty ||
              row.productsSummary.toLowerCase().contains(query) ||
              row.accountName.toLowerCase().contains(query);

          final matchesStatus = switch (_purchasesStatusFilter) {
            _InvoiceStatusFilter.all => true,
            _InvoiceStatusFilter.completed => row.status == 'completed',
            _InvoiceStatusFilter.partial => row.status == 'partial',
          };

          return matchesQuery && matchesStatus;
        })
        .toList(growable: false);
  }

  List<ExpenseRecord> _filteredExpenses() {
    final query = _purchasesSearchController.text.trim().toLowerCase();
    return _expenseRows
        .where((row) {
          final matchesQuery =
              query.isEmpty ||
              row.accountName.toLowerCase().contains(query) ||
              (row.notes?.toLowerCase().contains(query) ?? false) ||
              row.paymentMethod.toLowerCase().contains(query);
          return matchesQuery;
        })
        .toList(growable: false);
  }

  String _movementLabel(StandaloneCashMovement movement) {
    final type = _movementType(movement);
    return switch (type) {
      _FinancingTypeFilter.capitalInjection => 'Capital Injection'.tr(),
      _FinancingTypeFilter.ownerWithdrawal => 'Owner Withdrawal'.tr(),
      _FinancingTypeFilter.adjustment => 'Cash Adjustment'.tr(),
      _FinancingTypeFilter.all => 'Cash Adjustment'.tr(),
    };
  }

  _FinancingTypeFilter _movementType(StandaloneCashMovement movement) {
    final note = (movement.notes ?? '').trim().toLowerCase();
    if (note.contains('capital injection') || note.contains('ضخ رأس مال')) {
      return _FinancingTypeFilter.capitalInjection;
    }
    if (note.contains('owner withdrawal') || note.contains('مسحوبات مالك')) {
      return _FinancingTypeFilter.ownerWithdrawal;
    }
    return _FinancingTypeFilter.adjustment;
  }

  Widget _buildFinancingTypeBadge(
    BuildContext context,
    _FinancingTypeFilter type,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = switch (type) {
      _FinancingTypeFilter.capitalInjection => 'Capital Injection'.tr(),
      _FinancingTypeFilter.ownerWithdrawal => 'Owner Withdrawal'.tr(),
      _FinancingTypeFilter.adjustment => 'Cash Adjustment'.tr(),
      _FinancingTypeFilter.all => 'Cash Adjustment'.tr(),
    };
    final bgColor = switch (type) {
      _FinancingTypeFilter.capitalInjection => Colors.green.shade50,
      _FinancingTypeFilter.ownerWithdrawal => Colors.red.shade50,
      _FinancingTypeFilter.adjustment => colorScheme.surfaceContainerHighest,
      _FinancingTypeFilter.all => colorScheme.surfaceContainerHighest,
    };
    final fgColor = switch (type) {
      _FinancingTypeFilter.capitalInjection => Colors.green.shade800,
      _FinancingTypeFilter.ownerWithdrawal => Colors.red.shade800,
      _FinancingTypeFilter.adjustment => colorScheme.onSurfaceVariant,
      _FinancingTypeFilter.all => colorScheme.onSurfaceVariant,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fgColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildStandaloneMovementsSection(BuildContext context) {
    final veryDense = MediaQuery.sizeOf(context).height < 720;
    final ownerFinancingRows = _standaloneRows
        .where((row) => _movementType(row) != _FinancingTypeFilter.adjustment)
        .toList(growable: false);

    final filteredRows = ownerFinancingRows
        .where((row) {
          if (_financingTypeFilter == _FinancingTypeFilter.all) return true;
          if (_financingTypeFilter == _FinancingTypeFilter.adjustment) {
            return false;
          }
          return _movementType(row) == _financingTypeFilter;
        })
        .toList(growable: false);

    final inflow = filteredRows
        .where((row) => row.amount > 0)
        .fold<double>(0, (sum, row) => sum + row.amount);
    final outflow = filteredRows
        .where((row) => row.amount < 0)
        .fold<double>(0, (sum, row) => sum + row.amount.abs());

    return AppSectionPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _columnHeader(
            title: 'Owner Financing Movements'.tr(),
            count: filteredRows.length,
            total: inflow - outflow,
            totalColor: Theme.of(context).colorScheme.primary,
            amountLabel: 'Net movement'.tr(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Movement Type'.tr(),
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              ChoiceChip(
                selected: _financingTypeFilter == _FinancingTypeFilter.all,
                label: Text('All'.tr()),
                onSelected: (_) {
                  setState(() {
                    _financingTypeFilter = _FinancingTypeFilter.all;
                  });
                },
              ),
              ChoiceChip(
                selected:
                    _financingTypeFilter ==
                    _FinancingTypeFilter.capitalInjection,
                label: Text('Capital Injection'.tr()),
                onSelected: (_) {
                  setState(() {
                    _financingTypeFilter =
                        _FinancingTypeFilter.capitalInjection;
                  });
                },
              ),
              ChoiceChip(
                selected:
                    _financingTypeFilter ==
                    _FinancingTypeFilter.ownerWithdrawal,
                label: Text('Owner Withdrawal'.tr()),
                onSelected: (_) {
                  setState(() {
                    _financingTypeFilter = _FinancingTypeFilter.ownerWithdrawal;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: Icon(
                  Icons.add_circle_outline,
                  color: Colors.green.shade700,
                  size: 18,
                ),
                label: Text(
                  '${'Standalone Cash In'.tr()}: ${_formatMoney(context, inflow)}',
                ),
              ),
              Chip(
                avatar: Icon(
                  Icons.remove_circle_outline,
                  color: Colors.red.shade700,
                  size: 18,
                ),
                label: Text(
                  '${'Standalone Cash Out'.tr()}: ${_formatMoney(context, outflow)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 360,
            child: filteredRows.isEmpty
                ? AppEmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'No owner financing movements for selected range.'
                        .tr(),
                    compact: true,
                  )
                : ListView.separated(
                    itemCount: filteredRows.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final row = filteredRows[index];
                      final movementType = _movementType(row);
                      final isInflow = row.amount >= 0;
                      final amountColor = isInflow
                          ? Colors.green.shade700
                          : Colors.red.shade700;
                      final paymentMethodLabel = row.paymentMethod == 'cash'
                          ? 'Cash'.tr()
                          : 'Vodafone Cash'.tr();
                      return ListTile(
                        dense: veryDense,
                        visualDensity: veryDense
                            ? VisualDensity.compact
                            : VisualDensity.standard,
                        isThreeLine: !veryDense,
                        leading: Icon(
                          isInflow
                              ? Icons.call_received_outlined
                              : Icons.call_made_outlined,
                          color: amountColor,
                        ),
                        title: Row(
                          children: [
                            Expanded(child: Text(_movementLabel(row))),
                            const SizedBox(width: 8),
                            _buildFinancingTypeBadge(context, movementType),
                          ],
                        ),
                        subtitle: Text(
                          veryDense
                              ? '$paymentMethodLabel | ${DateFormat('yyyy-MM-dd HH:mm').format(row.createdAt)}'
                              : '$paymentMethodLabel | ${DateFormat('yyyy-MM-dd HH:mm').format(row.createdAt)}${(row.notes == null || row.notes!.isEmpty) ? '' : ' | ${row.notes}'}\n${'Not included in profit'.tr()}',
                        ),
                        trailing: Text(
                          _formatMoney(context, row.absoluteAmount),
                          style: TextStyle(
                            color: amountColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 1100;
    final veryDense = MediaQuery.sizeOf(context).height < 720;
    final sales = _filteredSales();
    final purchases = _filteredPurchases();
    final expenses = _filteredExpenses();

    // Always compute summary values from full loaded rows (real values for range)
    final salesCashInTotal = _salesRows.fold<double>(
      0,
      (sum, item) => sum + item.paidAmount,
    );
    final purchasesAndExpensesCashOutTotal =
        _purchaseRows.fold<double>(0, (sum, item) => sum + item.paidAmount) +
        _expensePaymentsTotal;
    final cashInTotal = salesCashInTotal + _standaloneInTotal;
    final cashOutTotal = purchasesAndExpensesCashOutTotal + _standaloneOutTotal;
    final cashInBox = _openingBalance + cashInTotal - cashOutTotal;

    return AppPageShell(
      isCompact: isCompact,
      child: Column(
        children: [
          AppSectionPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isCompact)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Statement'.tr(),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cash Box Statement'.tr(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _loading ? null : _loadData,
                            icon: const Icon(Icons.refresh),
                            label: Text('Refresh'.tr()),
                          ),
                          _buildMoreActionsButton(context),
                        ],
                      ),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Statement'.tr(),
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Cash Box Statement'.tr(),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _loading ? null : _loadData,
                        icon: const Icon(Icons.refresh),
                        label: Text('Refresh'.tr()),
                      ),
                      const SizedBox(width: 8),
                      _buildMoreActionsButton(context),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppSectionPanel(
            child: _buildCashSummary(
              context,
              openingBalance: _openingBalance,
              cashInTotal: cashInTotal,
              cashOutTotal: cashOutTotal,
              cashInBox: cashInBox,
              standaloneInTotal: _standaloneInTotal,
              standaloneOutTotal: _standaloneOutTotal,
              isCompact: isCompact,
            ),
          ),
          if (cashInBox < 0) ...[
            const SizedBox(height: 10),
            AppSectionPanel(
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Negative Cash Balance'.tr(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          AppSectionPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickFromDate,
                      icon: const Icon(Icons.date_range_outlined),
                      label: Text(
                        _fromDate == null
                            ? '${'From'.tr()}: ${'Any date'.tr()}'
                            : '${'From'.tr()}: ${DateFormat('yyyy-MM-dd').format(_fromDate!)}',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickToDate,
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        _toDate == null
                            ? '${'To'.tr()}: ${'Any date'.tr()}'
                            : '${'To'.tr()}: ${DateFormat('yyyy-MM-dd').format(_toDate!)}',
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _fromDate = null;
                          _toDate = null;
                        });
                        _loadData();
                      },
                      child: Text(
                        'Clear Filters'.tr(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showAdvancedFilters = !_showAdvancedFilters;
                        });
                      },
                      icon: Icon(
                        _showAdvancedFilters ? Icons.tune : Icons.tune_outlined,
                      ),
                      label: Text('Advanced options'.tr()),
                    ),
                  ],
                ),
                if (_showAdvancedFilters) ...[
                  SizedBox(height: veryDense ? 6 : 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.today, size: 18),
                        label: Text('Today'.tr()),
                        onPressed: () => _applyQuickRange(_QuickRange.today),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.date_range, size: 18),
                        label: Text('This Week'.tr()),
                        onPressed: () => _applyQuickRange(_QuickRange.thisWeek),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.calendar_view_month, size: 18),
                        label: Text('This Month'.tr()),
                        onPressed: () =>
                            _applyQuickRange(_QuickRange.thisMonth),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppSectionPanel(child: _buildCashFlowTabs(context)),
          const SizedBox(height: 10),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? AppLoadingIndicator(label: 'Loading statement...'.tr())
                : isCompact
                ? ListView(
                    children: [
                      if (_cashFlowView != _CashFlowView.financing) ...[
                        _buildSalesColumn(context, sales, veryDense: veryDense),
                        const SizedBox(height: 10),
                        _buildPurchasesColumn(
                          context,
                          purchases,
                          expenses,
                          veryDense: veryDense,
                        ),
                      ],
                      if (_cashFlowView != _CashFlowView.operational) ...[
                        if (_cashFlowView != _CashFlowView.financing)
                          const SizedBox(height: 10),
                        _buildStandaloneMovementsSection(context),
                      ],
                    ],
                  )
                : Row(
                    children: [
                      if (_cashFlowView != _CashFlowView.financing) ...[
                        Expanded(
                          child: _buildSalesColumn(
                            context,
                            sales,
                            veryDense: veryDense,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildPurchasesColumn(
                            context,
                            purchases,
                            expenses,
                            veryDense: veryDense,
                          ),
                        ),
                      ],
                      if (_cashFlowView != _CashFlowView.operational)
                        Expanded(
                          child: _buildStandaloneMovementsSection(context),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashFlowTabs(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cash Flow View'.tr(),
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<_CashFlowView>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment<_CashFlowView>(
                value: _CashFlowView.operational,
                icon: const Icon(Icons.storefront_outlined, size: 18),
                label: Text('Operational'.tr()),
              ),
              ButtonSegment<_CashFlowView>(
                value: _CashFlowView.financing,
                icon: const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 18,
                ),
                label: Text('Financing'.tr()),
              ),
            ],
            selected: <_CashFlowView>{_cashFlowView},
            onSelectionChanged: (selection) {
              if (selection.isEmpty) return;
              setState(() => _cashFlowView = selection.first);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSalesColumn(
    BuildContext context,
    List<SalesInvoiceSummary> rows, {
    required bool veryDense,
  }) {
    final total = rows.fold<double>(0, (sum, item) => sum + item.paidAmount);

    return AppSectionPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _columnHeader(
            title: 'Cash In'.tr(),
            count: rows.length,
            total: total,
            totalColor: Colors.green.shade700,
            amountLabel: 'Received amount'.tr(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _salesSearchController,
            decoration: InputDecoration(
              labelText: 'Search by name'.tr(),
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<_InvoiceStatusFilter>(
            initialValue: _salesStatusFilter,
            decoration: InputDecoration(labelText: 'Status'.tr()),
            items: [
              DropdownMenuItem(
                value: _InvoiceStatusFilter.all,
                child: Text('All'.tr()),
              ),
              DropdownMenuItem(
                value: _InvoiceStatusFilter.completed,
                child: Text('Completed'.tr()),
              ),
              DropdownMenuItem(
                value: _InvoiceStatusFilter.partial,
                child: Text('Partial'.tr()),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _salesStatusFilter = value);
            },
          ),
          const SizedBox(height: 8),
          Expanded(
            child: rows.isEmpty
                ? AppEmptyState(
                    icon: Icons.point_of_sale_outlined,
                    title: 'No sales data for selected range.'.tr(),
                    compact: true,
                  )
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      return _buildSalesInvoiceTile(
                        context,
                        row,
                        veryDense: veryDense,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchasesColumn(
    BuildContext context,
    List<PurchaseInvoiceSummary> rows,
    List<ExpenseRecord> expenseRows, {
    required bool veryDense,
  }) {
    final purchasesTotal = rows.fold<double>(
      0,
      (sum, item) => sum + item.paidAmount,
    );
    final expensesTotal = expenseRows.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    final total = purchasesTotal + expensesTotal;

    return AppSectionPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _columnHeader(
            title: 'Cash Out'.tr(),
            count: rows.length + expenseRows.length,
            total: total,
            totalColor: Colors.red.shade700,
            amountLabel: 'Paid amount + expenses'.tr(),
          ),
          if (expensesTotal != 0) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${'Operating expenses'.tr()}: ${_formatMoney(context, expensesTotal)}',
                style: TextStyle(
                  color: Colors.red.shade400,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _purchasesSearchController,
            decoration: InputDecoration(
              labelText: 'Search by name'.tr(),
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<_InvoiceStatusFilter>(
            initialValue: _purchasesStatusFilter,
            decoration: InputDecoration(labelText: 'Status'.tr()),
            items: [
              DropdownMenuItem(
                value: _InvoiceStatusFilter.all,
                child: Text('All'.tr()),
              ),
              DropdownMenuItem(
                value: _InvoiceStatusFilter.completed,
                child: Text('Completed'.tr()),
              ),
              DropdownMenuItem(
                value: _InvoiceStatusFilter.partial,
                child: Text('Partial'.tr()),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _purchasesStatusFilter = value);
            },
          ),
          const SizedBox(height: 8),
          Expanded(
            child: (rows.isEmpty && expenseRows.isEmpty)
                ? AppEmptyState(
                    icon: Icons.local_shipping_outlined,
                    title: 'No supplier data for selected range.'.tr(),
                    compact: true,
                  )
                : ListView.separated(
                    itemCount: rows.length + expenseRows.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index < rows.length) {
                        final row = rows[index];
                        return _buildPurchaseInvoiceTile(
                          context,
                          row,
                          veryDense: veryDense,
                        );
                      }

                      final expense = expenseRows[index - rows.length];
                      return _buildExpenseTile(
                        context,
                        expense,
                        veryDense: veryDense,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesInvoiceTile(
    BuildContext context,
    SalesInvoiceSummary row, {
    required bool veryDense,
  }) {
    final subtitle = veryDense
        ? '${'Customer'.tr()}: ${row.accountName}'
        : '${'Customer'.tr()}: ${row.accountName} | ${DateFormat('yyyy-MM-dd HH:mm').format(row.createdAt)}';

    return ListTile(
      dense: veryDense,
      visualDensity: veryDense ? VisualDensity.compact : VisualDensity.standard,
      title: Text(
        row.productsSummary,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        _formatMoney(context, row.paidAmount),
        style: TextStyle(
          color: Colors.green.shade700,
          fontWeight: FontWeight.w700,
        ),
      ),
      onTap: () => context.go(
        '/invoices?tab=sales&selectedInvoiceId=${row.id}&navSource=statement',
      ),
    );
  }

  Widget _buildPurchaseInvoiceTile(
    BuildContext context,
    PurchaseInvoiceSummary row, {
    required bool veryDense,
  }) {
    final subtitle = veryDense
        ? '${'Supplier'.tr()}: ${row.accountName}'
        : '${'Supplier'.tr()}: ${row.accountName} | ${DateFormat('yyyy-MM-dd HH:mm').format(row.createdAt)}';

    return ListTile(
      dense: veryDense,
      visualDensity: veryDense ? VisualDensity.compact : VisualDensity.standard,
      title: Text(
        row.productsSummary,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        _formatMoney(context, row.paidAmount),
        style: TextStyle(
          color: Colors.red.shade700,
          fontWeight: FontWeight.w700,
        ),
      ),
      onTap: () => context.go(
        '/invoices?tab=purchases&selectedInvoiceId=${row.id}&navSource=statement',
      ),
    );
  }

  Widget _buildExpenseTile(
    BuildContext context,
    ExpenseRecord expense, {
    required bool veryDense,
  }) {
    final paymentMethodLabel = expense.paymentMethod == 'cash'
        ? 'Cash'.tr()
        : 'Vodafone Cash'.tr();
    final subtitle = veryDense
        ? '$paymentMethodLabel | ${DateFormat('yyyy-MM-dd HH:mm').format(expense.createdAt)}'
        : '$paymentMethodLabel | ${DateFormat('yyyy-MM-dd HH:mm').format(expense.createdAt)}${(expense.notes == null || expense.notes!.isEmpty) ? '' : ' | ${expense.notes}'}';

    return ListTile(
      dense: veryDense,
      visualDensity: veryDense ? VisualDensity.compact : VisualDensity.standard,
      leading: const Icon(Icons.receipt_long_outlined),
      title: Text(
        '${'Expense'.tr()}: ${expense.accountName}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        _formatMoney(context, expense.amount),
        style: TextStyle(
          color: Colors.red.shade700,
          fontWeight: FontWeight.w700,
        ),
      ),
      onTap: () => context.go('/expenses'),
    );
  }

  Widget _columnHeader({
    required String title,
    required int count,
    required double total,
    required Color totalColor,
    required String amountLabel,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
        Text(
          '$amountLabel: ${_formatMoney(context, total)}',
          style: TextStyle(color: totalColor, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 8),
        Chip(label: Text('${count.toString()} ${'rows/page'.tr()}')),
      ],
    );
  }

  Widget _buildCashSummary(
    BuildContext context, {
    required double openingBalance,
    required double cashInTotal,
    required double cashOutTotal,
    required double cashInBox,
    required double standaloneInTotal,
    required double standaloneOutTotal,
    required bool isCompact,
  }) {
    final balanceColor = cashInBox >= 0
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;

    final netFlow = cashInTotal - cashOutTotal;

    final primaryChildren = [
      _summaryTile(
        title: 'Opening Balance'.tr(),
        value: openingBalance,
        icon: Icons.history,
        valueColor: openingBalance >= 0
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.error,
      ),
      _summaryTile(
        title: 'Net movement'.tr(),
        value: netFlow,
        icon: netFlow >= 0 ? Icons.trending_up : Icons.trending_down,
        valueColor: netFlow >= 0 ? Colors.green.shade700 : Colors.red.shade700,
      ),
      _summaryTile(
        title: 'Cash in Box'.tr(),
        value: cashInBox,
        icon: Icons.account_balance_wallet,
        valueColor: balanceColor,
      ),
    ];

    Widget primary;
    if (isCompact) {
      primary = Column(
        children: [
          for (var i = 0; i < primaryChildren.length; i++) ...[
            primaryChildren[i],
            if (i != primaryChildren.length - 1) const SizedBox(height: 8),
          ],
        ],
      );
    } else {
      primary = Row(
        children: [
          Expanded(child: primaryChildren[0]),
          const SizedBox(width: 8),
          Expanded(child: primaryChildren[1]),
          const SizedBox(width: 8),
          Expanded(child: primaryChildren[2]),
        ],
      );
    }

    final secondaryChildren = [
      _summaryTile(
        title: 'Cash In'.tr(),
        value: cashInTotal,
        icon: Icons.south_west,
        valueColor: Colors.green.shade700,
      ),
      _summaryTile(
        title: 'Cash Out'.tr(),
        value: cashOutTotal,
        icon: Icons.north_east,
        valueColor: Colors.red.shade700,
      ),
      _summaryTile(
        title: 'Standalone Cash In'.tr(),
        value: standaloneInTotal,
        icon: Icons.call_received_outlined,
        valueColor: Colors.green.shade600,
      ),
      _summaryTile(
        title: 'Standalone Cash Out'.tr(),
        value: standaloneOutTotal,
        icon: Icons.call_made_outlined,
        valueColor: Colors.red.shade600,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        primary,
        const SizedBox(height: 8),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: Text(
              'Advanced options'.tr(),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            children: [
              if (isCompact)
                Column(
                  children: [
                    for (var i = 0; i < secondaryChildren.length; i++) ...[
                      secondaryChildren[i],
                      if (i != secondaryChildren.length - 1)
                        const SizedBox(height: 8),
                    ],
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(child: secondaryChildren[0]),
                    const SizedBox(width: 8),
                    Expanded(child: secondaryChildren[1]),
                    const SizedBox(width: 8),
                    Expanded(child: secondaryChildren[2]),
                    const SizedBox(width: 8),
                    Expanded(child: secondaryChildren[3]),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryTile({
    required String title,
    required double value,
    required IconData icon,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
        ), // Use theme outline color
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
          ), // Use theme primary color for icon
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    // Use titleMedium for better hierarchy
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant, // Use onSurfaceVariant for subtitle text
                  ),
                ),
                Text(
                  _formatMoney(context, value),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color:
                        valueColor ??
                        Theme.of(context)
                            .colorScheme
                            .onSurface, // Default to onSurface if valueColor is null
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
