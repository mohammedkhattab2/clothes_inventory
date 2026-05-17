import 'package:delta_erp/features/purchase_ocr/domain/purchase_ocr_product_matcher.dart';
import 'package:delta_erp/services/database/app_database.dart';

class OcrProductMappingsRepository implements OcrProductMappingsStore {
  OcrProductMappingsRepository(this._appDatabase);

  static const double weightUsage = 0.03;
  static const double weightRecency = 1.0;

  final AppDatabase _appDatabase;

  @override
  Future<LearnedProductMapping?> findPreferredMapping(
    String normalizedOcrText,
  ) async {
    if (normalizedOcrText.trim().isEmpty) {
      return null;
    }

    final db = await _appDatabase.database;
    final rows = await db.query(
      'ocr_product_mappings',
      where: 'ocr_text = ?',
      whereArgs: [normalizedOcrText],
    );

    if (rows.isEmpty) {
      return null;
    }

    final now = DateTime.now();
    final mappings = rows
        .map(
          (row) => LearnedProductMapping(
            id: row['id'] as int,
            ocrText: (row['ocr_text'] as String?) ?? '',
            productId: row['product_id'] as int,
            usageCount: (row['usage_count'] as int?) ?? 1,
            lastUsedAt:
                DateTime.tryParse((row['last_used_at'] as String?) ?? '') ??
                now,
          ),
        )
        .toList(growable: false);

    mappings.sort((a, b) {
      final scoreCompare = _weightedScore(b, now).compareTo(
        _weightedScore(a, now),
      );
      if (scoreCompare != 0) return scoreCompare;

      final usageCompare = b.usageCount.compareTo(a.usageCount);
      if (usageCompare != 0) return usageCompare;

      final recencyCompare = b.lastUsedAt.compareTo(a.lastUsedAt);
      if (recencyCompare != 0) return recencyCompare;

      return b.id.compareTo(a.id);
    });

    return mappings.first;
  }

  @override
  Future<void> saveOrIncrementMapping({
    required String normalizedOcrText,
    required int productId,
  }) async {
    final text = normalizedOcrText.trim();
    if (text.isEmpty) {
      return;
    }

    final db = await _appDatabase.database;
    await db.rawInsert(
      '''
      INSERT INTO ocr_product_mappings (ocr_text, product_id, usage_count, last_used_at)
      VALUES (?, ?, 1, CURRENT_TIMESTAMP)
      ON CONFLICT(ocr_text, product_id)
      DO UPDATE SET
        usage_count = usage_count + 1,
        last_used_at = CURRENT_TIMESTAMP
      ''',
      [text, productId],
    );
  }

  double _weightedScore(LearnedProductMapping mapping, DateTime now) {
    final recency = _recencyScore(mapping.lastUsedAt, now);
    return (mapping.usageCount * weightUsage) + (recency * weightRecency);
  }

  double _recencyScore(DateTime lastUsedAt, DateTime now) {
    final days = now.difference(lastUsedAt).inDays;
    if (days <= 0) return 1.0;
    if (days <= 7) return 0.7;
    if (days <= 30) return 0.4;
    return 0.1;
  }
}
