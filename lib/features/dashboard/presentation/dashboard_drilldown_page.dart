import 'dart:collection';
import 'dart:developer' as dev;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:clothes_inventory/core/widgets/app_empty_state.dart';
import 'package:clothes_inventory/core/widgets/app_brand_header.dart';
import 'package:clothes_inventory/core/widgets/app_error_banner.dart';
import 'package:clothes_inventory/core/widgets/app_inline_loading_indicator.dart';
import 'package:clothes_inventory/core/widgets/app_loading_indicator.dart';
import 'package:clothes_inventory/features/dashboard/data/dashboard_drilldown_export_service.dart';
import 'package:clothes_inventory/features/dashboard/data/dashboard_repository.dart';
import 'package:clothes_inventory/features/dashboard/presentation/dashboard_cubit.dart';
import 'package:clothes_inventory/services/di/service_locator.dart';
import 'package:clothes_inventory/services/platform/folder_opener_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardDrillDownPage extends StatefulWidget {
  const DashboardDrillDownPage({
    required this.kind,
    required this.fromDate,
    required this.toDate,
    required this.granularity,
    this.categoryId,
    this.accountId,
    super.key,
  });

  final String kind;
  final DateTime fromDate;
  final DateTime toDate;
  final String granularity;
  final int? categoryId;
  final int? accountId;

  @override
  State<DashboardDrillDownPage> createState() => _DashboardDrillDownPageState();
}

class _DashboardDrillDownPageState extends State<DashboardDrillDownPage> {
  static const _pageSize = 50;
  static int _lastNetSectionIndex = 0;
  static const _netSectionPrefKey = 'dashboard.net.sectionIndex';

  final _currency = NumberFormat.currency(symbol: '', decimalDigits: 2);
  bool _loading = false;
  bool _exportingPdf = false;
  bool _exportingCsv = false;
  String? _error;
  String? _lastExportPath;
  int _page = 0;
  int _netSectionIndex = _lastNetSectionIndex;
  List<DashboardInvoiceRecord> _invoiceRows = const [];
  List<DashboardProfitRecord> _profitRows = const [];
  List<DashboardInvoiceRecord> _netExpenseRows = const [];
  List<_NetTrendPoint> _netTrendRows = const [];
  DashboardSnapshot? _netSnapshot;

  @override
  void initState() {
    super.initState();
    _netSectionIndex = _lastNetSectionIndex.clamp(0, 2);
    _restoreNetSectionPreference();
    _load();
  }

  Future<void> _restoreNetSectionPreference() async {
    if (widget.kind != 'net') return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(_netSectionPrefKey);
      if (saved == null) return;
      final normalized = saved.clamp(0, 2);
      _lastNetSectionIndex = normalized;
      if (!mounted) return;
      setState(() {
        _netSectionIndex = normalized;
      });
    } catch (_) {
      // Ignore preference read failures and keep in-memory fallback.
    }
  }

  Future<void> _persistNetSectionPreference(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_netSectionPrefKey, index);
    } catch (_) {
      // Ignore preference write failures and keep in-memory fallback.
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = getIt<DashboardRepository>();
      final offset = _page * _pageSize;
      if (widget.kind == 'net') {
        final snapshot = await repo.getDashboardSnapshot(
          from: widget.fromDate,
          to: widget.toDate,
          granularity: widget.granularity,
          categoryId: widget.categoryId,
          accountId: widget.accountId,
        );
        final allProfitRows = await repo.getProfitBreakdown(
          from: widget.fromDate,
          to: widget.toDate,
          categoryId: widget.categoryId,
          accountId: widget.accountId,
        );
        final allExpenseRows = await repo.getExpenseEntries(
          from: widget.fromDate,
          to: widget.toDate,
          accountId: widget.accountId,
        );
        if (!mounted) return;
        setState(() {
          _netSnapshot = snapshot;
          _profitRows = allProfitRows;
          _netExpenseRows = allExpenseRows;
          _netTrendRows = _buildNetTrendRows(
            grossRows: allProfitRows,
            expenseRows: allExpenseRows,
            granularity: widget.granularity,
          );
          _invoiceRows = const [];
          _loading = false;
        });
      } else if (_isProfitKind(widget.kind)) {
        final rows = await repo.getProfitBreakdown(
          from: widget.fromDate,
          to: widget.toDate,
          categoryId: widget.categoryId,
          accountId: widget.accountId,
        );
        if (!mounted) return;
        setState(() {
          _profitRows = rows;
          _invoiceRows = const [];
          _netExpenseRows = const [];
          _netTrendRows = const [];
          _netSnapshot = null;
          _loading = false;
        });
      } else if (widget.kind == 'revenue' || widget.kind == 'customer_debt') {
        final rows = await repo.getSalesInvoices(
          from: widget.fromDate,
          to: widget.toDate,
          categoryId: widget.categoryId,
          accountId: widget.accountId,
          onlyUnpaid: widget.kind == 'customer_debt',
          limit: _pageSize,
          offset: offset,
        );
        if (!mounted) return;
        setState(() {
          _invoiceRows = rows;
          _profitRows = const [];
          _netExpenseRows = const [];
          _netTrendRows = const [];
          _netSnapshot = null;
          _loading = false;
        });
      } else if (widget.kind == 'expenses') {
        final rows = await repo.getExpenseBreakdownEntries(
          from: widget.fromDate,
          to: widget.toDate,
          categoryId: widget.categoryId,
          accountId: widget.accountId,
          limit: _pageSize,
          offset: offset,
        );
        if (!mounted) return;
        setState(() {
          _invoiceRows = rows;
          _profitRows = const [];
          _netExpenseRows = const [];
          _netTrendRows = const [];
          _netSnapshot = null;
          _loading = false;
        });
      } else {
        final rows = await repo.getPurchaseInvoices(
          from: widget.fromDate,
          to: widget.toDate,
          categoryId: widget.categoryId,
          accountId: widget.accountId,
          onlyUnpaid: widget.kind == 'supplier_debt',
          limit: _pageSize,
          offset: offset,
        );
        if (!mounted) return;
        setState(() {
          _invoiceRows = rows;
          _profitRows = const [];
          _netExpenseRows = const [];
          _netTrendRows = const [];
          _netSnapshot = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  bool _isProfitKind(String kind) => kind == 'gross' || kind == 'net';

  String _title() {
    switch (widget.kind) {
      case 'revenue':
        return 'Revenue Details (Sales Invoices)'.tr();
      case 'expenses':
        return 'Expenses Details (Expense Entries)'.tr();
      case 'gross':
        return 'Gross Profit Breakdown'.tr();
      case 'net':
        return 'Net Profit Breakdown'.tr();
      case 'customer_debt':
        return 'Customer Debt (Unpaid Sales)'.tr();
      case 'supplier_debt':
        return 'Supplier Debt (Unpaid Purchases)'.tr();
      default:
        return 'Dashboard Details'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isDenseViewport = size.height < 820 || size.width < 1180;
    final isVeryDenseViewport = size.height < 700 || size.width < 1024;
    final sectionGap = isVeryDenseViewport
        ? 6.0
        : (isDenseViewport ? 8.0 : 10.0);

    return Padding(
      padding: EdgeInsets.all(
        isVeryDenseViewport ? 12 : (isDenseViewport ? 16 : 24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppBrandHeader(
            pageTitle: _title(),
            description:
                '${'Range'.tr()}: ${DateFormat('yyyy-MM-dd').format(widget.fromDate)} ${'to'.tr()} ${DateFormat('yyyy-MM-dd').format(widget.toDate)}',
            isDense: isDenseViewport,
            slim: isVeryDenseViewport,
          ),
          SizedBox(height: sectionGap),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 860;
              final actions = [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _loading || _exportingPdf
                      ? null
                      : () => _exportDrillDownPdf(context),
                  icon: _exportingPdf
                      ? const AppInlineLoadingIndicator()
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: Text('PDF'.tr()),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _loading || _exportingCsv
                      ? null
                      : () => _exportDrillDownCsv(context),
                  icon: _exportingCsv
                      ? const AppInlineLoadingIndicator()
                      : const Icon(Icons.table_view_outlined),
                  label: Text('CSV'.tr()),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _lastExportPath == null
                      ? null
                      : () => _openExportFolder(context),
                  icon: const Icon(Icons.folder_open_outlined),
                  label: Text('Open Folder'.tr()),
                ),
              ];

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: sectionGap,
                      runSpacing: sectionGap,
                      children: actions,
                    ),
                    if (_lastExportPath != null) ...[
                      SizedBox(height: sectionGap),
                      Text(
                        '${'Last'.tr()}: ${p.basename(_lastExportPath!)}',
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  actions[0],
                  SizedBox(width: sectionGap),
                  actions[1],
                  SizedBox(width: sectionGap),
                  actions[2],
                  if (_lastExportPath != null) ...[
                    SizedBox(width: sectionGap),
                    Expanded(
                      child: Text(
                        '${'Last'.tr()}: ${p.basename(_lastExportPath!)}',
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          SizedBox(height: sectionGap),
          if (_loading)
            Expanded(
              child: AppLoadingIndicator(label: 'Loading details...'.tr()),
            )
          else if (_error != null)
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: AppErrorBanner(
                    message: _error!,
                    onRetry: _load,
                    retryLabel: 'Refresh'.tr(),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: widget.kind == 'net'
                  ? _buildNetProfitView()
                  : _buildModernDrillDownView(),
            ),
          if (!_isProfitKind(widget.kind)) ...[
            SizedBox(height: sectionGap),
            Wrap(
              spacing: sectionGap,
              runSpacing: sectionGap,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _page > 0
                      ? () {
                          setState(() => _page -= 1);
                          _load();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_left),
                  label: Text('Previous'.tr()),
                ),
                Text('${'Page'.tr()} ${_page + 1}'),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _canGoNext()
                      ? () {
                          setState(() => _page += 1);
                          _load();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_right),
                  label: Text('Next'.tr()),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool _canGoNext() {
    if (_isProfitKind(widget.kind)) {
      return false;
    }
    return _invoiceRows.length == _pageSize;
  }

  Future<void> _exportDrillDownPdf(BuildContext context) async {
    setState(() => _exportingPdf = true);
    try {
      final data = await _loadAllForExport();
      final path = await getIt<DashboardDrillDownExportService>().exportPdf(
        title: _title(),
        kind: widget.kind,
        fromDate: widget.fromDate,
        toDate: widget.toDate,
        granularity: widget.granularity,
        categoryLabel: widget.categoryId?.toString() ?? 'All'.tr(),
        accountLabel: widget.accountId?.toString() ?? 'All'.tr(),
        invoiceRows: data.$1,
        profitRows: data.$2,
      );
      if (!mounted) return;
      setState(() => _lastExportPath = path);
      ScaffoldMessenger.of(
        this.context,
      ).showSnackBar(SnackBar(content: Text('${'PDF exported'.tr()}: $path')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'PDF export failed'.tr()}: $e')),
      );
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  Future<void> _exportDrillDownCsv(BuildContext context) async {
    setState(() => _exportingCsv = true);
    try {
      final data = await _loadAllForExport();
      final path = await getIt<DashboardDrillDownExportService>().exportCsv(
        title: _title(),
        kind: widget.kind,
        fromDate: widget.fromDate,
        toDate: widget.toDate,
        granularity: widget.granularity,
        categoryLabel: widget.categoryId?.toString() ?? 'All'.tr(),
        accountLabel: widget.accountId?.toString() ?? 'All'.tr(),
        invoiceRows: data.$1,
        profitRows: data.$2,
      );
      if (!mounted) return;
      setState(() => _lastExportPath = path);
      ScaffoldMessenger.of(
        this.context,
      ).showSnackBar(SnackBar(content: Text('${'CSV exported'.tr()}: $path')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'CSV export failed'.tr()}: $e')),
      );
    } finally {
      if (mounted) setState(() => _exportingCsv = false);
    }
  }

  Future<(List<DashboardInvoiceRecord>, List<DashboardProfitRecord>)>
  _loadAllForExport() async {
    final repo = getIt<DashboardRepository>();
    if (widget.kind == 'net') {
      final profits = await repo.getProfitBreakdown(
        from: widget.fromDate,
        to: widget.toDate,
        categoryId: widget.categoryId,
        accountId: widget.accountId,
      );
      final expenses = await repo.getExpenseEntries(
        from: widget.fromDate,
        to: widget.toDate,
        accountId: widget.accountId,
      );
      return (expenses, profits);
    }
    if (_isProfitKind(widget.kind)) {
      final profits = await repo.getProfitBreakdown(
        from: widget.fromDate,
        to: widget.toDate,
        categoryId: widget.categoryId,
        accountId: widget.accountId,
      );
      return (const <DashboardInvoiceRecord>[], profits);
    }
    if (widget.kind == 'revenue' || widget.kind == 'customer_debt') {
      final invoices = await repo.getSalesInvoices(
        from: widget.fromDate,
        to: widget.toDate,
        categoryId: widget.categoryId,
        accountId: widget.accountId,
        onlyUnpaid: widget.kind == 'customer_debt',
      );
      return (invoices, const <DashboardProfitRecord>[]);
    }
    if (widget.kind == 'expenses') {
      final invoices = await repo.getExpenseBreakdownEntries(
        from: widget.fromDate,
        to: widget.toDate,
        categoryId: widget.categoryId,
        accountId: widget.accountId,
      );
      return (invoices, const <DashboardProfitRecord>[]);
    }
    final invoices = await repo.getPurchaseInvoices(
      from: widget.fromDate,
      to: widget.toDate,
      categoryId: widget.categoryId,
      accountId: widget.accountId,
      onlyUnpaid: widget.kind == 'supplier_debt',
    );
    return (invoices, const <DashboardProfitRecord>[]);
  }

  Future<void> _openExportFolder(BuildContext context) async {
    final path = _lastExportPath;
    if (path == null) return;
    final ok = await getIt<FolderOpenerService>().openContainingFolder(path);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open export folder.'.tr())),
      );
    }
  }

  Widget _buildInvoiceTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(
          Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        headingTextStyle: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        dataTextStyle: Theme.of(context).textTheme.bodyMedium,
        columnSpacing: 22,
        columns: [
          DataColumn(label: Text('Date'.tr())),
          DataColumn(label: Text('Invoice'.tr())),
          DataColumn(label: Text('Account'.tr())),
          DataColumn(label: Text('Status'.tr())),
          DataColumn(label: Text('Total'.tr())),
          DataColumn(label: Text('Paid'.tr())),
          DataColumn(label: Text('Outstanding'.tr())),
        ],
        rows: _invoiceRows
            .map(
              (row) => DataRow(
                onSelectChanged: (_) =>
                    _navigateToInvoice(row.type, row.id, row.invoiceNumber),
                cells: [
                  DataCell(
                    Text(DateFormat('yyyy-MM-dd HH:mm').format(row.createdAt)),
                  ),
                  DataCell(Text(row.invoiceNumber)),
                  DataCell(Text(row.accountName)),
                  DataCell(Text(row.status)),
                  DataCell(Text(_currency.format(row.totalAmount))),
                  DataCell(Text(_currency.format(row.paidAmount))),
                  DataCell(Text(_currency.format(row.outstandingAmount))),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildProfitTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(
          Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        headingTextStyle: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        dataTextStyle: Theme.of(context).textTheme.bodyMedium,
        columnSpacing: 22,
        columns: [
          DataColumn(label: Text('Date'.tr())),
          DataColumn(label: Text('Invoice'.tr())),
          DataColumn(label: Text('Customer'.tr())),
          DataColumn(label: Text('Revenue'.tr())),
          DataColumn(label: Text('COGS'.tr())),
          DataColumn(label: Text('Gross Profit'.tr())),
        ],
        rows: _profitRows
            .map(
              (row) => DataRow(
                onSelectChanged: (_) =>
                    _navigateToInvoice('sale', row.saleId, row.invoiceNumber),
                cells: [
                  DataCell(
                    Text(DateFormat('yyyy-MM-dd HH:mm').format(row.createdAt)),
                  ),
                  DataCell(Text(row.invoiceNumber)),
                  DataCell(Text(row.accountName)),
                  DataCell(Text(_currency.format(row.revenue))),
                  DataCell(Text(_currency.format(row.cogs))),
                  DataCell(Text(_currency.format(row.grossProfit))),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildModernDrillDownView() {
    final colorScheme = Theme.of(context).colorScheme;
    final isProfit = widget.kind == 'gross';
    final totalAmount = _invoiceRows.fold<double>(
      0,
      (sum, row) => sum + row.totalAmount,
    );
    final totalPaid = _invoiceRows.fold<double>(
      0,
      (sum, row) => sum + row.paidAmount,
    );
    final totalOutstanding = _invoiceRows.fold<double>(
      0,
      (sum, row) => sum + row.outstandingAmount,
    );
    final grossRevenueTotal = _profitRows.fold<double>(
      0,
      (sum, row) => sum + row.revenue,
    );
    final grossCogsTotal = _profitRows.fold<double>(
      0,
      (sum, row) => sum + row.cogs,
    );
    final grossProfitTotal = _profitRows.fold<double>(
      0,
      (sum, row) => sum + row.grossProfit,
    );

    final summary = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.82),
            colorScheme.surfaceContainerHigh,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_drillDownIcon(widget.kind), color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _title(),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _NetMiniMetrics(
            items: isProfit
                ? [
                    _NetMiniMetricItem(
                      label: 'Revenue'.tr(),
                      value: _currency.format(grossRevenueTotal),
                    ),
                    _NetMiniMetricItem(
                      label: 'COGS'.tr(),
                      value: _currency.format(grossCogsTotal),
                    ),
                    _NetMiniMetricItem(
                      label: 'Gross Profit'.tr(),
                      value: _currency.format(grossProfitTotal),
                      emphasize: true,
                    ),
                  ]
                : [
                    _NetMiniMetricItem(
                      label: 'Total'.tr(),
                      value: _currency.format(totalAmount),
                    ),
                    _NetMiniMetricItem(
                      label: 'Paid'.tr(),
                      value: _currency.format(totalPaid),
                    ),
                    _NetMiniMetricItem(
                      label: 'Outstanding'.tr(),
                      value: _currency.format(totalOutstanding),
                      emphasize:
                          widget.kind == 'customer_debt' ||
                          widget.kind == 'supplier_debt',
                    ),
                  ],
          ),
        ],
      ),
    );

    final details = _NetSectionCard(
      title: _title(),
      icon: _drillDownIcon(widget.kind),
      child: isProfit ? _buildProfitTable() : _buildInvoiceTable(),
    );

    return ListView(children: [summary, const SizedBox(height: 12), details]);
  }

  IconData _drillDownIcon(String kind) {
    switch (kind) {
      case 'revenue':
        return Icons.trending_up_rounded;
      case 'expenses':
        return Icons.receipt_long_outlined;
      case 'gross':
        return Icons.show_chart_rounded;
      case 'customer_debt':
        return Icons.people_alt_outlined;
      case 'supplier_debt':
        return Icons.warehouse_outlined;
      default:
        return Icons.insights_outlined;
    }
  }

  Widget _buildNetProfitView() {
    final snapshot = _netSnapshot;
    final colorScheme = Theme.of(context).colorScheme;
    final tabs = <String>['Overview'.tr(), 'Transactions'.tr(), 'Trend'.tr()];
    final grossRevenueTotal = _profitRows.fold<double>(
      0,
      (sum, row) => sum + row.revenue,
    );
    final grossCogsTotal = _profitRows.fold<double>(
      0,
      (sum, row) => sum + row.cogs,
    );
    final grossProfitTotal = _profitRows.fold<double>(
      0,
      (sum, row) => sum + row.grossProfit,
    );
    final operatingExpenseTotal = _netExpenseRows.fold<double>(
      0,
      (sum, row) => sum + row.totalAmount,
    );
    final netTrendTotal = _netTrendRows.fold<double>(
      0,
      (sum, row) => sum + row.netProfit,
    );

    final summary = snapshot == null
        ? const SizedBox.shrink()
        : Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primaryContainer.withValues(alpha: 0.85),
                  colorScheme.surfaceContainerHigh,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Net Profit Breakdown'.tr(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${'Formula'.tr()}: ${'Net Profit'.tr()} = ${'Gross Profit'.tr()} - ${'Operating expenses'.tr()}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _NetSummaryChip(
                      title: 'Revenue'.tr(),
                      value: _currency.format(snapshot.totalSales),
                    ),
                    _NetSummaryChip(
                      title: 'COGS'.tr(),
                      value: _currency.format(snapshot.cogs),
                    ),
                    _NetSummaryChip(
                      title: 'Gross Profit'.tr(),
                      value: _currency.format(snapshot.grossProfit),
                    ),
                    _NetSummaryChip(
                      title: 'Operating expenses'.tr(),
                      value: _currency.format(snapshot.expenses),
                    ),
                    _NetSummaryChip(
                      title: 'Net Profit'.tr(),
                      value: _currency.format(snapshot.netProfit),
                      emphasize: true,
                    ),
                  ],
                ),
              ],
            ),
          );

    final grossPanel = _NetSectionCard(
      title: 'Gross Profit Breakdown'.tr(),
      icon: Icons.show_chart_rounded,
      child: Column(
        children: [
          _NetMiniMetrics(
            items: [
              _NetMiniMetricItem(
                label: 'Revenue'.tr(),
                value: _currency.format(grossRevenueTotal),
              ),
              _NetMiniMetricItem(
                label: 'COGS'.tr(),
                value: _currency.format(grossCogsTotal),
              ),
              _NetMiniMetricItem(
                label: 'Gross Profit'.tr(),
                value: _currency.format(grossProfitTotal),
                emphasize: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildProfitTable(),
        ],
      ),
    );

    final expensePanel = _NetSectionCard(
      title: 'Expenses Details (Expense Entries)'.tr(),
      icon: Icons.receipt_long_outlined,
      child: Column(
        children: [
          _NetMiniMetrics(
            items: [
              _NetMiniMetricItem(
                label: 'Total'.tr(),
                value: _currency.format(operatingExpenseTotal),
                emphasize: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildNetExpenseTable(),
        ],
      ),
    );

    final trendPanel = _NetSectionCard(
      title: 'Net Profit Trend'.tr(),
      icon: Icons.timeline_rounded,
      child: Column(
        children: [
          _NetMiniMetrics(
            items: [
              _NetMiniMetricItem(
                label: 'Net Profit'.tr(),
                value: _currency.format(netTrendTotal),
                emphasize: true,
              ),
              _NetMiniMetricItem(
                label: 'Period'.tr(),
                value: _netTrendRows.length.toString(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildNetTrendChart(),
          const SizedBox(height: 10),
          _buildNetTrendTable(),
        ],
      ),
    );

    final overviewPanel = _NetSectionCard(
      title: 'Overview'.tr(),
      icon: Icons.space_dashboard_outlined,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _NetMiniMetricItemCard(
            label: 'Gross Profit'.tr(),
            value: _currency.format(grossProfitTotal),
            icon: Icons.show_chart_rounded,
          ),
          _NetMiniMetricItemCard(
            label: 'Operating expenses'.tr(),
            value: _currency.format(operatingExpenseTotal),
            icon: Icons.receipt_long_outlined,
          ),
          _NetMiniMetricItemCard(
            label: 'Net Profit'.tr(),
            value: snapshot == null
                ? _currency.format(0)
                : _currency.format(snapshot.netProfit),
            icon: Icons.insights_outlined,
            emphasize: true,
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1200;
        final isMedium = constraints.maxWidth >= 860;
        final sectionBody = _netSectionIndex == 0
            ? Column(
                children: [
                  overviewPanel,
                  const SizedBox(height: 12),
                  trendPanel,
                ],
              )
            : (_netSectionIndex == 1
                  ? (isMedium
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: grossPanel),
                              const SizedBox(width: 12),
                              Expanded(child: expensePanel),
                            ],
                          )
                        : Column(
                            children: [
                              grossPanel,
                              const SizedBox(height: 12),
                              expensePanel,
                            ],
                          ))
                  : trendPanel);

        if (isWide) {
          return ListView(
            children: [
              summary,
              const SizedBox(height: 12),
              _buildNetSectionTabs(tabs),
              const SizedBox(height: 12),
              sectionBody,
            ],
          );
        }

        if (isMedium) {
          return ListView(
            children: [
              summary,
              const SizedBox(height: 12),
              _buildNetSectionTabs(tabs),
              const SizedBox(height: 12),
              sectionBody,
            ],
          );
        }

        return ListView(
          children: [
            summary,
            const SizedBox(height: 12),
            _buildNetSectionTabs(tabs),
            const SizedBox(height: 12),
            sectionBody,
          ],
        );
      },
    );
  }

  Widget _buildNetSectionTabs(List<String> tabs) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: List<Widget>.generate(tabs.length, (index) {
          final selected = _netSectionIndex == index;
          return ChoiceChip(
            label: Text(tabs[index]),
            selected: selected,
            onSelected: (_) => setState(() {
              _netSectionIndex = index;
              _lastNetSectionIndex = index;
              _persistNetSectionPreference(index);
            }),
            selectedColor: colorScheme.primaryContainer,
            labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? colorScheme.onPrimaryContainer : null,
            ),
            side: BorderSide(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNetExpenseTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(
          Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        headingTextStyle: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        dataTextStyle: Theme.of(context).textTheme.bodyMedium,
        columnSpacing: 22,
        columns: [
          DataColumn(label: Text('Date'.tr())),
          DataColumn(label: Text('Invoice'.tr())),
          DataColumn(label: Text('Account'.tr())),
          DataColumn(label: Text('Status'.tr())),
          DataColumn(label: Text('Total'.tr())),
        ],
        rows: _netExpenseRows
            .map(
              (row) => DataRow(
                onSelectChanged: (_) =>
                    _navigateToInvoice('expense', row.id, row.invoiceNumber),
                cells: [
                  DataCell(
                    Text(DateFormat('yyyy-MM-dd HH:mm').format(row.createdAt)),
                  ),
                  DataCell(Text(row.invoiceNumber)),
                  DataCell(Text(row.accountName)),
                  DataCell(Text(row.status)),
                  DataCell(Text(_currency.format(row.totalAmount))),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildNetTrendTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(
          Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        headingTextStyle: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        dataTextStyle: Theme.of(context).textTheme.bodyMedium,
        columnSpacing: 22,
        columns: [
          DataColumn(label: Text('Period'.tr())),
          DataColumn(label: Text('Gross Profit'.tr())),
          DataColumn(label: Text('Operating expenses'.tr())),
          DataColumn(label: Text('Net Profit'.tr())),
        ],
        rows: _netTrendRows
            .map(
              (row) => DataRow(
                cells: [
                  DataCell(Text(row.periodLabel)),
                  DataCell(Text(_currency.format(row.grossProfit))),
                  DataCell(Text(_currency.format(row.expenses))),
                  DataCell(Text(_currency.format(row.netProfit))),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildNetTrendChart() {
    final colorScheme = Theme.of(context).colorScheme;

    if (_netTrendRows.isEmpty) {
      return AppEmptyState(
        icon: Icons.timeline_outlined,
        title: 'No trend data for selected range.'.tr(),
        compact: true,
      );
    }

    if (_netTrendRows.length < 2) {
      return AppEmptyState(
        icon: Icons.show_chart_outlined,
        title: 'Not enough trend points.'.tr(),
        compact: true,
      );
    }

    final values = _netTrendRows
        .map((e) => e.netProfit)
        .toList(growable: false);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final span = (maxValue - minValue).abs() < 0.000001
        ? 1.0
        : (maxValue - minValue);

    final lineColor = colorScheme.secondary;
    final positivePointColor = colorScheme.primary;
    final negativePointColor = colorScheme.error;
    final zeroLineColor = colorScheme.outline.withValues(alpha: 0.65);

    return SizedBox(
      height: 240,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const left = 24.0;
          const right = 12.0;
          const top = 14.0;
          const bottom = 26.0;

          final width = (constraints.maxWidth - left - right).clamp(
            1.0,
            double.infinity,
          );
          final height = (constraints.maxHeight - top - bottom).clamp(
            1.0,
            double.infinity,
          );

          double toY(double value) {
            final normalized = (value - minValue) / span;
            return top + height - (normalized * height);
          }

          return Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            padding: const EdgeInsets.all(8),
            child: Stack(
              children: [
                CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _NetProfitTrendPainter(
                    rows: _netTrendRows,
                    minValue: minValue,
                    span: span,
                    left: left,
                    top: top,
                    width: width,
                    height: height,
                    lineColor: lineColor,
                    gridColor: colorScheme.outlineVariant.withValues(
                      alpha: 0.35,
                    ),
                    zeroLineColor: zeroLineColor,
                  ),
                ),
                ...List.generate(_netTrendRows.length, (i) {
                  final x = left + (width * i / (_netTrendRows.length - 1));
                  final y = toY(_netTrendRows[i].netProfit);
                  final pointColor = _netTrendRows[i].netProfit >= 0
                      ? positivePointColor
                      : negativePointColor;
                  return Positioned(
                    left: x - 5,
                    top: y - 5,
                    child: Tooltip(
                      message:
                          '${_netTrendRows[i].periodLabel}\n${'Gross Profit'.tr()}: ${_currency.format(_netTrendRows[i].grossProfit)}\n${'Operating expenses'.tr()}: ${_currency.format(_netTrendRows[i].expenses)}\n${'Net Profit'.tr()}: ${_currency.format(_netTrendRows[i].netProfit)}',
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: pointColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  List<_NetTrendPoint> _buildNetTrendRows({
    required List<DashboardProfitRecord> grossRows,
    required List<DashboardInvoiceRecord> expenseRows,
    required String granularity,
  }) {
    final buckets = SplayTreeMap<String, _NetTrendAccumulator>();

    for (final row in grossRows) {
      final key = _trendBucketKey(row.createdAt, granularity);
      final bucket = buckets.putIfAbsent(key, _NetTrendAccumulator.new);
      bucket.grossProfit += row.grossProfit;
    }

    for (final row in expenseRows) {
      final key = _trendBucketKey(row.createdAt, granularity);
      final bucket = buckets.putIfAbsent(key, _NetTrendAccumulator.new);
      bucket.expenses += row.totalAmount;
    }

    return buckets.entries
        .map(
          (entry) => _NetTrendPoint(
            periodLabel: entry.key,
            grossProfit: entry.value.grossProfit,
            expenses: entry.value.expenses,
          ),
        )
        .toList();
  }

  String _trendBucketKey(DateTime date, String granularity) {
    if (granularity == 'week') {
      final weekStart = date.subtract(Duration(days: date.weekday - 1));
      return DateFormat('yyyy-MM-dd').format(weekStart);
    }
    if (granularity == 'month') {
      return DateFormat('yyyy-MM').format(date);
    }
    return DateFormat('yyyy-MM-dd').format(date);
  }

  void _navigateToInvoice(String invoiceType, int invoiceId, String invoiceNo) {
    try {
      if (invoiceType == 'expense') {
        if (!mounted) return;
        context.go('/expenses');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'Opened'.tr()} ${'Expenses'.tr()}')),
        );
        return;
      }

      final route = buildInvoiceFocusRoute(
        invoiceType: invoiceType,
        invoiceId: invoiceId,
        fromDate: widget.fromDate,
        toDate: widget.toDate,
        sourcePage: _page,
        sourcePageSize: _pageSize,
        accountId: widget.accountId,
        categoryId: widget.categoryId,
      );
      if (!mounted) return;
      context.go(route);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${'Navigated to'.tr()} $invoiceType ${'invoice'.tr()} $invoiceNo',
          ),
        ),
      );
    } catch (e, st) {
      dev.log(
        'Failed navigation from drill-down row',
        name: 'DashboardDrillDownPage',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'Navigation failed'.tr()}: $e')),
      );
    }
  }
}

class _NetSummaryChip extends StatelessWidget {
  const _NetSummaryChip({
    required this.title,
    required this.value,
    this.emphasize = false,
  });

  final String title;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: emphasize
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: emphasize ? colorScheme.primary : colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _NetSectionCard extends StatelessWidget {
  const _NetSectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 18, color: colorScheme.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _NetMiniMetricItem {
  const _NetMiniMetricItem({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;
}

class _NetMiniMetrics extends StatelessWidget {
  const _NetMiniMetrics({required this.items});

  final List<_NetMiniMetricItem> items;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: item.emphasize
                    ? colorScheme.primaryContainer
                    : colorScheme.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: item.emphasize
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                ),
              ),
              child: Text(
                '${item.label}: ${item.value}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: item.emphasize
                      ? FontWeight.w800
                      : FontWeight.w600,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _NetMiniMetricItemCard extends StatelessWidget {
  const _NetMiniMetricItemCard({
    required this.label,
    required this.value,
    required this.icon,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: emphasize
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: emphasize ? colorScheme.primary : colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: emphasize
                  ? colorScheme.primary.withValues(alpha: 0.2)
                  : colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NetTrendPoint {
  const _NetTrendPoint({
    required this.periodLabel,
    required this.grossProfit,
    required this.expenses,
  });

  final String periodLabel;
  final double grossProfit;
  final double expenses;

  double get netProfit => grossProfit - expenses;
}

class _NetTrendAccumulator {
  double grossProfit = 0;
  double expenses = 0;
}

class _NetProfitTrendPainter extends CustomPainter {
  _NetProfitTrendPainter({
    required this.rows,
    required this.minValue,
    required this.span,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.lineColor,
    required this.gridColor,
    required this.zeroLineColor,
  });

  final List<_NetTrendPoint> rows;
  final double minValue;
  final double span;
  final double left;
  final double top;
  final double width;
  final double height;
  final Color lineColor;
  final Color gridColor;
  final Color zeroLineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (rows.length < 2) return;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = top + (height * i / 4);
      canvas.drawLine(Offset(left, y), Offset(left + width, y), grid);
    }

    double yFor(double value) {
      final normalized = (value - minValue) / span;
      return top + height - (normalized * height);
    }

    final maxValue = minValue + span;
    if (minValue <= 0 && maxValue >= 0) {
      final zeroY = yFor(0);
      canvas.drawLine(
        Offset(left, zeroY),
        Offset(left + width, zeroY),
        Paint()
          ..color = zeroLineColor
          ..strokeWidth = 1.4,
      );
    }

    final path = Path();
    for (var i = 0; i < rows.length; i++) {
      final x = left + (width * i / (rows.length - 1));
      final y = yFor(rows[i].netProfit);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [
            lineColor.withValues(alpha: 0.9),
            lineColor.withValues(alpha: 0.4),
          ],
          stops: const [0.1, 1.0],
        ).createShader(Rect.fromLTWH(left, top, width, height))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _NetProfitTrendPainter oldDelegate) {
    return oldDelegate.rows != rows ||
        oldDelegate.minValue != minValue ||
        oldDelegate.span != span ||
        oldDelegate.left != left ||
        oldDelegate.top != top ||
        oldDelegate.width != width ||
        oldDelegate.height != height ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.zeroLineColor != zeroLineColor;
  }
}
