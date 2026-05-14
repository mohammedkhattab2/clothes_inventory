enum UnitType { piece, weight }

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.unitType,
    required this.salePrice,
    this.salePriceHalfWholesale = 0,
    this.salePriceWholesale = 0,
    required this.purchasePrice,
    required this.lowStockThreshold,
    this.currentStock = 0,
    this.barcode,
    this.categoryId,
  });

  final int? id;
  final String name;
  final String? barcode;
  final int? categoryId;
  final UnitType unitType;
  // `salePrice` is retail (تجزئة) to keep backward compatibility.
  final double salePrice;
  final double salePriceHalfWholesale;
  final double salePriceWholesale;
  final double purchasePrice;
  final double lowStockThreshold;
  final double currentStock;

  Product copyWith({
    int? id,
    String? name,
    String? barcode,
    int? categoryId,
    UnitType? unitType,
    double? salePrice,
    double? salePriceHalfWholesale,
    double? salePriceWholesale,
    double? purchasePrice,
    double? lowStockThreshold,
    double? currentStock,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      categoryId: categoryId ?? this.categoryId,
      unitType: unitType ?? this.unitType,
      salePrice: salePrice ?? this.salePrice,
      salePriceHalfWholesale:
          salePriceHalfWholesale ?? this.salePriceHalfWholesale,
      salePriceWholesale: salePriceWholesale ?? this.salePriceWholesale,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      currentStock: currentStock ?? this.currentStock,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'category_id': categoryId,
      'unit_type': unitType.name,
      'sale_price': salePrice,
      'sale_price_half_wholesale': salePriceHalfWholesale,
      'sale_price_wholesale': salePriceWholesale,
      'purchase_price': purchasePrice,
      'low_stock_threshold': lowStockThreshold,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, Object?> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      barcode: map['barcode'] as String?,
      categoryId: map['category_id'] as int?,
      unitType: UnitType.values.firstWhere(
        (value) => value.name == map['unit_type'],
      ),
      salePrice: (map['sale_price'] as num).toDouble(),
      salePriceHalfWholesale:
          ((map['sale_price_half_wholesale'] ?? map['sale_price']) as num)
              .toDouble(),
      salePriceWholesale:
          ((map['sale_price_wholesale'] ?? map['sale_price']) as num)
              .toDouble(),
      purchasePrice: (map['purchase_price'] as num).toDouble(),
      lowStockThreshold: (map['low_stock_threshold'] as num).toDouble(),
      currentStock: (((map['current_stock'] ?? 0) as num).toDouble()).clamp(
        0,
        double.infinity,
      ),
    );
  }
}
