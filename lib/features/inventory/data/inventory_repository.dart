import 'package:delta_erp/services/database/app_database.dart';

class InventoryStockRow {
  const InventoryStockRow({
    required this.productId,
    required this.productName,
    this.barcode,
    required this.unitType,
    required this.currentStock,
    required this.lowThreshold,
  });

  final int productId;
  final String productName;
  final String? barcode;
  final String unitType;
  final double currentStock;
  final double lowThreshold;

  bool get isLow => currentStock <= lowThreshold;
}

class InventoryRepository {
  const InventoryRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<List<InventoryStockRow>> getCurrentStockRows() async {
    final db = await _appDatabase.database;
    final rows = await db.rawQuery('''
      SELECT
        p.id AS product_id,
        p.name AS product_name,
        p.barcode AS barcode,
        p.unit_type AS unit_type,
        p.low_stock_threshold AS low_stock_threshold,
        MAX(
          0,
          COALESCE(SUM(CASE WHEN sm.movement_type = 'in' THEN sm.quantity ELSE 0 END), 0) -
          COALESCE(SUM(CASE WHEN sm.movement_type = 'out' THEN sm.quantity ELSE 0 END), 0)
        ) AS current_stock
      FROM products p
      LEFT JOIN stock_movements sm ON sm.product_id = p.id
      GROUP BY p.id, p.name, p.barcode, p.unit_type, p.low_stock_threshold
      ORDER BY p.name ASC
    ''');

    return rows
        .map(
          (row) => InventoryStockRow(
            productId: row['product_id'] as int,
            productName: row['product_name'] as String,
            barcode: (row['barcode'] as String?)?.trim(),
            unitType: row['unit_type'] as String,
            currentStock: (((row['current_stock'] ?? 0) as num).toDouble())
                .clamp(0, double.infinity),
            lowThreshold: ((row['low_stock_threshold'] ?? 0) as num).toDouble(),
          ),
        )
        .toList();
  }
}
