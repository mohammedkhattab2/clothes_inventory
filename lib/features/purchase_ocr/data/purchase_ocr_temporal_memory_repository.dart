import 'package:clothes_inventory/features/purchase_ocr/domain/purchase_ocr_temporal_intelligence.dart';
import 'package:clothes_inventory/services/database/app_database.dart';

class PurchaseOcrTemporalMemoryRepository
    implements PurchaseOcrTemporalMemoryStore {
  const PurchaseOcrTemporalMemoryRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<SupplierStatsSnapshot?> getSupplierStats(int supplierId) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      'supplier_stats',
      where: 'supplier_id = ?',
      whereArgs: [supplierId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return SupplierStatsSnapshot(
      supplierId: row['supplier_id'] as int,
      invoiceCount: ((row['invoice_count'] ?? 0) as num).toInt(),
      avgItemCount: ((row['avg_item_count'] ?? 0) as num).toDouble(),
      priceStabilityScore: ((row['price_stability_score'] ?? 1) as num).toDouble(),
      lastInvoiceAt:
          DateTime.tryParse((row['last_invoice_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }

  @override
  Future<void> upsertSupplierStats(SupplierStatsSnapshot stats) async {
    final db = await _appDatabase.database;
    await db.rawInsert(
      '''
      INSERT INTO supplier_stats (
        supplier_id,
        invoice_count,
        avg_item_count,
        price_stability_score,
        last_invoice_at,
        updated_at
      ) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
      ON CONFLICT(supplier_id)
      DO UPDATE SET
        invoice_count = excluded.invoice_count,
        avg_item_count = excluded.avg_item_count,
        price_stability_score = excluded.price_stability_score,
        last_invoice_at = excluded.last_invoice_at,
        updated_at = CURRENT_TIMESTAMP
      ''',
      [
        stats.supplierId,
        stats.invoiceCount,
        stats.avgItemCount,
        stats.priceStabilityScore,
        stats.lastInvoiceAt.toIso8601String(),
      ],
    );
  }

  @override
  Future<List<ProductPricePoint>> listProductPriceHistory(
    int productId, {
    int limit = 20,
  }) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      'product_price_history',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'datetime(observed_at) DESC, id DESC',
      limit: limit,
    );

    return rows
        .map(
          (row) => ProductPricePoint(
            productId: row['product_id'] as int,
            supplierId: row['supplier_id'] as int?,
            unitPrice: ((row['unit_price'] ?? 0) as num).toDouble(),
            observedAt:
                DateTime.tryParse((row['observed_at'] as String?) ?? '') ??
                DateTime.now(),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> appendProductPricePoint(ProductPricePoint point) async {
    final db = await _appDatabase.database;
    await db.insert('product_price_history', {
      'product_id': point.productId,
      'supplier_id': point.supplierId,
      'unit_price': point.unitPrice,
      'observed_at': point.observedAt.toIso8601String(),
    });
  }

  @override
  Future<List<UserCorrectionPattern>> listUserCorrectionPatterns(
    String normalizedOcrText,
  ) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      'user_correction_patterns',
      where: 'ocr_text = ?',
      whereArgs: [normalizedOcrText],
      orderBy: 'correction_count DESC, datetime(last_corrected_at) DESC, id DESC',
      limit: 10,
    );

    return rows
        .map(
          (row) => UserCorrectionPattern(
            ocrText: (row['ocr_text'] as String?) ?? '',
            suggestedProductId: row['suggested_product_id'] as int?,
            selectedProductId: row['selected_product_id'] as int,
            correctionCount: ((row['correction_count'] ?? 0) as num).toInt(),
            lastCorrectedAt:
                DateTime.tryParse((row['last_corrected_at'] as String?) ?? '') ??
                DateTime.now(),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> incrementUserCorrectionPattern({
    required String normalizedOcrText,
    int? suggestedProductId,
    required int selectedProductId,
  }) async {
    final db = await _appDatabase.database;
    await db.rawInsert(
      '''
      INSERT INTO user_correction_patterns (
        ocr_text,
        suggested_product_id,
        selected_product_id,
        correction_count,
        last_corrected_at
      ) VALUES (?, ?, ?, 1, CURRENT_TIMESTAMP)
      ON CONFLICT(ocr_text, suggested_product_id, selected_product_id)
      DO UPDATE SET
        correction_count = correction_count + 1,
        last_corrected_at = CURRENT_TIMESTAMP
      ''',
      [normalizedOcrText, suggestedProductId, selectedProductId],
    );
  }
}
