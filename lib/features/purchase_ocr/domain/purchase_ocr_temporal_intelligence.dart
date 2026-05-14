import 'dart:math' as math;

import 'package:clothes_inventory/features/purchase_ocr/domain/purchase_ocr_models.dart';

class SupplierStatsSnapshot {
  const SupplierStatsSnapshot({
    required this.supplierId,
    required this.invoiceCount,
    required this.avgItemCount,
    required this.priceStabilityScore,
    required this.lastInvoiceAt,
  });

  final int supplierId;
  final int invoiceCount;
  final double avgItemCount;
  final double priceStabilityScore;
  final DateTime lastInvoiceAt;
}

class ProductPricePoint {
  const ProductPricePoint({
    required this.productId,
    required this.unitPrice,
    required this.observedAt,
    this.supplierId,
  });

  final int productId;
  final int? supplierId;
  final double unitPrice;
  final DateTime observedAt;
}

class UserCorrectionPattern {
  const UserCorrectionPattern({
    required this.ocrText,
    required this.suggestedProductId,
    required this.selectedProductId,
    required this.correctionCount,
    required this.lastCorrectedAt,
  });

  final String ocrText;
  final int? suggestedProductId;
  final int selectedProductId;
  final int correctionCount;
  final DateTime lastCorrectedAt;
}

abstract class PurchaseOcrTemporalMemoryStore {
  Future<SupplierStatsSnapshot?> getSupplierStats(int supplierId);

  Future<void> upsertSupplierStats(SupplierStatsSnapshot stats);

  Future<List<ProductPricePoint>> listProductPriceHistory(int productId, {int limit});

  Future<void> appendProductPricePoint(ProductPricePoint point);

  Future<List<UserCorrectionPattern>> listUserCorrectionPatterns(String normalizedOcrText);

  Future<void> incrementUserCorrectionPattern({
    required String normalizedOcrText,
    int? suggestedProductId,
    required int selectedProductId,
  });
}

class PurchaseOcrTemporalInsight {
  const PurchaseOcrTemporalInsight({required this.key, required this.message});

  final String key;
  final String message;
}

class PurchaseOcrTrendAnomaly {
  const PurchaseOcrTrendAnomaly({
    required this.severity,
    required this.message,
  });

  final OcrAnomalySeverity severity;
  final String message;
}

class PurchaseOcrBehavioralSignal {
  const PurchaseOcrBehavioralSignal({
    required this.signal,
    required this.message,
    required this.strength,
  });

  final String signal;
  final String message;
  final double strength;
}

class PurchaseOcrTemporalOutput {
  const PurchaseOcrTemporalOutput({
    required this.items,
    required this.temporalInsights,
    required this.trendAnomalies,
    required this.behavioralSignals,
    required this.riskContribution,
  });

  final List<PurchaseOcrLineItemDraft> items;
  final List<PurchaseOcrTemporalInsight> temporalInsights;
  final List<PurchaseOcrTrendAnomaly> trendAnomalies;
  final List<PurchaseOcrBehavioralSignal> behavioralSignals;
  final double riskContribution;
}

class PurchaseOcrTemporalIntelligenceLayer {
  const PurchaseOcrTemporalIntelligenceLayer({
    required PurchaseOcrTemporalMemoryStore memoryStore,
  }) : _memoryStore = memoryStore;

  final PurchaseOcrTemporalMemoryStore _memoryStore;

  Future<PurchaseOcrTemporalOutput> analyze({
    required PurchaseOcrDraft draft,
    required String Function(String) normalizeText,
  }) async {
    final insights = <PurchaseOcrTemporalInsight>[];
    final trendAnomalies = <PurchaseOcrTrendAnomaly>[];
    final behavioral = <PurchaseOcrBehavioralSignal>[];
    final updatedItems = <PurchaseOcrLineItemDraft>[];

    var risk = 0.0;

    if (draft.supplierId != null) {
      final stats = await _memoryStore.getSupplierStats(draft.supplierId!);
      if (stats != null) {
        insights.add(
          PurchaseOcrTemporalInsight(
            key: 'supplier_stability',
            message:
                'Supplier stability score: ${stats.priceStabilityScore.toStringAsFixed(2)} across ${stats.invoiceCount} invoices.',
          ),
        );
        if (stats.priceStabilityScore < 0.45) {
          trendAnomalies.add(
            const PurchaseOcrTrendAnomaly(
              severity: OcrAnomalySeverity.medium,
              message: 'Supplier shows unstable pricing behavior over time.',
            ),
          );
          risk += 0.15;
        }
      }
    }

    for (final item in draft.items) {
      var next = item;
      final matchedId = item.matchedProductId;

      if (matchedId != null) {
        final history = await _memoryStore.listProductPriceHistory(matchedId, limit: 12);
        if (history.length >= 3 && item.unitPrice > 0) {
          final average = history
                  .map((h) => h.unitPrice)
                  .reduce((a, b) => a + b) /
              history.length;
          final first = history.last.unitPrice;
          final last = history.first.unitPrice;
          final drift = first <= 0 ? 0.0 : (last - first) / first;
          final deviation = average <= 0 ? 0.0 : (item.unitPrice - average).abs() / average;

          if (drift > 0.2 && deviation > 0.25) {
            trendAnomalies.add(
              PurchaseOcrTrendAnomaly(
                severity: OcrAnomalySeverity.high,
                message:
                    'Price trend anomaly for "${item.productName}": detected upward drift with current deviation ${((deviation) * 100).toStringAsFixed(0)}%.',
              ),
            );
            risk += 0.2;
          }
        }
      }

      final normalized = normalizeText(item.productName);
      if (normalized.isNotEmpty) {
        final patterns = await _memoryStore.listUserCorrectionPatterns(normalized);
        if (patterns.isNotEmpty) {
          final top = patterns.first;
          if (top.correctionCount >= 3 && top.selectedProductId != item.matchedProductId) {
            final boosted = [...item.suggestedProducts];
            final existingIndex = boosted.indexWhere(
              (s) => s.productId == top.selectedProductId,
            );
            if (existingIndex >= 0) {
              final p = boosted.removeAt(existingIndex);
              boosted.insert(
                0,
                OcrProductSuggestion(
                  productId: p.productId,
                  productName: p.productName,
                  matchScore: math.max(0.98, p.matchScore),
                ),
              );
            }

            next = next.copyWith(
              matchedProductId: top.selectedProductId,
              suggestedProducts: boosted,
            );

            behavioral.add(
              PurchaseOcrBehavioralSignal(
                signal: 'user_correction_preference',
                message:
                    'Applied frequent correction preference for "${item.productName}".',
                strength: (top.correctionCount / 10).clamp(0, 1).toDouble(),
              ),
            );
            risk += 0.08;
          }
        }
      }

      updatedItems.add(next);
    }

    return PurchaseOcrTemporalOutput(
      items: updatedItems,
      temporalInsights: insights,
      trendAnomalies: trendAnomalies,
      behavioralSignals: behavioral,
      riskContribution: risk.clamp(0, 0.45).toDouble(),
    );
  }

  Future<void> recordAcceptedInvoice({
    required PurchaseOcrDraft draft,
  }) async {
    final now = DateTime.now();

    if (draft.supplierId != null) {
      final current = await _memoryStore.getSupplierStats(draft.supplierId!);
      final nextCount = (current?.invoiceCount ?? 0) + 1;
      final currentAvgItems = current?.avgItemCount ?? 0;
      final observedItems = draft.items.length.toDouble();
      final nextAvgItems = ((currentAvgItems * (nextCount - 1)) + observedItems) / nextCount;

      final priceRatios = <double>[];
      for (final item in draft.items) {
        if (item.matchedProductId == null || item.unitPrice <= 0) continue;
        final history = await _memoryStore.listProductPriceHistory(item.matchedProductId!, limit: 5);
        if (history.isEmpty) continue;
        final avg = history
                .map((e) => e.unitPrice)
                .reduce((a, b) => a + b) /
            history.length;
        if (avg > 0) {
          priceRatios.add((item.unitPrice - avg).abs() / avg);
        }
      }

      final meanDeviation = priceRatios.isEmpty
          ? 0.0
          : priceRatios.reduce((a, b) => a + b) / priceRatios.length;
      final observedStability = (1 - meanDeviation).clamp(0, 1).toDouble();
      final prevStability = current?.priceStabilityScore ?? 1.0;
      final nextStability = ((prevStability * 0.7) + (observedStability * 0.3))
          .clamp(0, 1)
          .toDouble();

      await _memoryStore.upsertSupplierStats(
        SupplierStatsSnapshot(
          supplierId: draft.supplierId!,
          invoiceCount: nextCount,
          avgItemCount: nextAvgItems,
          priceStabilityScore: nextStability,
          lastInvoiceAt: now,
        ),
      );
    }

    for (final item in draft.items) {
      final productId = item.matchedProductId;
      if (productId == null || item.unitPrice <= 0) continue;
      await _memoryStore.appendProductPricePoint(
        ProductPricePoint(
          productId: productId,
          supplierId: draft.supplierId,
          unitPrice: item.unitPrice,
          observedAt: now,
        ),
      );
    }
  }

  Future<void> recordUserCorrection({
    required String normalizedOcrText,
    int? suggestedProductId,
    required int selectedProductId,
  }) {
    if (normalizedOcrText.trim().isEmpty) {
      return Future.value();
    }
    return _memoryStore.incrementUserCorrectionPattern(
      normalizedOcrText: normalizedOcrText,
      suggestedProductId: suggestedProductId,
      selectedProductId: selectedProductId,
    );
  }
}
