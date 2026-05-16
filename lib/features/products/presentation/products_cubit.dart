import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:clothes_inventory/features/products/data/product_repository.dart';
import 'package:clothes_inventory/features/products/domain/product.dart';

class ProductsState extends Equatable {
  const ProductsState({
    this.items = const <Product>[],
    this.loading = false,
    this.error,
    this.query = '',
    this.barcode = '',
  });

  final List<Product> items;
  final bool loading;
  final String? error;
  final String query;
  final String barcode;

  ProductsState copyWith({
    List<Product>? items,
    bool? loading,
    String? error,
    String? query,
    String? barcode,
    bool clearError = false,
  }) {
    return ProductsState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      query: query ?? this.query,
      barcode: barcode ?? this.barcode,
    );
  }

  @override
  List<Object?> get props => [items, loading, error, query, barcode];
}

class ProductsBulkDeleteResult {
  const ProductsBulkDeleteResult({
    required this.deletedCount,
    required this.failed,
  });

  final int deletedCount;
  final Map<int, String> failed;

  int get failedCount => failed.length;
}

class ProductsCubit extends Cubit<ProductsState> {
  ProductsCubit(this._repository) : super(const ProductsState());

  final ProductRepository _repository;
  int _requestSerial = 0;

  bool _productMatchesSearch(Product p) {
    final nameQ = state.query.trim();
    final barcodeQ = state.barcode.trim();
    if (barcodeQ.isNotEmpty) {
      return (p.barcode ?? '').trim().toLowerCase() == barcodeQ.toLowerCase();
    }
    if (nameQ.isNotEmpty) {
      return p.name.toLowerCase().contains(nameQ.toLowerCase());
    }
    return true;
  }

  void _sortByName(List<Product> items) {
    items.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
  }

  Future<void> load({bool withLoading = true}) async {
    final requestId = ++_requestSerial;
    final query = state.query;
    final barcode = state.barcode;

    emit(state.copyWith(loading: withLoading, clearError: true));
    try {
      final items = await _repository.listProducts(
        nameQuery: query,
        barcode: barcode,
      );
      if (requestId != _requestSerial || isClosed) return;
      emit(state.copyWith(items: items, loading: false));
    } catch (e) {
      if (requestId != _requestSerial || isClosed) return;
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> searchByName(String query) async {
    emit(state.copyWith(query: query));
    await load(withLoading: false);
  }

  Future<void> searchByBarcode(String barcode) async {
    emit(state.copyWith(barcode: barcode));
    await load(withLoading: false);
  }

  Future<void> setFilters({String? query, String? barcode}) async {
    emit(
      state.copyWith(
        query: query ?? state.query,
        barcode: barcode ?? state.barcode,
      ),
    );
    await load(withLoading: false);
  }

  Future<void> clearSearch() async {
    emit(state.copyWith(query: '', barcode: ''));
    await load();
  }

  Future<void> create(Product product) async {
    final created = await _repository.createProduct(product);
    if (!_productMatchesSearch(created)) {
      emit(state.copyWith(loading: false, clearError: true));
      return;
    }
    final items = [...state.items]..removeWhere((p) => p.id == created.id);
    items.add(created);
    _sortByName(items);
    emit(state.copyWith(items: items, loading: false, clearError: true));
  }

  Future<void> update(Product product) async {
    await _repository.updateProduct(product);
    final id = product.id!;
    final items = [...state.items];
    final idx = items.indexWhere((p) => p.id == id);
    if (!_productMatchesSearch(product)) {
      if (idx >= 0) items.removeAt(idx);
      emit(state.copyWith(items: items, loading: false, clearError: true));
      return;
    }
    final stock = idx >= 0 ? items[idx].currentStock : product.currentStock;
    final merged = product.copyWith(currentStock: stock);
    if (idx >= 0) {
      items[idx] = merged;
    } else {
      items.add(merged);
    }
    _sortByName(items);
    emit(state.copyWith(items: items, loading: false, clearError: true));
  }

  Future<void> delete(int id) async {
    await _repository.deleteProduct(id);
    final items = state.items.where((p) => p.id != id).toList();
    emit(state.copyWith(items: items, loading: false, clearError: true));
  }

  Future<ProductsBulkDeleteResult> deleteMany(List<int> ids) async {
    final uniqueIds = ids.toSet().toList(growable: false);
    var deletedCount = 0;
    final failed = <int, String>{};

    for (final id in uniqueIds) {
      try {
        await _repository.deleteProduct(id);
        deletedCount++;
      } catch (e) {
        failed[id] = e.toString();
      }
    }

    final succeededIds = uniqueIds
        .where((id) => !failed.containsKey(id))
        .toSet();
    final items = state.items.where((p) {
      final pid = p.id;
      if (pid == null) return true;
      return !succeededIds.contains(pid);
    }).toList();
    emit(state.copyWith(items: items, loading: false, clearError: true));
    return ProductsBulkDeleteResult(deletedCount: deletedCount, failed: failed);
  }
}
