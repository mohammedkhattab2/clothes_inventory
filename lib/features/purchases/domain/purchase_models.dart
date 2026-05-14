import 'package:clothes_inventory/features/sales/domain/sale_models.dart';

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
    this.taxPercentage = 0,
    required this.paidAmount,
    required this.paymentMethod,
    this.notes,
    this.createdAt,
  });

  final int supplierId;
  final List<PurchaseDraftItem> items;
  final double taxPercentage;
  final double paidAmount;
  final PaymentMethod paymentMethod;
  final String? notes;
  final DateTime? createdAt;
}
