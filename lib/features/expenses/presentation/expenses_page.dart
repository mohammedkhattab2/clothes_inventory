import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:delta_erp/features/accounts/data/accounts_repository.dart';
import 'package:delta_erp/features/expenses/data/expenses_csv_service.dart';
import 'package:delta_erp/features/expenses/data/expenses_repository.dart';
import 'package:delta_erp/features/expenses/presentation/widgets/expense_delete_dialog.dart';
import 'package:delta_erp/features/expenses/presentation/widgets/expense_edit_dialog.dart';
import 'package:delta_erp/features/expenses/presentation/widgets/expenses_page_layout.dart';
import 'package:delta_erp/services/di/service_locator.dart';
import 'package:delta_erp/services/export/user_export_path_picker.dart';
import 'package:delta_erp/services/platform/folder_opener_service.dart';
import 'package:delta_erp/services/pdf/expenses_pdf_service.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

enum _ExpenseSortKey { newest, oldest, amountHighToLow, amountLowToHigh }

class _ExpensesPageState extends State<ExpensesPage> {
  final _repo = getIt<ExpensesRepository>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();

  bool _loading = false;
  bool _posting = false;
  bool _exportingCsv = false;
  bool _exportingPdf = false;
  bool _printing = false;
  String? _error;
  String? _lastExportPath;
  DateTime? _fromDate;
  DateTime? _toDate;
  String _paymentMethod = 'cash';
  bool _showReversals = false;
  String _searchQuery = '';
  _ExpenseSortKey _sortKey = _ExpenseSortKey.newest;
  int _page = 0;
  int _pageSize = 50;

  List<AccountLookup> _expenseAccounts = const <AccountLookup>[];
  List<ExpenseRecord> _records = const <ExpenseRecord>[];
  int? _selectedEntryExpenseAccountId;
  int? _selectedFilterExpenseAccountId;
  int _totalCount = 0;
  double _grossTotal = 0;
  double _netTotal = 0;

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  int _safePage(int totalRows) {
    if (totalRows <= 0) return 0;
    final maxPage = (totalRows - 1) ~/ _pageSize;
    return _page > maxPage ? maxPage : _page;
  }

  int _totalPages(int totalRows) {
    if (totalRows <= 0) return 1;
    return ((totalRows - 1) ~/ _pageSize) + 1;
  }

  int _currentOffset() => _page * _pageSize;

  String _sortByQueryValue() {
    switch (_sortKey) {
      case _ExpenseSortKey.newest:
        return 'created_desc';
      case _ExpenseSortKey.oldest:
        return 'created_asc';
      case _ExpenseSortKey.amountHighToLow:
        return 'amount_desc';
      case _ExpenseSortKey.amountLowToHigh:
        return 'amount_asc';
    }
  }

  Future<void> _initializePage() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _repo.ensureDefaultExpenseAccounts();
      final accounts = await _repo.listExpenseAccounts();

      if (!mounted) return;
      setState(() {
        _expenseAccounts = accounts;
        _selectedEntryExpenseAccountId ??= accounts.isNotEmpty
            ? accounts.first.id
            : null;
        _selectedFilterExpenseAccountId = null;
        _page = 0;
      });

      await _reloadRecords();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _reloadRecords() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.listExpenses(
          fromDate: _fromDate,
          toDate: _toDate,
          accountId: _selectedFilterExpenseAccountId,
          includeReversals: _showReversals,
          searchQuery: _searchQuery,
          sortBy: _sortByQueryValue(),
          limit: _pageSize,
          offset: _currentOffset(),
        ),
        _repo.sumGrossExpensePayments(
          fromDate: _fromDate,
          toDate: _toDate,
          accountId: _selectedFilterExpenseAccountId,
        ),
        _repo.sumExpensePayments(
          fromDate: _fromDate,
          toDate: _toDate,
          accountId: _selectedFilterExpenseAccountId,
        ),
        _repo.getExpensesCount(
          fromDate: _fromDate,
          toDate: _toDate,
          accountId: _selectedFilterExpenseAccountId,
          includeReversals: _showReversals,
          searchQuery: _searchQuery,
        ),
      ]);
      final records = results[0] as List<ExpenseRecord>;
      final gross = (results[1] as num).toDouble();
      final net = (results[2] as num).toDouble();
      final totalCount = (results[3] as num).toInt();

      final maxPage = totalCount <= 0 ? 0 : (totalCount - 1) ~/ _pageSize;
      if (_page > maxPage) {
        setState(() => _page = maxPage);
        return _reloadRecords();
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _records = records;
        _totalCount = totalCount;
        _grossTotal = gross;
        _netTotal = net;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
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
    await _reloadRecords();
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
    await _reloadRecords();
  }

  double? _parseAmount() {
    final raw = _amountController.text.trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw.replaceAll(',', '.'));
  }

  Future<void> _submitExpense() async {
    final accountId = _selectedEntryExpenseAccountId;
    final parsedAmount = _parseAmount();

    if (accountId == null) {
      setState(() => _error = 'Select expense account.'.tr());
      return;
    }
    if (parsedAmount == null || parsedAmount <= 0) {
      setState(() => _error = 'Enter a valid amount.'.tr());
      return;
    }

    setState(() {
      _posting = true;
      _error = null;
    });

    try {
      await _repo.createExpense(
        accountId: accountId,
        amount: parsedAmount,
        paymentMethod: _paymentMethod,
        notes: _notesController.text,
      );
      if (!mounted) return;

      _amountController.clear();
      _notesController.clear();
      await _reloadRecords();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Expense saved'.tr())));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _posting = false);
      }
    }
  }

  Future<void> _deleteExpense(ExpenseRecord row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const ExpenseDeleteDialog(),
    );

    if (confirmed != true) return;

    setState(() {
      _posting = true;
      _error = null;
    });
    try {
      await _repo.cancelExpense(expenseId: row.id, reason: 'deleted');
      if (!mounted) return;
      await _reloadRecords();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Expense deleted'.tr())));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _posting = false);
      }
    }
  }

  Future<void> _exportCsv() async {
    final targetPath = await getIt<UserExportPathPicker>().pickSavePath(
      dialogTitle: 'export.save_dialog_title'.tr(),
      suggestedFileName:
          'expenses_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv',
      extensions: const ['csv'],
    );
    if (targetPath == null) return;

    setState(() => _exportingCsv = true);
    try {
      final rows = await _repo.listExpenses(
        fromDate: _fromDate,
        toDate: _toDate,
        accountId: _selectedFilterExpenseAccountId,
        includeReversals: _showReversals,
        searchQuery: _searchQuery,
        sortBy: _sortByQueryValue(),
        limit: 100000,
        offset: 0,
      );
      final path = await getIt<ExpensesCsvService>().exportToCsv(
        rows: rows,
        grossExpenses: _grossTotal,
        netExpenses: _netTotal,
        includeReversals: _showReversals,
        targetPath: targetPath,
        fromDate: _fromDate,
        toDate: _toDate,
        accountId: _selectedFilterExpenseAccountId,
      );

      if (!mounted) return;
      setState(() => _lastExportPath = path);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${'CSV exported'.tr()}: $path')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'CSV export failed'.tr()}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _exportingCsv = false);
      }
    }
  }

  Future<void> _exportPdf() async {
    final targetPath = await getIt<UserExportPathPicker>().pickSavePath(
      dialogTitle: 'export.save_dialog_title'.tr(),
      suggestedFileName:
          'expenses_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
      extensions: const ['pdf'],
    );
    if (targetPath == null) return;

    setState(() => _exportingPdf = true);
    try {
      final rows = await _repo.listExpenses(
        fromDate: _fromDate,
        toDate: _toDate,
        accountId: _selectedFilterExpenseAccountId,
        includeReversals: _showReversals,
        searchQuery: _searchQuery,
        sortBy: _sortByQueryValue(),
        limit: 100000,
        offset: 0,
      );

      final path = await getIt<ExpensesPdfService>().exportToPdf(
        rows: rows,
        grossExpenses: _grossTotal,
        netExpenses: _netTotal,
        includeReversals: _showReversals,
        targetPath: targetPath,
        fromDate: _fromDate,
        toDate: _toDate,
        accountId: _selectedFilterExpenseAccountId,
      );

      if (!mounted) return;
      setState(() => _lastExportPath = path);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${'PDF exported'.tr()}: $path')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'PDF export failed'.tr()}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _exportingPdf = false);
      }
    }
  }

  Future<void> _openExportFolder() async {
    final path = _lastExportPath;
    if (path == null) return;

    final ok = await getIt<FolderOpenerService>().openContainingFolder(path);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open export folder.'.tr())),
      );
    }
  }

  Future<void> _printReport() async {
    setState(() => _printing = true);
    try {
      final rows = await _repo.listExpenses(
        fromDate: _fromDate,
        toDate: _toDate,
        accountId: _selectedFilterExpenseAccountId,
        includeReversals: _showReversals,
        searchQuery: _searchQuery,
        sortBy: _sortByQueryValue(),
        limit: 100000,
        offset: 0,
      );

      await getIt<ExpensesPdfService>().printReport(
        rows: rows,
        grossExpenses: _grossTotal,
        netExpenses: _netTotal,
        includeReversals: _showReversals,
        fromDate: _fromDate,
        toDate: _toDate,
        accountId: _selectedFilterExpenseAccountId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Report sent to printer.'.tr())));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'PDF export failed'.tr()}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _printing = false);
      }
    }
  }

  Future<void> _editExpense(ExpenseRecord row) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => ExpenseEditDialog(
        row: row,
        expenseAccounts: _expenseAccounts,
        onSave: (value) {
          return _repo.updateExpense(
            expenseId: row.id,
            accountId: value.accountId,
            amount: value.amount,
            paymentMethod: value.paymentMethod,
            notes: value.notes,
          );
        },
      ),
    );

    if (updated != true || !mounted) return;
    await _reloadRecords();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Expense updated'.tr())));
  }

  String _formatMoney(double value) {
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

  String _compactErrorMessage(String raw) {
    final normalized = raw.replaceAll('\n', ' ').trim();
    final withoutPrefix = normalized.startsWith('Exception:')
        ? normalized.substring('Exception:'.length).trim()
        : normalized;
    if (withoutPrefix.length <= 220) {
      return withoutPrefix;
    }
    return '${withoutPrefix.substring(0, 220)}...';
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 1100;
    final safePage = _safePage(_totalCount);
    final totalPages = _totalPages(_totalCount);
    final showingFrom = _totalCount == 0 ? 0 : (safePage * _pageSize) + 1;
    final showingTo = _totalCount == 0 ? 0 : showingFrom + _records.length - 1;

    return ExpensesPageLayout(
      isCompact: isCompact,
      loading: _loading,
      posting: _posting,
      exportingCsv: _exportingCsv,
      exportingPdf: _exportingPdf,
      printing: _printing,
      error: _error,
      lastExportPath: _lastExportPath,
      fromDate: _fromDate,
      toDate: _toDate,
      paymentMethod: _paymentMethod,
      showReversals: _showReversals,
      searchController: _searchController,
      amountController: _amountController,
      notesController: _notesController,
      searchQuery: _searchQuery,
      sortIndex: _sortKey.index,
      pageSize: _pageSize,
      expenseAccounts: _expenseAccounts,
      records: _records,
      selectedEntryExpenseAccountId: _selectedEntryExpenseAccountId,
      selectedFilterExpenseAccountId: _selectedFilterExpenseAccountId,
      totalCount: _totalCount,
      grossTotal: _grossTotal,
      netTotal: _netTotal,
      safePage: safePage,
      totalPages: totalPages,
      showingFrom: showingFrom,
      showingTo: showingTo,
      onPrintReport: _printReport,
      onExportPdf: _exportPdf,
      onExportCsv: _exportCsv,
      onOpenExportFolder: _openExportFolder,
      onRefresh: _initializePage,
      onEntryAccountChanged: (value) {
        setState(() => _selectedEntryExpenseAccountId = value);
      },
      onPaymentMethodChanged: (value) {
        setState(() => _paymentMethod = value);
      },
      onAddExpense: _submitExpense,
      onPickFromDate: _pickFromDate,
      onPickToDate: _pickToDate,
      onClearDateFilters: () {
        setState(() {
          _fromDate = null;
          _toDate = null;
        });
        _reloadRecords();
      },
      onToggleReversals: (value) {
        setState(() {
          _showReversals = value;
          _page = 0;
        });
        _reloadRecords();
      },
      onSearchChanged: (value) {
        setState(() {
          _searchQuery = value;
          _page = 0;
        });
        _reloadRecords();
      },
      onFilterAccountChanged: (value) {
        setState(() {
          _selectedFilterExpenseAccountId = value;
          _page = 0;
        });
        _reloadRecords();
      },
      onSortChanged: (value) {
        setState(() {
          _sortKey = _ExpenseSortKey.values[value];
          _page = 0;
        });
        _reloadRecords();
      },
      onPageSizeChanged: (value) {
        setState(() {
          _pageSize = value;
          _page = 0;
        });
        _reloadRecords();
      },
      onEditExpense: _editExpense,
      onDeleteExpense: _deleteExpense,
      onPreviousPage: () {
        setState(() => _page = safePage - 1);
        _reloadRecords();
      },
      onNextPage: () {
        setState(() => _page = safePage + 1);
        _reloadRecords();
      },
      formatMoney: _formatMoney,
      compactErrorMessage: _compactErrorMessage,
    );
  }
}
