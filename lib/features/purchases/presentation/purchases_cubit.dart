import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:clothes_inventory/core/utils/number_utils.dart';
import 'package:clothes_inventory/features/products/domain/product.dart';
import 'package:clothes_inventory/features/purchases/data/purchases_repository.dart';
import 'package:clothes_inventory/features/purchases/domain/purchase_models.dart';
import 'package:clothes_inventory/features/sales/domain/sale_models.dart';

class PurchasesState extends Equatable {
  const PurchasesState({
    this.supplierId,
    this.cart = const <PurchaseDraftItem>[],
    this.headerDiscountKind = InvoiceHeaderDiscountKind.percent,
    this.headerDiscountValue = 0,
    this.paidAmount = 0,
    this.paymentMethod = PaymentMethod.cash,
    this.loading = false,
    this.error,
    this.successInvoiceId,
  });

  final int? supplierId;
  final List<PurchaseDraftItem> cart;
  final InvoiceHeaderDiscountKind headerDiscountKind;
  final double headerDiscountValue;
  final double paidAmount;
  final PaymentMethod paymentMethod;
  final bool loading;
  final String? error;
  final int? successInvoiceId;

  double get subtotal =>
      roundCurrency(cart.fold<double>(0, (sum, item) => sum + item.lineTotal));

  double get headerDiscountAmount => computeInvoiceHeaderDiscountAmount(
        subtotal: subtotal,
        kind: headerDiscountKind,
        value: headerDiscountValue,
      );

  double get total => roundCurrency(subtotal - headerDiscountAmount);

  PurchasesState copyWith({
    int? supplierId,
    List<PurchaseDraftItem>? cart,
    InvoiceHeaderDiscountKind? headerDiscountKind,
    double? headerDiscountValue,
    double? paidAmount,
    PaymentMethod? paymentMethod,
    bool? loading,
    String? error,
    int? successInvoiceId,
    bool clearError = false,
  }) {
    return PurchasesState(
      supplierId: supplierId ?? this.supplierId,
      cart: cart ?? this.cart,
      headerDiscountKind: headerDiscountKind ?? this.headerDiscountKind,
      headerDiscountValue: headerDiscountValue ?? this.headerDiscountValue,
      paidAmount: paidAmount ?? this.paidAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      successInvoiceId: successInvoiceId,
    );
  }

  @override
  List<Object?> get props => [
    supplierId,
    cart,
    headerDiscountKind,
    headerDiscountValue,
    paidAmount,
    paymentMethod,
    loading,
    error,
    successInvoiceId,
  ];
}

class PurchasesCubit extends Cubit<PurchasesState> {
  PurchasesCubit(this._repository) : super(const PurchasesState());

  final PurchasesRepository _repository;

  String _errorMessage(Object error) {
    if (error is StateError) {
      return error.message.toString();
    }
    const badStatePrefix = 'Bad state: ';
    final text = error.toString();
    return text.startsWith(badStatePrefix)
        ? text.substring(badStatePrefix.length)
        : text;
  }

  void setSupplier(int? accountId) {
    emit(state.copyWith(supplierId: accountId));
  }

  void setPaidAmount(double value) {
    emit(state.copyWith(paidAmount: roundCurrency(value)));
  }

  void setHeaderDiscountKind(InvoiceHeaderDiscountKind kind) {
    emit(state.copyWith(headerDiscountKind: kind));
  }

  void setHeaderDiscountValue(double value) {
    final normalized = state.headerDiscountKind == InvoiceHeaderDiscountKind.percent
        ? roundCurrency(value.clamp(0, 100))
        : roundCurrency(value.clamp(0, double.infinity));
    emit(state.copyWith(headerDiscountValue: normalized));
  }

  void setPaymentMethod(PaymentMethod method) {
    emit(state.copyWith(paymentMethod: method));
  }

  void addProduct(Product product) {
    final idx = state.cart.indexWhere((x) => x.productId == product.id);
    if (idx == -1) {
      emit(
        state.copyWith(
          cart: [
            ...state.cart,
            PurchaseDraftItem(
              productId: product.id!,
              productName: product.name,
              unitType: product.unitType.name,
              quantity: 1,
              unitPrice: product.purchasePrice,
            ),
          ],
        ),
      );
      return;
    }

    final updated = [...state.cart];
    final current = updated[idx];
    updated[idx] = current.copyWith(
      quantity: roundQuantity(current.quantity + 1),
    );
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
    if (current.unitType == UnitType.piece.name && !isIntegerLike(nextQty)) {
      emit(state.copyWith(error: 'Piece products require whole quantity.'));
      return;
    }

    updated[idx] = current.copyWith(
      quantity: nextQty,
      unitPrice: roundCurrency(unitPrice ?? current.unitPrice),
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

  Future<void> checkout({String? notes}) async {
    if (state.supplierId == null) {
      emit(state.copyWith(error: 'Supplier is required.'));
      return;
    }
    if (state.cart.isEmpty) {
      emit(state.copyWith(error: 'Add at least one product.'));
      return;
    }

    emit(
      state.copyWith(loading: true, clearError: true, successInvoiceId: null),
    );
    try {
      final id = await _repository.createPurchase(
        PurchaseCreateRequest(
          supplierId: state.supplierId!,
          items: state.cart,
          headerDiscountKind: state.headerDiscountKind,
          headerDiscountValue: state.headerDiscountValue,
          paidAmount: state.paidAmount,
          paymentMethod: state.paymentMethod,
          notes: notes,
        ),
      );
      emit(
        PurchasesState(
          successInvoiceId: id,
          paymentMethod: state.paymentMethod,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: _errorMessage(e)));
    }
  }

  Future<void> returnPurchaseItem({
    required int purchaseId,
    required int purchaseItemId,
    required double quantity,
    String? reason,
  }) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _repository.returnPurchaseItem(
        purchaseId: purchaseId,
        purchaseItemId: purchaseItemId,
        quantity: quantity,
        reason: reason,
      );
      emit(state.copyWith(loading: false));
    } catch (e) {
      emit(state.copyWith(loading: false, error: _errorMessage(e)));
    }
  }

  Future<void> cancelPurchase(int purchaseId) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _repository.cancelPurchase(purchaseId);
      emit(state.copyWith(loading: false));
    } catch (e) {
      emit(state.copyWith(loading: false, error: _errorMessage(e)));
    }
  }
}
