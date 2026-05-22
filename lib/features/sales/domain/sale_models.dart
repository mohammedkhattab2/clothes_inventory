import 'package:delta_erp/core/utils/number_utils.dart';

enum PaymentMethod { cash, vodafoneCash, visa, cashAndWallet }

/// Invoice-level discount applied after line totals (subtotal).
enum InvoiceHeaderDiscountKind { percent, fixed }

double computeInvoiceHeaderDiscountAmount({
  required double subtotal,
  required InvoiceHeaderDiscountKind kind,
  required double value,
}) {
  if (subtotal <= 0) return 0;
  switch (kind) {
    case InvoiceHeaderDiscountKind.percent:
      final pct = value.clamp(0, 100);
      return roundCurrency(subtotal * pct / 100);
    case InvoiceHeaderDiscountKind.fixed:
      return roundCurrency(value.clamp(0, subtotal));
  }
}

enum SaleStatus { pending, completed, partial, cancelled }

extension SaleStatusCodec on SaleStatus {
  String get dbValue {
    switch (this) {
      case SaleStatus.pending:
        return 'pending';
      case SaleStatus.completed:
        return 'completed';
      case SaleStatus.partial:
        return 'partial';
      case SaleStatus.cancelled:
        return 'cancelled';
    }
  }
}

SaleStatus saleStatusFromDb(String value) {
  switch (value) {
    case 'pending':
      return SaleStatus.pending;
    case 'partial':
      return SaleStatus.partial;
    case 'cancelled':
      return SaleStatus.cancelled;
    case 'completed':
    default:
      return SaleStatus.completed;
  }
}

class SaleDraftItem {
  const SaleDraftItem({
    required this.productId,
    required this.productName,
    this.barcode,
    required this.unitType,
    required this.availableStock,
    required this.minUnitPrice,
    required this.quantity,
    required this.unitPrice,
    this.discount = 0,
    this.amendSourceSaleItemId,
  });

  final int productId;
  final String productName;
  final String? barcode;
  final String unitType;
  final double availableStock;
  final double minUnitPrice;
  final double quantity;
  final double unitPrice;
  final double discount;

  /// Original [sale_items.id] when loaded for invoice amendment in cart.
  final int? amendSourceSaleItemId;

  double get lineTotal => (quantity * unitPrice) - discount;

  SaleDraftItem copyWith({
    int? productId,
    String? productName,
    String? barcode,
    String? unitType,
    double? availableStock,
    double? minUnitPrice,
    double? quantity,
    double? unitPrice,
    double? discount,
    int? amendSourceSaleItemId,
  }) {
    return SaleDraftItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      barcode: barcode ?? this.barcode,
      unitType: unitType ?? this.unitType,
      availableStock: availableStock ?? this.availableStock,
      minUnitPrice: minUnitPrice ?? this.minUnitPrice,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discount: discount ?? this.discount,
      amendSourceSaleItemId:
          amendSourceSaleItemId ?? this.amendSourceSaleItemId,
    );
  }
}

/// Refund limits when completing an invoice amendment in cart.
class AmendRefundPreview {
  const AmendRefundPreview({
    required this.oldTotalAmount,
    required this.returnAmountTotal,
    required this.newTotalAmount,
    required this.totalDelta,
    required this.netPaidAmount,
    required this.outstandingAfterAmend,
    required this.maxRefundable,
    required this.paymentMethod,
    required this.paidCash,
    required this.paidWallet,
  });

  final double oldTotalAmount;
  final double returnAmountTotal;
  final double newTotalAmount;
  final double totalDelta;
  final double netPaidAmount;
  final double outstandingAfterAmend;
  final double maxRefundable;
  final PaymentMethod paymentMethod;
  final double paidCash;
  final double paidWallet;

  double get positiveDelta => totalDelta > 0 ? totalDelta : 0;
}

/// User-confirmed refund amounts for [SaleAmendRequest].
class AmendRefundConfirmation {
  const AmendRefundConfirmation({
    this.refundAmountOverride,
    this.refundCashOverride,
    this.refundWalletOverride,
  });

  final double? refundAmountOverride;
  final double? refundCashOverride;
  final double? refundWalletOverride;
}

enum PositiveAmendmentHandling { defer, collectNow }

/// User-confirmed handling for positive amendment deltas.
class AmendCollectConfirmation {
  const AmendCollectConfirmation.defer()
    : handling = PositiveAmendmentHandling.defer,
      paymentMethod = null,
      collectAmount = null,
      collectWalletAmount = null;

  const AmendCollectConfirmation.collectNow({
    required this.paymentMethod,
    required this.collectAmount,
    this.collectWalletAmount,
  }) : handling = PositiveAmendmentHandling.collectNow;

  final PositiveAmendmentHandling handling;
  final PaymentMethod? paymentMethod;
  final double? collectAmount;
  final double? collectWalletAmount;
}

class SaleCreateRequest {
  const SaleCreateRequest({
    required this.items,
    this.headerDiscountKind = InvoiceHeaderDiscountKind.percent,
    this.headerDiscountValue = 0,
    required this.paidAmount,
    this.paidWalletAmount = 0,
    required this.paymentMethod,
    this.isPending = false,
    this.pendingSaleId,
    this.customerId,
    this.newCustomerName,
    this.customerPhone,
    this.notes,
  });

  final int? customerId;
  final String? newCustomerName;

  /// Saved to [accounts.phone] when completing a sale (existing or new customer).
  final String? customerPhone;
  final List<SaleDraftItem> items;
  final InvoiceHeaderDiscountKind headerDiscountKind;
  final double headerDiscountValue;
  final double paidAmount;

  /// Used when [paymentMethod] is [PaymentMethod.cashAndWallet]; stored as
  /// a separate `vodafone_cash` payment row (wallet portion).
  final double paidWalletAmount;
  final PaymentMethod paymentMethod;
  final bool isPending;
  final int? pendingSaleId;
  final String? notes;
}

/// Replace line items/totals of an existing completed/partial sale; records
/// quantity reductions as returns and optional refunds when overpaid.
class SaleAmendRequest {
  const SaleAmendRequest({
    required this.saleId,
    required this.items,
    this.headerDiscountKind = InvoiceHeaderDiscountKind.percent,
    this.headerDiscountValue = 0,
    required this.paymentMethod,
    this.refundAmountOverride,
    this.refundCashOverride,
    this.refundWalletOverride,
    this.positiveAmendmentHandling,
    this.collectPaymentMethod,
    this.collectAmount,
    this.collectWalletAmount,
  });

  final int saleId;
  final List<SaleDraftItem> items;
  final InvoiceHeaderDiscountKind headerDiscountKind;
  final double headerDiscountValue;
  final PaymentMethod paymentMethod;
  final double? refundAmountOverride;
  final double? refundCashOverride;
  final double? refundWalletOverride;
  final PositiveAmendmentHandling? positiveAmendmentHandling;
  final PaymentMethod? collectPaymentMethod;
  final double? collectAmount;
  final double? collectWalletAmount;
}
