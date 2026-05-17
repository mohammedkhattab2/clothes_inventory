import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:delta_erp/core/utils/number_utils.dart';
import 'package:delta_erp/features/products/domain/product.dart';
import 'package:delta_erp/features/purchases/data/purchases_repository.dart';
import 'package:delta_erp/features/purchases/domain/purchase_models.dart';
import 'package:delta_erp/features/sales/domain/sale_models.dart';

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
    this.successEvent,
    this.editingPurchaseId,
    this.amendmentStockCreditByProduct = const <int, double>{},
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
  final String? successEvent;

  /// When set, completing the purchase calls [PurchasesRepository.amendPurchase].
  final int? editingPurchaseId;

  /// Per-product quantities on the invoice when amendment mode was loaded.
  final Map<int, double> amendmentStockCreditByProduct;

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
    String? successEvent,
    int? editingPurchaseId,
    Map<int, double>? amendmentStockCreditByProduct,
    bool clearError = false,
    bool clearSuccessEvent = false,
    bool clearEditingPurchaseId = false,
    bool clearAmendmentStockCredit = false,
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
      successEvent: clearSuccessEvent
          ? null
          : (successEvent ?? this.successEvent),
      editingPurchaseId: clearEditingPurchaseId
          ? null
          : (editingPurchaseId ?? this.editingPurchaseId),
      amendmentStockCreditByProduct:
          clearEditingPurchaseId || clearAmendmentStockCredit
          ? const <int, double>{}
          : (amendmentStockCreditByProduct ??
              this.amendmentStockCreditByProduct),
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
    successEvent,
    editingPurchaseId,
    amendmentStockCreditByProduct,
  ];
}

class PurchasesCubit extends Cubit<PurchasesState> {
  PurchasesCubit(this._repository) : super(const PurchasesState());

  final PurchasesRepository _repository;

  void clearTransientFeedback({bool clearError = false}) {
    emit(
      state.copyWith(
        successInvoiceId: null,
        clearSuccessEvent: true,
        clearError: clearError,
      ),
    );
  }

  /// Clears the cart and exits “amend invoice in cart” mode.
  void clearInvoiceAmendment() {
    emit(const PurchasesState());
  }

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

  String _humanizeError(Object error) {
    final raw = _errorMessage(error);
    final lower = raw.toLowerCase();

    if (lower.contains('insufficient stock')) {
      return 'Insufficient stock for one or more products.';
    }
    if (lower.contains('cannot amend a purchase that has returns')) {
      return 'purchase.amend_blocked_returns';
    }
    if (lower.contains('this invoice cannot be amended')) {
      return 'purchase.amend_blocked_status';
    }
    if (lower.contains('purchase ledger credit entry missing')) {
      return 'purchase.amend_blocked_ledger';
    }

    return raw;
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

  /// Adds [quantityToAdd] to the cart line for [product], or creates a new line.
  /// Used when creating a product from the purchase entry dialog with an explicit quantity.
  void addProductWithQuantity(Product product, double quantityToAdd) {
    final pid = product.id;
    if (pid == null) return;
    final delta = roundQuantity(quantityToAdd);
    if (delta <= 0) {
      return;
    }

    final idx = state.cart.indexWhere((x) => x.productId == pid);
    if (idx == -1) {
      if (product.unitType == UnitType.piece && !isIntegerLike(delta)) {
        emit(
          state.copyWith(error: 'Piece products require integer quantity.'),
        );
        return;
      }
      emit(
        state.copyWith(
          cart: [
            ...state.cart,
            PurchaseDraftItem(
              productId: pid,
              productName: product.name,
              unitType: product.unitType.name,
              quantity: delta,
              unitPrice: product.purchasePrice,
            ),
          ],
          clearError: true,
        ),
      );
      return;
    }

    final updated = [...state.cart];
    final current = updated[idx];
    final nextQty = roundQuantity(current.quantity + delta);
    if (current.unitType == UnitType.piece.name && !isIntegerLike(nextQty)) {
      emit(
        state.copyWith(error: 'Piece products require integer quantity.'),
      );
      return;
    }
    updated[idx] = current.copyWith(quantity: nextQty);
    emit(state.copyWith(cart: updated, clearError: true));
  }

  /// When an existing product is edited from the add-product dialog, keep cart line price in sync.
  void syncCartLinePurchasePrice(int productId, double unitPrice) {
    final updated = [...state.cart];
    final idx = updated.indexWhere((x) => x.productId == productId);
    if (idx == -1) return;
    final rounded = roundCurrency(unitPrice);
    updated[idx] = updated[idx].copyWith(unitPrice: rounded);
    emit(state.copyWith(cart: updated, clearError: true));
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
      emit(state.copyWith(error: 'Piece products require integer quantity.'));
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
      state.copyWith(
        loading: true,
        clearError: true,
        successInvoiceId: null,
        clearSuccessEvent: true,
      ),
    );
    try {
      final credit = state.amendmentStockCreditByProduct;
      final isAmending = state.editingPurchaseId != null;

      if (isAmending) {
        final productIds = state.cart.map((e) => e.productId).toList();
        final liveByProduct =
            await _repository.getCurrentStocksForProducts(productIds);
        final newByProduct = <int, double>{};
        for (final item in state.cart) {
          final q = roundQuantity(item.quantity);
          newByProduct[item.productId] =
              roundQuantity((newByProduct[item.productId] ?? 0) + q);
        }
        for (final entry in credit.entries) {
          newByProduct.putIfAbsent(entry.key, () => 0);
        }
        for (final entry in credit.entries) {
          final pid = entry.key;
          final oldQ = roundQuantity(entry.value);
          final live = liveByProduct[pid] ?? 0;
          final newTotal = roundQuantity(newByProduct[pid] ?? 0);
          final minRequired =
              (oldQ - live).clamp(0.0, double.infinity).toDouble();
          if (newTotal + 0.000001 < minRequired) {
            emit(
              state.copyWith(
                loading: false,
                error: 'Insufficient stock for one or more products.',
              ),
            );
            return;
          }
        }
      }

      if (state.editingPurchaseId != null) {
        final amendmentId = state.editingPurchaseId!;
        await _repository.amendPurchase(
          PurchaseAmendRequest(
            purchaseId: amendmentId,
            items: state.cart,
            headerDiscountKind: state.headerDiscountKind,
            headerDiscountValue: state.headerDiscountValue,
          ),
        );
        emit(
          PurchasesState(
            successInvoiceId: amendmentId,
            paymentMethod: state.paymentMethod,
            successEvent: 'purchase_amended',
          ),
        );
        return;
      }

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
      emit(state.copyWith(loading: false, error: _humanizeError(e)));
    }
  }

  Future<void> loadPurchaseForAmendment(int purchaseId) async {
    emit(
      state.copyWith(
        loading: true,
        clearError: true,
        successInvoiceId: null,
        clearSuccessEvent: true,
      ),
    );

    try {
      final draft = await _repository.loadPurchaseDraftForAmendment(purchaseId);
      final pay = draft.amendmentPayments!;

      final double paidAmt;
      final double paidWlt;
      switch (pay.method) {
        case PaymentMethod.cash:
          paidAmt = roundCurrency(pay.paidCash);
          paidWlt = 0;
        case PaymentMethod.vodafoneCash:
          paidAmt = roundCurrency(pay.paidCash);
          paidWlt = 0;
        case PaymentMethod.visa:
          paidAmt = roundCurrency(pay.paidCash);
          paidWlt = 0;
        case PaymentMethod.cashAndWallet:
          paidAmt = roundCurrency(pay.paidCash);
          paidWlt = roundCurrency(pay.paidWallet);
      }

      emit(
        PurchasesState(
          supplierId: draft.supplierId,
          cart: draft.items,
          headerDiscountKind: draft.headerDiscountKind,
          headerDiscountValue: draft.headerDiscountValue,
          paidAmount: roundCurrency(paidAmt + paidWlt),
          paymentMethod: pay.method == PaymentMethod.cashAndWallet
              ? PaymentMethod.cash
              : pay.method,
          successEvent: 'invoice_amendment_loaded',
          editingPurchaseId: draft.purchaseId,
          amendmentStockCreditByProduct: draft.amendmentStockCreditByProduct,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: _humanizeError(e)));
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
