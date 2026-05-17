import 'package:delta_erp/features/sales/domain/sale_models.dart';

export 'package:delta_erp/features/sales/domain/sale_models.dart'
    show InvoiceHeaderDiscountKind, PaymentMethod;

class PurchaseDraftItem {
  const PurchaseDraftItem({
    required this.productId,
    required this.productName,
    required this.unitType,
    required this.quantity,
    required this.unitPrice,
    this.discount = 0,
  });

  final int productId;
  final String productName;
  final String unitType;
  final double quantity;
  final double unitPrice;
  final double discount;

  double get lineTotal => (quantity * unitPrice) - discount;

  PurchaseDraftItem copyWith({
    int? productId,
    String? productName,
    String? unitType,
    double? quantity,
    double? unitPrice,
    double? discount,
  }) {
    return PurchaseDraftItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      unitType: unitType ?? this.unitType,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discount: discount ?? this.discount,
    );
  }
}

class PurchaseCreateRequest {
  const PurchaseCreateRequest({
    required this.supplierId,
    required this.items,
    this.headerDiscountKind = InvoiceHeaderDiscountKind.percent,
    this.headerDiscountValue = 0,
    required this.paidAmount,
    required this.paymentMethod,
    this.notes,
    this.createdAt,
  });

  final int supplierId;
  final List<PurchaseDraftItem> items;
  final InvoiceHeaderDiscountKind headerDiscountKind;
  final double headerDiscountValue;
  final double paidAmount;
  final PaymentMethod paymentMethod;
  final String? notes;
  final DateTime? createdAt;
}

/// Net payments already stored on the purchase (unchanged during amend).
class PurchaseAmendmentPaymentSnapshot {
  const PurchaseAmendmentPaymentSnapshot({
    required this.paidCash,
    required this.paidWallet,
    required this.method,
  });

  final double paidCash;
  final double paidWallet;
  final PaymentMethod method;
}

/// Draft loaded when editing an existing purchase invoice in the cart.
class PendingPurchaseDraft {
  const PendingPurchaseDraft({
    required this.purchaseId,
    required this.supplierId,
    required this.headerDiscountKind,
    required this.headerDiscountValue,
    required this.items,
    this.amendmentPayments,
    this.amendmentStockCreditByProduct = const <int, double>{},
  });

  final int purchaseId;
  final int supplierId;
  final InvoiceHeaderDiscountKind headerDiscountKind;
  final double headerDiscountValue;
  final List<PurchaseDraftItem> items;

  /// When set, cart was loaded for editing an existing invoice.
  final PurchaseAmendmentPaymentSnapshot? amendmentPayments;

  /// Per-product quantities on the invoice at load time; used in the cubit to
  /// validate reducing purchase quantities against live stock while original
  /// `in` movements still exist in the DB.
  final Map<int, double> amendmentStockCreditByProduct;
}

/// Replace line items/totals of an existing completed/partial purchase (no returns).
/// Supplier and existing payment rows are unchanged.
class PurchaseAmendRequest {
  const PurchaseAmendRequest({
    required this.purchaseId,
    required this.items,
    this.headerDiscountKind = InvoiceHeaderDiscountKind.percent,
    this.headerDiscountValue = 0,
  });

  final int purchaseId;
  final List<PurchaseDraftItem> items;
  final InvoiceHeaderDiscountKind headerDiscountKind;
  final double headerDiscountValue;
}
