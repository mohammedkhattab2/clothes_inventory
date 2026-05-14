import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:clothes_inventory/core/utils/number_utils.dart';
import 'package:clothes_inventory/features/products/domain/product.dart';
import 'package:clothes_inventory/features/sales/data/sales_repository.dart';
import 'package:clothes_inventory/features/sales/domain/sale_models.dart';

class SalesState extends Equatable {
  const SalesState({
    this.cart = const <SaleDraftItem>[],
    this.customerId,
    this.newCustomerName = '',
    this.taxPercentage = 0,
    this.paidAmount = 0,
    this.paymentMethod = PaymentMethod.cash,
    this.loading = false,
    this.error,
    this.successInvoiceId,
    this.successEvent,
    this.pendingSaleId,
  });

  final List<SaleDraftItem> cart;
  final int? customerId;
  final String newCustomerName;
  final double taxPercentage;
  final double paidAmount;
  final PaymentMethod paymentMethod;
  final bool loading;
  final String? error;
  final int? successInvoiceId;
  final String? successEvent;
  final int? pendingSaleId;

  double get subtotal =>
      roundCurrency(cart.fold<double>(0, (sum, item) => sum + item.lineTotal));

  double get taxAmount => roundCurrency(subtotal * (taxPercentage / 100));

  double get total => roundCurrency(subtotal + taxAmount);

  SalesState copyWith({
    List<SaleDraftItem>? cart,
    int? customerId,
    String? newCustomerName,
    double? taxPercentage,
    double? paidAmount,
    PaymentMethod? paymentMethod,
    bool? loading,
    String? error,
    int? successInvoiceId,
    String? successEvent,
    int? pendingSaleId,
    bool clearError = false,
    bool clearSuccessEvent = false,
    bool clearPendingSaleId = false,
  }) {
    return SalesState(
      cart: cart ?? this.cart,
      customerId: customerId ?? this.customerId,
      newCustomerName: newCustomerName ?? this.newCustomerName,
      taxPercentage: taxPercentage ?? this.taxPercentage,
      paidAmount: paidAmount ?? this.paidAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      successInvoiceId: successInvoiceId,
      successEvent: clearSuccessEvent
          ? null
          : (successEvent ?? this.successEvent),
      pendingSaleId: clearPendingSaleId
          ? null
          : (pendingSaleId ?? this.pendingSaleId),
    );
  }

  @override
  List<Object?> get props => [
    cart,
    customerId,
    newCustomerName,
    taxPercentage,
    paidAmount,
    paymentMethod,
    loading,
    error,
    successInvoiceId,
    successEvent,
    pendingSaleId,
  ];
}

class SalesCubit extends Cubit<SalesState> {
  SalesCubit(this._repository) : super(const SalesState());

  final SalesRepository _repository;

  void clearTransientFeedback({bool clearError = false}) {
    emit(
      state.copyWith(
        successInvoiceId: null,
        clearSuccessEvent: true,
        clearError: clearError,
      ),
    );
  }

  void setCustomerId(int? accountId) {
    emit(state.copyWith(customerId: accountId));
  }

  void setNewCustomerName(String value) {
    emit(state.copyWith(newCustomerName: value));
  }

  void setPaidAmount(double value) {
    emit(state.copyWith(paidAmount: roundCurrency(value)));
  }

  void setTaxPercentage(double value) {
    final normalized = value.clamp(0, 100).toDouble();
    emit(state.copyWith(taxPercentage: roundCurrency(normalized)));
  }

  void setPaymentMethod(PaymentMethod method) {
    emit(state.copyWith(paymentMethod: method));
  }

  void addProduct(Product product, {double? initialUnitPrice}) {
    if (product.currentStock <= 0) {
      emit(state.copyWith(error: 'Insufficient stock for this product.'));
      return;
    }

    final idx = state.cart.indexWhere((x) => x.productId == product.id);
    if (idx == -1) {
      if (1 > product.currentStock + 0.000001) {
        emit(state.copyWith(error: 'Insufficient stock for this product.'));
        return;
      }

      final selectedPrice = roundCurrency(
        initialUnitPrice ?? product.salePrice,
      );
      if (selectedPrice < product.purchasePrice - 0.000001) {
        emit(
          state.copyWith(
            error: 'Sale price cannot be less than purchase price.',
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          cart: [
            ...state.cart,
            SaleDraftItem(
              productId: product.id!,
              productName: product.name,
              unitType: product.unitType.name,
              availableStock: product.currentStock,
              minUnitPrice: product.purchasePrice,
              quantity: 1,
              unitPrice: selectedPrice,
            ),
          ],
        ),
      );
      return;
    }

    final updated = [...state.cart];
    final current = updated[idx];
    final nextQty = current.quantity + 1;
    if (nextQty > product.currentStock + 0.000001) {
      emit(
        state.copyWith(
          error:
              'Cannot add more than available stock (${product.currentStock.toStringAsFixed(0)}).',
        ),
      );
      return;
    }
    updated[idx] = current.copyWith(quantity: roundQuantity(nextQty));
    emit(state.copyWith(cart: updated));
  }

  void updateItem(
    int productId, {
    double? quantity,
    double? unitPrice,
    double? discount,
  }) {
    final updated = [...state.cart];
    final idx = updated.indexWhere((x) => x.productId == productId);
    if (idx == -1) return;

    final current = updated[idx];
    final nextQty = roundQuantity(quantity ?? current.quantity);
    if (nextQty <= 0) {
      emit(state.copyWith(error: 'Quantity must be greater than zero.'));
      return;
    }
    if (current.unitType == UnitType.piece.name && !isIntegerLike(nextQty)) {
      emit(state.copyWith(error: 'Piece products require whole quantity.'));
      return;
    }
    if (nextQty > current.availableStock + 0.000001) {
      emit(state.copyWith(error: 'Cannot sell more than available stock.'));
      return;
    }

    final nextUnitPrice = roundCurrency(unitPrice ?? current.unitPrice);
    if (nextUnitPrice < current.minUnitPrice - 0.000001) {
      emit(
        state.copyWith(error: 'Sale price cannot be less than purchase price.'),
      );
      return;
    }

    updated[idx] = current.copyWith(
      quantity: nextQty,
      unitPrice: nextUnitPrice,
      discount: roundCurrency(discount ?? current.discount),
    );
    emit(state.copyWith(cart: updated, clearError: true));
  }

  void removeItem(int productId) {
    emit(
      state.copyWith(
        cart: state.cart.where((x) => x.productId != productId).toList(),
      ),
    );
  }

  Future<void> checkout({
    String? notes,
    bool isPending = false,
    int? pendingSaleIdOverride,
  }) async {
    if (state.cart.isEmpty) {
      emit(state.copyWith(error: 'Add at least one product.'));
      return;
    }

    final pendingSaleId = pendingSaleIdOverride ?? state.pendingSaleId;

    if (!isPending && pendingSaleId != null) {
      await settlePendingSale(
        saleId: pendingSaleId,
        paidAmount: state.paidAmount,
        paymentMethod: state.paymentMethod,
      );
      return;
    }

    emit(
      state.copyWith(
        loading: true,
        clearError: true,
        successInvoiceId: null,
        clearSuccessEvent: true,
      ),
    );

    try {
      final productIds = state.cart.map((item) => item.productId).toList();
      final liveStockByProduct = await _repository.getCurrentStocksForProducts(
        productIds,
      );

      final syncedCart = state.cart
          .map(
            (item) => item.copyWith(
              availableStock: liveStockByProduct[item.productId] ?? 0,
            ),
          )
          .toList();

      final hasInsufficient = syncedCart.any(
        (item) => item.quantity > item.availableStock + 0.000001,
      );
      if (hasInsufficient) {
        emit(
          state.copyWith(
            loading: false,
            cart: syncedCart,
            error: 'Insufficient stock for one or more products.',
          ),
        );
        return;
      }

      final hasBelowCostPrice = syncedCart.any(
        (item) => item.unitPrice < item.minUnitPrice - 0.000001,
      );
      if (hasBelowCostPrice) {
        emit(
          state.copyWith(
            loading: false,
            cart: syncedCart,
            error: 'Sale price cannot be less than purchase price.',
          ),
        );
        return;
      }

      final saleId = await _repository.createSale(
        SaleCreateRequest(
          customerId: state.customerId,
          newCustomerName: state.newCustomerName.trim().isEmpty
              ? null
              : state.newCustomerName.trim(),
          items: syncedCart,
          taxPercentage: state.taxPercentage,
          paidAmount: state.paidAmount,
          paymentMethod: state.paymentMethod,
          isPending: isPending,
          pendingSaleId: pendingSaleId,
          notes: notes,
        ),
      );

      emit(
        SalesState(
          successInvoiceId: saleId,
          paymentMethod: state.paymentMethod,
          successEvent: isPending ? 'pending_saved' : 'sale_saved',
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: _humanizeError(e)));
    }
  }

  Future<void> settlePendingSale({
    required int saleId,
    required double paidAmount,
    required PaymentMethod paymentMethod,
  }) async {
    emit(
      state.copyWith(
        loading: true,
        clearError: true,
        successInvoiceId: null,
        clearSuccessEvent: true,
      ),
    );

    try {
      await _repository.settlePendingSale(
        saleId: saleId,
        paidAmount: paidAmount,
        paymentMethod: paymentMethod,
      );
      emit(
        state.copyWith(
          loading: false,
          successInvoiceId: saleId,
          successEvent: 'pending_completed',
          clearPendingSaleId: true,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: _humanizeError(e)));
    }
  }

  Future<void> loadPendingInvoiceToCart(int saleId) async {
    emit(
      state.copyWith(
        loading: true,
        clearError: true,
        successInvoiceId: null,
        clearSuccessEvent: true,
      ),
    );

    try {
      final draft = await _repository.loadPendingSaleDraft(saleId);
      emit(
        SalesState(
          cart: draft.items,
          customerId: draft.customerId,
          newCustomerName: draft.customerId == null
              ? (draft.customerName ?? '')
              : '',
          taxPercentage: draft.taxPercentage,
          paidAmount: 0,
          paymentMethod: PaymentMethod.cash,
          successEvent: 'pending_loaded',
          pendingSaleId: draft.saleId,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: _humanizeError(e)));
    }
  }

  Future<void> returnSaleItem({
    required int saleId,
    required int saleItemId,
    required double quantity,
    required PaymentMethod paymentMethod,
    String? reason,
  }) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _repository.returnSaleItem(
        saleId: saleId,
        saleItemId: saleItemId,
        quantity: quantity,
        paymentMethod: paymentMethod,
        reason: reason,
      );
      emit(state.copyWith(loading: false));
    } catch (e) {
      emit(state.copyWith(loading: false, error: _humanizeError(e)));
    }
  }

  Future<void> cancelSale(int saleId) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _repository.cancelSale(saleId);
      emit(state.copyWith(loading: false));
    } catch (e) {
      emit(state.copyWith(loading: false, error: _humanizeError(e)));
    }
  }

  String _humanizeError(Object error) {
    final raw = error.toString().replaceFirst('Bad state: ', '').trim();
    final lower = raw.toLowerCase();

    if (lower.contains('insufficient stock')) {
      return 'Insufficient stock for one or more products.';
    }
    if (lower.contains('stock movement quantity must be greater than zero')) {
      return 'Quantity must be greater than zero.';
    }
    if (lower.contains('sale price cannot be less than purchase price')) {
      return 'Sale price cannot be less than purchase price.';
    }

    return raw;
  }
}
