import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:delta_erp/features/accounts/data/account_statement_repository.dart';

class AccountStatementState extends Equatable {
  const AccountStatementState({
    this.accountId,
    this.transactions = const <AccountStatementTransaction>[],
    this.currentBalance = 0,
    this.totalCount = 0,
    this.page = 0,
    this.pageSize = 50,
    this.fromDate,
    this.toDate,
    this.type = 'all',
    this.loading = false,
    this.error,
  });

  final int? accountId;
  final List<AccountStatementTransaction> transactions;
  final double currentBalance;
  final int totalCount;
  final int page;
  final int pageSize;
  final DateTime? fromDate;
  final DateTime? toDate;
  final String type;
  final bool loading;
  final String? error;

  int get totalPages =>
      totalCount == 0 ? 1 : ((totalCount - 1) ~/ pageSize) + 1;
  bool get canGoPrev => page > 0;
  bool get canGoNext => (page + 1) * pageSize < totalCount;
  int get offset => page * pageSize;
  int get showingFrom => totalCount == 0 ? 0 : offset + 1;
  int get showingTo => totalCount == 0 ? 0 : offset + transactions.length;

  AccountStatementState copyWith({
    int? accountId,
    List<AccountStatementTransaction>? transactions,
    double? currentBalance,
    int? totalCount,
    int? page,
    int? pageSize,
    DateTime? fromDate,
    DateTime? toDate,
    bool clearFromDate = false,
    bool clearToDate = false,
    String? type,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return AccountStatementState(
      accountId: accountId ?? this.accountId,
      transactions: transactions ?? this.transactions,
      currentBalance: currentBalance ?? this.currentBalance,
      totalCount: totalCount ?? this.totalCount,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      fromDate: clearFromDate ? null : (fromDate ?? this.fromDate),
      toDate: clearToDate ? null : (toDate ?? this.toDate),
      type: type ?? this.type,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    accountId,
    transactions,
    currentBalance,
    totalCount,
    page,
    pageSize,
    fromDate,
    toDate,
    type,
    loading,
    error,
  ];
}

class AccountStatementCubit extends Cubit<AccountStatementState> {
  AccountStatementCubit(this._repository)
    : super(const AccountStatementState());

  final AccountStatementRepository _repository;

  Future<void> loadForAccount(int accountId) async {
    emit(
      state.copyWith(
        accountId: accountId,
        page: 0,
        loading: true,
        clearError: true,
      ),
    );
    await _fetch();
  }

  Future<void> setFromDate(DateTime? date) async {
    emit(
      state.copyWith(fromDate: date, page: 0, loading: true, clearError: true),
    );
    await _fetch();
  }

  Future<void> setToDate(DateTime? date) async {
    emit(
      state.copyWith(toDate: date, page: 0, loading: true, clearError: true),
    );
    await _fetch();
  }

  Future<void> setType(String type) async {
    emit(state.copyWith(type: type, page: 0, loading: true, clearError: true));
    await _fetch();
  }

  Future<void> setPageSize(int pageSize) async {
    emit(
      state.copyWith(
        pageSize: pageSize,
        page: 0,
        loading: true,
        clearError: true,
      ),
    );
    await _fetch();
  }

  Future<void> nextPage() async {
    if (!state.canGoNext) return;
    emit(state.copyWith(page: state.page + 1, loading: true, clearError: true));
    await _fetch();
  }

  Future<void> previousPage() async {
    if (!state.canGoPrev) return;
    emit(state.copyWith(page: state.page - 1, loading: true, clearError: true));
    await _fetch();
  }

  Future<void> refresh() async {
    emit(state.copyWith(loading: true, clearError: true));
    await _fetch();
  }

  Future<void> clearFilters({
    int? defaultAccountId,
    bool resetAccount = false,
  }) async {
    emit(
      state.copyWith(
        clearFromDate: true,
        clearToDate: true,
        type: 'all',
        page: 0,
        accountId: resetAccount
            ? (defaultAccountId ?? state.accountId)
            : state.accountId,
        loading: true,
        clearError: true,
      ),
    );
    await _fetch();
  }

  Future<void> _fetch() async {
    final accountId = state.accountId;
    if (accountId == null) {
      emit(state.copyWith(loading: false, transactions: const []));
      return;
    }

    try {
      final items = await _repository.getAccountTransactionsPaginated(
        accountId: accountId,
        limit: state.pageSize,
        offset: state.offset,
        fromDate: state.fromDate,
        toDate: state.toDate,
        type: state.type,
      );
      final totalCount = await _repository.getAccountTransactionsCount(
        accountId: accountId,
        fromDate: state.fromDate,
        toDate: state.toDate,
        type: state.type,
      );
      final balance = await _repository.getAccountRunningBalance(accountId);
      emit(
        state.copyWith(
          transactions: items,
          currentBalance: balance,
          totalCount: totalCount,
          loading: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }
}
