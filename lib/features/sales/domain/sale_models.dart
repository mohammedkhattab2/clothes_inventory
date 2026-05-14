enum PaymentMethod { cash, vodafoneCash }

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
    required this.unitType,
    required this.availableStock,
    required this.minUnitPrice,
    required this.quantity,
    required this.unitPrice,
    this.discount = 0,
  });

  final int productId;
  final String productName;
  final String unitType;
  final double availableStock;
  final double minUnitPrice;
  final double quantity;
  final double unitPrice;
  final double discount;

  double get lineTotal => (quantity * unitPrice) - discount;

  SaleDraftItem copyWith({
    int? productId,
    String? productName,
    String? unitType,
    double? availableStock,
    double? minUnitPrice,
    double? quantity,
    double? unitPrice,
    double? discount,
  }) {
    return SaleDraftItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      unitType: unitType ?? this.unitType,
      availableStock: availableStock ?? this.availableStock,
      minUnitPrice: minUnitPrice ?? this.minUnitPrice,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discount: discount ?? this.discount,
    );
  }
}

class SaleCreateRequest {
  const SaleCreateRequest({
    required this.items,
    required this.taxPercentage,
    required this.paidAmount,
    required this.paymentMethod,
    this.isPending = false,
    this.pendingSaleId,
    this.customerId,
    this.newCustomerName,
    this.notes,
  });

  final int? customerId;
  final String? newCustomerName;
  final List<SaleDraftItem> items;
  final double taxPercentage;
  final double paidAmount;
  final PaymentMethod paymentMethod;
  final bool isPending;
  final int? pendingSaleId;
  final String? notes;
}
