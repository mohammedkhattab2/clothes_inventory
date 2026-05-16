import 'dart:developer' as dev;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:clothes_inventory/core/widgets/app_data_table.dart';
import 'package:clothes_inventory/core/widgets/app_error_banner.dart';
import 'package:clothes_inventory/core/widgets/app_loading_indicator.dart';
import 'package:clothes_inventory/features/accounts/data/account_statement_csv_service.dart';
import 'package:clothes_inventory/features/accounts/data/account_statement_repository.dart';
import 'package:clothes_inventory/features/accounts/data/accounts_repository.dart';
import 'package:clothes_inventory/features/accounts/presentation/account_statement_cubit.dart';
import 'package:clothes_inventory/features/dashboard/presentation/dashboard_cubit.dart';
import 'package:clothes_inventory/services/di/service_locator.dart';
import 'package:clothes_inventory/services/platform/folder_opener_service.dart';
import 'package:clothes_inventory/services/pdf/account_statement_pdf_service.dart';

class AccountStatementPage extends StatefulWidget {
  const AccountStatementPage({required this.initialAccountId, super.key});

  final int initialAccountId;

  @override
  State<AccountStatementPage> createState() => _AccountStatementPageState();
}

class _AccountStatementPageState extends State<AccountStatementPage> {
  late Future<List<AccountLookup>> _accountsFuture;
  bool _exportingPdf = false;
  bool _exportingCsv = false;
  String? _lastExportPath;

  @override
  void initState() {
    super.initState();
    _accountsFuture = _loadAllAccounts();
  }

  Future<List<AccountLookup>> _loadAllAccounts() async {
    return getIt<AccountsRepository>().listAllAccounts();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 900;
    final isDenseViewport = size.height < 820 || size.width < 1180;
    return BlocProvider(
      create: (_) =>
          getIt<AccountStatementCubit>()
            ..loadForAccount(widget.initialAccountId),
      child: BlocBuilder<AccountStatementCubit, AccountStatementState>(
        builder: (context, state) {
          final currency = NumberFormat.currency(symbol: '', decimalDigits: 2);
          final balanceColor = state.currentBalance >= 0
              ? Colors.red.shade700
              : Colors.green.shade700;

          return Padding(
            padding: EdgeInsets.all(isCompact ? 8 : 14),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer, // Softer background
                borderRadius: BorderRadius.circular(16), // More rounded corners
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ), // Lighter border
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: 0.05,
                    ), // Subtle shadow
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(isCompact ? 10 : 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Account Statement'.tr(),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${'Current Balance'.tr()}: ${currency.format(state.currentBalance)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: balanceColor,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.primary.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Text(
                            currency.format(state.currentBalance),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: balanceColor,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<List<AccountLookup>>(
                      future: _accountsFuture,
                      builder: (context, snapshot) {
                        final accounts =
                            snapshot.data ?? const <AccountLookup>[];
                        final selectedAccount = accounts
                            .where((a) => a.id == state.accountId)
                            .cast<AccountLookup?>()
                            .firstWhere((a) => a != null, orElse: () => null);
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 1100;

                            final accountField = DropdownButtonFormField<int>(
                              initialValue: state.accountId,
                              decoration: InputDecoration(
                                labelText: 'Account'.tr(),
                              ),
                              items: accounts
                                  .map(
                                    (a) => DropdownMenuItem<int>(
                                      value: a.id,
                                      child: Text(
                                        '${a.name} (${a.accountType})',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  context
                                      .read<AccountStatementCubit>()
                                      .loadForAccount(value);
                                }
                              },
                            );

                            final typeField = DropdownButtonFormField<String>(
                              initialValue: state.type,
                              decoration: InputDecoration(
                                labelText: 'Type'.tr(),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'all',
                                  child: Text('All'.tr()),
                                ),
                                DropdownMenuItem(
                                  value: 'sale',
                                  child: Text('Sale'.tr()),
                                ),
                                DropdownMenuItem(
                                  value: 'purchase',
                                  child: Text('Purchase'.tr()),
                                ),
                                DropdownMenuItem(
                                  value: 'payment',
                                  child: Text('Payment'.tr()),
                                ),
                                DropdownMenuItem(
                                  value: 'return',
                                  child: Text('Return'.tr()),
                                ),
                                DropdownMenuItem(
                                  value: 'cancellation',
                                  child: Text('Cancellation'.tr()),
                                ),
                                DropdownMenuItem(
                                  value: 'expense',
                                  child: Text('Expense'.tr()),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  context.read<AccountStatementCubit>().setType(
                                    value,
                                  );
                                }
                              },
                            );

                            final actions = [
                              FilledButton.icon(
                                onPressed:
                                    state.accountId == null || _exportingPdf
                                    ? null
                                    : () => _exportPdf(
                                        context,
                                        state,
                                        selectedAccount,
                                      ),
                                icon: _exportingPdf
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.picture_as_pdf_outlined),
                                label: Text('PDF'.tr()),
                              ),
                              FilledButton.icon(
                                onPressed:
                                    state.accountId == null || _exportingCsv
                                    ? null
                                    : () => _exportCsv(
                                        context,
                                        state,
                                        selectedAccount,
                                      ),
                                icon: _exportingCsv
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.table_view_outlined),
                                label: Text('CSV'.tr()),
                              ),
                              OutlinedButton.icon(
                                onPressed: _lastExportPath == null
                                    ? null
                                    : () => _openExportFolder(context),
                                icon: const Icon(Icons.folder_open_outlined),
                                label: Text('Open Folder'.tr()),
                              ),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  await context
                                      .read<AccountStatementCubit>()
                                      .clearFilters(
                                        defaultAccountId:
                                            widget.initialAccountId,
                                      );
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Filters cleared'.tr()),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.filter_alt_off_outlined),
                                label: Text('Clear Filters'.tr()),
                              ),
                            ];

                            if (compact) {
                              return Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    accountField,
                                    const SizedBox(height: 8),
                                    _DateButton(
                                      label: 'From'.tr(),
                                      value: state.fromDate,
                                      onPick: (value) => context
                                          .read<AccountStatementCubit>()
                                          .setFromDate(value),
                                    ),
                                    const SizedBox(height: 8),
                                    _DateButton(
                                      label: 'To'.tr(),
                                      value: state.toDate,
                                      onPick: (value) => context
                                          .read<AccountStatementCubit>()
                                          .setToDate(value),
                                    ),
                                    const SizedBox(height: 8),
                                    typeField,
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: actions,
                                    ),
                                    if (_lastExportPath != null) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        '${'Last'.tr()}: ${p.basename(_lastExportPath!)}',
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }

                            return Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(child: accountField),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _DateButton(
                                      label: 'From'.tr(),
                                      value: state.fromDate,
                                      onPick: (value) => context
                                          .read<AccountStatementCubit>()
                                          .setFromDate(value),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _DateButton(
                                      label: 'To'.tr(),
                                      value: state.toDate,
                                      onPick: (value) => context
                                          .read<AccountStatementCubit>()
                                          .setToDate(value),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: typeField),
                                  const SizedBox(width: 8),
                                  actions[0],
                                  const SizedBox(width: 8),
                                  actions[1],
                                  const SizedBox(width: 8),
                                  actions[2],
                                  if (_lastExportPath != null) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${'Last'.tr()}: ${p.basename(_lastExportPath!)}',
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 8),
                                  actions[3],
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    if (state.loading)
                      Expanded(
                        child: AppLoadingIndicator(
                          label: 'Loading statement...'.tr(),
                        ),
                      )
                    else if (state.error != null)
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 620),
                            child: AppErrorBanner(
                              message: state.error!,
                              onRetry: () => context
                                  .read<AccountStatementCubit>()
                                  .loadForAccount(
                                    state.accountId ?? widget.initialAccountId,
                                  ),
                              retryLabel: 'Refresh'.tr(),
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: colorScheme.outlineVariant,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: AppDataTable(
                                    useCard: false,
                                    headingRowHeight: isDenseViewport ? 42 : 46,
                                    dataRowMinHeight: isDenseViewport ? 40 : 44,
                                    dataRowMaxHeight: isDenseViewport ? 40 : 44,
                                    horizontalMargin: 10,
                                    columnSpacing: isDenseViewport ? 16 : 20,
                                    columns: [
                                      DataColumn(label: Text('Date'.tr())),
                                      DataColumn(label: Text('Type'.tr())),
                                      DataColumn(label: Text('Reference'.tr())),
                                      DataColumn(label: Text('Debit'.tr())),
                                      DataColumn(label: Text('Credit'.tr())),
                                      DataColumn(
                                        label: Text('Running Balance'.tr()),
                                      ),
                                    ],
                                    rows: state.transactions
                                        .map(
                                          (tx) => DataRow(
                                            onSelectChanged: (_) =>
                                                _navigateFromStatement(
                                                  tx,
                                                  state,
                                                ),
                                            cells: [
                                              DataCell(
                                                Text(
                                                  DateFormat(
                                                    'yyyy-MM-dd HH:mm',
                                                  ).format(tx.createdAt),
                                                ),
                                              ),
                                              DataCell(Text(tx.typeLabel)),
                                              DataCell(Text(tx.referenceLabel)),
                                              DataCell(
                                                Text(
                                                  tx.debit == 0
                                                      ? '-'
                                                      : currency.format(
                                                          tx.debit,
                                                        ),
                                                  style: TextStyle(
                                                    color: tx.debit > 0
                                                        ? Colors.red.shade700
                                                        : null,
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  tx.credit == 0
                                                      ? '-'
                                                      : currency.format(
                                                          tx.credit,
                                                        ),
                                                  style: TextStyle(
                                                    color: tx.credit > 0
                                                        ? Colors.green.shade700
                                                        : null,
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  currency.format(
                                                    tx.runningBalance,
                                                  ),
                                                  style: TextStyle(
                                                    color:
                                                        tx.runningBalance >= 0
                                                        ? Colors.red.shade700
                                                        : Colors.green.shade700,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                DropdownButton<int>(
                                  value: state.pageSize,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 25,
                                      child: Text('25'),
                                    ),
                                    DropdownMenuItem(
                                      value: 50,
                                      child: Text('50'),
                                    ),
                                    DropdownMenuItem(
                                      value: 100,
                                      child: Text('100'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      context
                                          .read<AccountStatementCubit>()
                                          .setPageSize(value);
                                    }
                                  },
                                ),
                                Text('rows/page'.tr()),
                                OutlinedButton.icon(
                                  onPressed: state.canGoPrev
                                      ? () => context
                                            .read<AccountStatementCubit>()
                                            .previousPage()
                                      : null,
                                  icon: const Icon(Icons.chevron_left),
                                  label: Text('Previous'.tr()),
                                ),
                                Text(
                                  '${'Page'.tr()} ${state.page + 1} / ${state.totalPages}',
                                ),
                                OutlinedButton.icon(
                                  onPressed: state.canGoNext
                                      ? () => context
                                            .read<AccountStatementCubit>()
                                            .nextPage()
                                      : null,
                                  icon: const Icon(Icons.chevron_right),
                                  label: Text('Next'.tr()),
                                ),
                                Text(
                                  '${'Showing'.tr()} ${state.showingFrom}-${state.showingTo} ${'of'.tr()} ${state.totalCount}',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _exportPdf(
    BuildContext context,
    AccountStatementState state,
    AccountLookup? selectedAccount,
  ) async {
    final accountId = state.accountId;
    if (accountId == null || selectedAccount == null) return;
    setState(() => _exportingPdf = true);
    try {
      final allRows = await getIt<AccountStatementRepository>()
          .getAccountTransactions(
            accountId: accountId,
            fromDate: state.fromDate,
            toDate: state.toDate,
            type: state.type,
          );
      final path = await getIt<AccountStatementPdfService>().exportToPdf(
        accountName: selectedAccount.name,
        accountType: selectedAccount.accountType,
        transactions: allRows,
        finalBalance: state.currentBalance,
        fromDate: state.fromDate,
        toDate: state.toDate,
      );
      if (mounted) {
        setState(() => _lastExportPath = path);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
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

  Future<void> _exportCsv(
    BuildContext context,
    AccountStatementState state,
    AccountLookup? selectedAccount,
  ) async {
    final accountId = state.accountId;
    if (accountId == null || selectedAccount == null) return;
    setState(() => _exportingCsv = true);
    try {
      final allRows = await getIt<AccountStatementRepository>()
          .getAccountTransactions(
            accountId: accountId,
            fromDate: state.fromDate,
            toDate: state.toDate,
            type: state.type,
          );
      final path = await getIt<AccountStatementCsvService>().exportToCsv(
        accountName: selectedAccount.name,
        accountType: selectedAccount.accountType,
        transactions: allRows,
        finalBalance: state.currentBalance,
        fromDate: state.fromDate,
        toDate: state.toDate,
      );
      if (mounted) {
        setState(() => _lastExportPath = path);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
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

  void _navigateFromStatement(
    AccountStatementTransaction tx,
    AccountStatementState state,
  ) {
    try {
      final invoiceType =
          tx.invoiceType ??
          (tx.type == 'purchase'
              ? 'purchase'
              : (tx.type == 'sale' ? 'sale' : null));
      final invoiceId = tx.invoiceId ?? tx.referenceId;
      if (invoiceType == null || invoiceId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No linked invoice for this row.'.tr())),
        );
        return;
      }

      final route = buildInvoiceFocusRoute(
        invoiceType: invoiceType,
        invoiceId: invoiceId,
        fromDate:
            state.fromDate ?? DateTime.now().subtract(const Duration(days: 30)),
        toDate: state.toDate ?? DateTime.now(),
        sourcePage: state.page,
        sourcePageSize: state.pageSize,
        accountId: state.accountId,
      );
      context.go(
        route.replaceAll('&navSource=drilldown', '&navSource=statement'),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${'Navigated to'.tr()} $invoiceType ${'invoice'.tr()} #$invoiceId',
          ),
        ),
      );
    } catch (e, st) {
      dev.log(
        'Statement row navigation failed',
        name: 'AccountStatementPage',
        error: e,
        stackTrace: st,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'Navigation failed'.tr()}: $e')),
      );
    }
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onPick;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? label
        : DateFormat('yyyy-MM-dd').format(value!);
    final compact = MediaQuery.sizeOf(context).height < 820;

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 8 : 10,
        ),
      ),
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        onPick(picked);
      },
      icon: const Icon(Icons.date_range_outlined),
      label: Text(text),
    );
  }
}
