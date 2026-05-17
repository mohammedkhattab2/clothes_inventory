import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:delta_erp/features/dashboard/data/dashboard_repository.dart';
import 'package:delta_erp/services/pdf/dashboard_pdf_service.dart';
import 'dart:typed_data';

String buildDashboardDrillDownRoute({
  required String kind,
  required DateTime fromDate,
  required DateTime toDate,
  required String granularity,
  int? categoryId,
  int? accountId,
}) {
  final from = Uri.encodeComponent(fromDate.toIso8601String());
  final to = Uri.encodeComponent(toDate.toIso8601String());
  final encodedGranularity = Uri.encodeComponent(granularity);
  final category = categoryId?.toString() ?? '';
  final account = accountId?.toString() ?? '';
  return '/dashboard/drilldown/$kind?from=$from&to=$to&granularity=$encodedGranularity&categoryId=$category&accountId=$account';
}

String buildInvoiceFocusRoute({
  required String invoiceType,
  required int invoiceId,
  required DateTime fromDate,
  required DateTime toDate,
  required int sourcePage,
  required int sourcePageSize,
  int? accountId,
  int? categoryId,
}) {
  final target = invoiceType == 'purchase' ? '/purchases' : '/sales';
  final from = Uri.encodeComponent(fromDate.toIso8601String());
  final to = Uri.encodeComponent(toDate.toIso8601String());
  final account = accountId?.toString() ?? '';
  final category = categoryId?.toString() ?? '';
  return '$target?selectedInvoiceId=$invoiceId&from=$from&to=$to&accountId=$account&categoryId=$category&page=$sourcePage&pageSize=$sourcePageSize&navSource=drilldown';
}

class DashboardState extends Equatable {
  const DashboardState({
    required this.fromDate,
    required this.toDate,
    this.granularity = 'day',
    this.categoryId,
    this.accountId,
    this.categories = const <DashboardFilterOption>[],
    this.accounts = const <DashboardFilterOption>[],
    this.snapshot,
    this.loading = false,
    this.exporting = false,
    this.lastExportPath,
    this.error,
  });

  final DateTime fromDate;
  final DateTime toDate;
  final String granularity;
  final int? categoryId;
  final int? accountId;
  final List<DashboardFilterOption> categories;
  final List<DashboardFilterOption> accounts;
  final DashboardSnapshot? snapshot;
  final bool loading;
  final bool exporting;
  final String? lastExportPath;
  final String? error;

  DashboardState copyWith({
    DateTime? fromDate,
    DateTime? toDate,
    String? granularity,
    int? categoryId,
    int? accountId,
    bool clearCategory = false,
    bool clearAccount = false,
    List<DashboardFilterOption>? categories,
    List<DashboardFilterOption>? accounts,
    DashboardSnapshot? snapshot,
    bool? loading,
    bool? exporting,
    String? lastExportPath,
    bool clearLastExportPath = false,
    String? error,
    bool clearError = false,
  }) {
    return DashboardState(
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      granularity: granularity ?? this.granularity,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      accountId: clearAccount ? null : (accountId ?? this.accountId),
      categories: categories ?? this.categories,
      accounts: accounts ?? this.accounts,
      snapshot: snapshot ?? this.snapshot,
      loading: loading ?? this.loading,
      exporting: exporting ?? this.exporting,
      lastExportPath: clearLastExportPath
          ? null
          : (lastExportPath ?? this.lastExportPath),
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    fromDate,
    toDate,
    granularity,
    categoryId,
    accountId,
    categories,
    accounts,
    snapshot,
    loading,
    exporting,
    lastExportPath,
    error,
  ];
}

class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit(this._repository, this._pdfService)
    : super(
        DashboardState(
          fromDate: DateTime.now().subtract(const Duration(days: 30)),
          toDate: DateTime.now(),
        ),
      );

  final DashboardRepository _repository;
  final DashboardPdfService _pdfService;

  Future<void> initialize() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final categories = await _repository.getCategories();
      final accounts = await _repository.getAccounts();
      final selectedAccountId = accounts.any((a) => a.id == state.accountId)
          ? state.accountId
          : null;
      final snapshot = await _repository.getDashboardSnapshot(
        from: state.fromDate,
        to: state.toDate,
        granularity: state.granularity,
        categoryId: state.categoryId,
        accountId: selectedAccountId,
      );
      emit(
        state.copyWith(
          categories: categories,
          accounts: accounts,
          accountId: selectedAccountId,
          clearAccount: selectedAccountId == null,
          snapshot: snapshot,
          loading: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: _userFacingError(e)));
    }
  }

  Future<void> setFromDate(DateTime value) async {
    emit(state.copyWith(fromDate: value, loading: true, clearError: true));
    await _refreshSnapshot();
  }

  Future<void> setToDate(DateTime value) async {
    emit(state.copyWith(toDate: value, loading: true, clearError: true));
    await _refreshSnapshot();
  }

  Future<void> setGranularity(String value) async {
    emit(state.copyWith(granularity: value, loading: true, clearError: true));
    await _refreshSnapshot();
  }

  Future<void> setCategory(int? value) async {
    emit(
      state.copyWith(
        categoryId: value,
        clearCategory: value == null,
        loading: true,
        clearError: true,
      ),
    );
    await _refreshSnapshot();
  }

  Future<void> setAccount(int? value) async {
    emit(
      state.copyWith(
        accountId: value,
        clearAccount: value == null,
        loading: true,
        clearError: true,
      ),
    );
    await _refreshSnapshot();
  }

  Future<void> clearFilters() async {
    emit(
      state.copyWith(
        fromDate: DateTime.now().subtract(const Duration(days: 30)),
        toDate: DateTime.now(),
        granularity: 'day',
        clearCategory: true,
        clearAccount: true,
        loading: true,
        clearError: true,
      ),
    );
    await _refreshSnapshot();
  }

  String selectedCategoryLabel() {
    if (state.categoryId == null) return 'All';
    for (final item in state.categories) {
      if (item.id == state.categoryId) {
        return item.name;
      }
    }
    return 'All';
  }

  String selectedAccountLabel() {
    if (state.accountId == null) return 'All';
    for (final item in state.accounts) {
      if (item.id == state.accountId) {
        return item.name;
      }
    }
    return 'All';
  }

  Future<String> exportDashboardPdf({
    required String targetPath,
    Uint8List? topProductsChart,
    Uint8List? trendChart,
    bool includeOwnerAnalytics = true,
    String? preparedByName,
  }) async {
    final snapshot = state.snapshot;
    if (snapshot == null) {
      throw StateError('Dashboard snapshot is not loaded yet.');
    }
    emit(state.copyWith(exporting: true, clearError: true));
    try {
      final path = await _pdfService.exportSummary(
        snapshot: snapshot,
        fromDate: state.fromDate,
        toDate: state.toDate,
        granularity: state.granularity,
        targetPath: targetPath,
        includeOwnerAnalytics: includeOwnerAnalytics,
        preparedByName: preparedByName,
        categoryLabel: selectedCategoryLabel(),
        accountLabel: selectedAccountLabel(),
        topProductsChart: topProductsChart,
        trendChart: trendChart,
      );
      emit(state.copyWith(exporting: false, lastExportPath: path));
      return path;
    } catch (e) {
      emit(state.copyWith(exporting: false, error: _userFacingError(e)));
      rethrow;
    }
  }

  String drillDownRouteFor(String kind) {
    return buildDashboardDrillDownRoute(
      kind: kind,
      fromDate: state.fromDate,
      toDate: state.toDate,
      granularity: state.granularity,
      categoryId: state.categoryId,
      accountId: state.accountId,
    );
  }

  String invoiceRouteFor({
    required String invoiceType,
    required int invoiceId,
    required int sourcePage,
    required int sourcePageSize,
    DateTime? fromDate,
    DateTime? toDate,
    int? accountId,
    int? categoryId,
  }) {
    return buildInvoiceFocusRoute(
      invoiceType: invoiceType,
      invoiceId: invoiceId,
      fromDate: fromDate ?? state.fromDate,
      toDate: toDate ?? state.toDate,
      sourcePage: sourcePage,
      sourcePageSize: sourcePageSize,
      accountId: accountId ?? state.accountId,
      categoryId: categoryId ?? state.categoryId,
    );
  }

  Future<void> _refreshSnapshot() async {
    try {
      final selectedAccountId =
          state.accountId != null &&
              state.accounts.any((a) => a.id == state.accountId)
          ? state.accountId
          : null;
      final snapshot = await _repository.getDashboardSnapshot(
        from: state.fromDate,
        to: state.toDate,
        granularity: state.granularity,
        categoryId: state.categoryId,
        accountId: selectedAccountId,
      );
      emit(
        state.copyWith(
          snapshot: snapshot,
          loading: false,
          accountId: selectedAccountId,
          clearAccount: selectedAccountId == null,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: _userFacingError(e)));
    }
  }

  String _userFacingError(Object error) {
    final raw = error.toString();
    if (raw.contains('Bad state: Dashboard snapshot is not loaded yet.')) {
      return 'dashboard.snapshot_unavailable';
    }
    return 'dashboard.unexpected_error';
  }
}
