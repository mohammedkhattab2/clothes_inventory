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
    this.customerPhone = '',
    this.headerDiscountKind = InvoiceHeaderDiscountKind.percent,
    this.headerDiscountValue = 0,
    this.paidAmount = 0,
    this.paidWalletAmount = 0,
    this.paymentMethod = PaymentMethod.cash,
    this.loading = false,
    this.error,
    this.successInvoiceId,
    this.successEvent,
    this.pendingSaleId,
    this.editingSaleId,
    this.amendmentStockCreditByProduct = const <int, double>{},
  });

  final List<SaleDraftItem> cart;
  final int? customerId;
  final String newCustomerName;
  final String customerPhone;
  final InvoiceHeaderDiscountKind headerDiscountKind;
  final double headerDiscountValue;
  final double paidAmount;
  /// Wallet portion when [paymentMethod] is [PaymentMethod.cashAndWallet].
  final double paidWalletAmount;
  final PaymentMethod paymentMethod;
  final bool loading;
  final String? error;
  final int? successInvoiceId;
  final String? successEvent;
  final int? pendingSaleId;

  /// When set, completing the sale calls [SalesRepository.amendSale] instead of
  /// creating a new invoice.
  final int? editingSaleId;

  /// Quantities that were on the invoice when amendment load started; used to
  /// offset live stock while original sale `out` movements still exist.
  final Map<int, double> amendmentStockCreditByProduct;

  double get subtotal =>
      roundCurrency(cart.fold<double>(0, (sum, item) => sum + item.lineTotal));

  double get headerDiscountAmount => computeInvoiceHeaderDiscountAmount(
        subtotal: subtotal,
        kind: headerDiscountKind,
        value: headerDiscountValue,
      );

  double get total => roundCurrency(subtotal - headerDiscountAmount);

  double get effectivePaidTotal {
    switch (paymentMethod) {
      case PaymentMethod.cashAndWallet:
        return roundCurrency(paidAmount + paidWalletAmount);
      case PaymentMethod.cash:
      case PaymentMethod.vodafoneCash:
      case PaymentMethod.visa:
        return paidAmount;
    }
  }

  SalesState copyWith({
    List<SaleDraftItem>? cart,
    int? customerId,
    String? newCustomerName,
    String? customerPhone,
    InvoiceHeaderDiscountKind? headerDiscountKind,
    double? headerDiscountValue,
    double? paidAmount,
    double? paidWalletAmount,
    PaymentMethod? paymentMethod,
    bool? loading,
    String? error,
    int? successInvoiceId,
    String? successEvent,
    int? pendingSaleId,
    int? editingSaleId,
    Map<int, double>? amendmentStockCreditByProduct,
    bool clearError = false,
    bool clearSuccessEvent = false,
    bool clearPendingSaleId = false,
    bool clearEditingSaleId = false,
    bool clearAmendmentStockCredit = false,
  }) {
    return SalesState(
      cart: cart ?? this.cart,
      customerId: customerId ?? this.customerId,
      newCustomerName: newCustomerName ?? this.newCustomerName,
      customerPhone: customerPhone ?? this.customerPhone,
      headerDiscountKind: headerDiscountKind ?? this.headerDiscountKind,
      headerDiscountValue: headerDiscountValue ?? this.headerDiscountValue,
      paidAmount: paidAmount ?? this.paidAmount,
      paidWalletAmount: paidWalletAmount ?? this.paidWalletAmount,
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
      editingSaleId:
          clearEditingSaleId ? null : (editingSaleId ?? this.editingSaleId),
      amendmentStockCreditByProduct: clearEditingSaleId ||
              clearAmendmentStockCredit
          ? const <int, double>{}
          : (amendmentStockCreditByProduct ??
              this.amendmentStockCreditByProduct),
    );
  }

  @override
  List<Object?> get props => [
    cart,
    customerId,
    newCustomerName,
    customerPhone,
    headerDiscountKind,
    headerDiscountValue,
    paidAmount,
    paidWalletAmount,
    paymentMethod,
    loading,
    error,
    successInvoiceId,
    successEvent,
    pendingSaleId,
    editingSaleId,
    amendmentStockCreditByProduct,
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

  /// Clears the cart and exits “amend invoice in cart” mode.
  void clearInvoiceAmendment() {
    emit(const SalesState());
  }

  void setCustomerId(int? accountId) {
    emit(
      state.copyWith(
        customerId: accountId,
        customerPhone: accountId == null ? '' : state.customerPhone,
      ),
    );
  }

  void setNewCustomerName(String value) {
    emit(state.copyWith(newCustomerName: value));
  }

  void setCustomerPhone(String value) {
    emit(state.copyWith(customerPhone: value));
  }

  void setPaidAmount(double value) {
    emit(state.copyWith(paidAmount: roundCurrency(value)));
  }

  void setPaidWalletAmount(double value) {
    emit(state.copyWith(paidWalletAmount: roundCurrency(value)));
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
    if (method == state.paymentMethod) return;

    final (priorCash, priorWallet, priorVisa) = switch (state.paymentMethod) {
      PaymentMethod.cash => (state.paidAmount, 0.0, 0.0),
      PaymentMethod.vodafoneCash => (0.0, state.paidAmount, 0.0),
      PaymentMethod.visa => (0.0, 0.0, state.paidAmount),
      PaymentMethod.cashAndWallet => (
          state.paidAmount,
          state.paidWalletAmount,
          0.0,
        ),
    };

    switch (method) {
      case PaymentMethod.cash:
      case PaymentMethod.vodafoneCash:
      case PaymentMethod.visa:
        emit(
          state.copyWith(
            paymentMethod: method,
            paidAmount: roundCurrency(priorCash + priorWallet + priorVisa),
            paidWalletAmount: 0,
          ),
        );
      case PaymentMethod.cashAndWallet:
        emit(
          state.copyWith(
            paymentMethod: method,
            paidAmount: roundCurrency(priorCash + priorVisa),
            paidWalletAmount: priorWallet,
          ),
        );
    }
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

    if (!isPending && pendingSaleId != null && state.editingSaleId == null) {
      await settlePendingSale(
        saleId: pendingSaleId,
        paidAmount: state.paidAmount,
        paidWalletAmount: state.paidWalletAmount,
        paymentMethod: state.paymentMethod,
        customerPhone: state.customerPhone.trim().isEmpty
            ? null
            : state.customerPhone.trim(),
      );
      return;
    }

    if (state.editingSaleId != null && isPending) {
      emit(
        state.copyWith(
          error: 'sale.amend_complete_only',
        ),
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

      final credit = state.amendmentStockCreditByProduct;
      final isAmending = state.editingSaleId != null;
      final syncedCart = state.cart
          .map(
            (item) {
              final live = liveStockByProduct[item.productId] ?? 0;
              final extra = isAmending
                  ? (credit[item.productId] ?? 0)
                  : 0.0;
              return item.copyWith(
                availableStock: roundQuantity(live + extra),
              );
            },
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

      if (state.editingSaleId != null) {
        final amendmentId = state.editingSaleId!;
        await _repository.amendSale(
          SaleAmendRequest(
            saleId: amendmentId,
            items: syncedCart,
            headerDiscountKind: state.headerDiscountKind,
            headerDiscountValue: state.headerDiscountValue,
          ),
        );
        emit(
          SalesState(
            successInvoiceId: amendmentId,
            paymentMethod: state.paymentMethod,
            successEvent: 'sale_amended',
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
          customerPhone: state.customerPhone.trim().isEmpty
              ? null
              : state.customerPhone.trim(),
          items: syncedCart,
          headerDiscountKind: state.headerDiscountKind,
          headerDiscountValue: state.headerDiscountValue,
          paidAmount: state.paidAmount,
          paidWalletAmount: state.paidWalletAmount,
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
    double paidWalletAmount = 0,
    required PaymentMethod paymentMethod,
    String? customerPhone,
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
        paidWalletAmount: paidWalletAmount,
        paymentMethod: paymentMethod,
        customerPhone: customerPhone,
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
          customerPhone: draft.customerPhone ?? '',
          headerDiscountKind: draft.headerDiscountKind,
          headerDiscountValue: draft.headerDiscountValue,
          paidAmount: 0,
          paidWalletAmount: 0,
          paymentMethod: PaymentMethod.cash,
          successEvent: 'pending_loaded',
          pendingSaleId: draft.saleId,
          editingSaleId: null,
          amendmentStockCreditByProduct: const <int, double>{},
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: _humanizeError(e)));
    }
  }

  Future<void> loadInvoiceForAmendment(int saleId) async {
    emit(
      state.copyWith(
        loading: true,
        clearError: true,
        successInvoiceId: null,
        clearSuccessEvent: true,
        clearPendingSaleId: true,
      ),
    );

    try {
      final draft = await _repository.loadSaleDraftForAmendment(saleId);
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
        SalesState(
          cart: draft.items,
          customerId: draft.customerId,
          newCustomerName: draft.customerId == null
              ? (draft.customerName ?? '')
              : '',
          customerPhone: draft.customerPhone ?? '',
          headerDiscountKind: draft.headerDiscountKind,
          headerDiscountValue: draft.headerDiscountValue,
          paidAmount: paidAmt,
          paidWalletAmount: paidWlt,
          paymentMethod: pay.method,
          successEvent: 'invoice_amendment_loaded',
          editingSaleId: draft.saleId,
          amendmentStockCreditByProduct: draft.amendmentStockCreditByProduct,
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
    if (lower.contains('cannot amend a sale that has returns')) {
      return 'sale.amend_blocked_returns';
    }
    if (lower.contains('this invoice cannot be amended')) {
      return 'sale.amend_blocked_status';
    }
    if (lower.contains('ledger debit entry missing')) {
      return 'sale.amend_blocked_ledger';
    }

    return raw;
  }
}
