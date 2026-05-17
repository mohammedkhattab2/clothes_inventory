import 'package:delta_erp/features/purchase_ocr/domain/purchase_invoice_parser.dart';
import 'package:delta_erp/features/purchase_ocr/domain/purchase_ocr_anomaly_detector.dart';
import 'package:delta_erp/features/purchase_ocr/domain/purchase_ocr_models.dart';
import 'package:delta_erp/features/purchase_ocr/domain/purchase_ocr_product_matcher.dart';
import 'package:delta_erp/features/purchase_ocr/domain/purchase_ocr_temporal_intelligence.dart';
import 'package:delta_erp/features/products/domain/product.dart';

class PurchaseOcrConfidenceScores {
  const PurchaseOcrConfidenceScores({
    required this.supplier,
    required this.total,
    required this.averageItems,
    required this.lowConfidenceItemsCount,
  });

  final OcrConfidence? supplier;
  final OcrConfidence? total;
  final double averageItems;
  final int lowConfidenceItemsCount;
}

class PurchaseOcrIntelligenceResult {
  const PurchaseOcrIntelligenceResult({
    required this.parsedInvoice,
    required this.matchedItems,
    required this.learnedMappingsApplied,
    required this.anomalies,
    required this.confidenceScores,
    required this.temporalInsights,
    required this.trendAnomalies,
    required this.behavioralSignals,
    required this.actionableRecommendations,
    required this.riskScore,
  });

  final PurchaseOcrDraft parsedInvoice;
  final List<PurchaseOcrLineItemDraft> matchedItems;
  final List<int> learnedMappingsApplied;
  final List<PurchaseOcrAnomaly> anomalies;
  final PurchaseOcrConfidenceScores confidenceScores;
  final List<PurchaseOcrTemporalInsight> temporalInsights;
  final List<PurchaseOcrTrendAnomaly> trendAnomalies;
  final List<PurchaseOcrBehavioralSignal> behavioralSignals;
  final List<PurchaseOcrActionableRecommendation> actionableRecommendations;
  final double riskScore;
}

class PurchaseOcrIntelligenceEngine {
  const PurchaseOcrIntelligenceEngine({
    required PurchaseInvoiceParser parser,
    required PurchaseOcrProductMatcher matcher,
    required PurchaseOcrAnomalyDetector anomalyDetector,
    PurchaseOcrTemporalIntelligenceLayer? temporalLayer,
  }) : _parser = parser,
       _matcher = matcher,
       _anomalyDetector = anomalyDetector,
       _temporalLayer = temporalLayer;

  final PurchaseInvoiceParser _parser;
  final PurchaseOcrProductMatcher _matcher;
  final PurchaseOcrAnomalyDetector _anomalyDetector;
  final PurchaseOcrTemporalIntelligenceLayer? _temporalLayer;

  Future<PurchaseOcrIntelligenceResult> analyze({
    required String rawText,
    required String imagePath,
    required List<Product> products,
    required int? Function(String? supplierName) resolveSupplierId,
  }) async {
    final parsed = _parser.parse(rawText: rawText, imagePath: imagePath);

    final matchedItems = <PurchaseOcrLineItemDraft>[];
    final learnedAppliedIndexes = <int>[];

    for (var i = 0; i < parsed.items.length; i++) {
      final item = parsed.items[i];
      final matchResult = await _matcher.matchWithLearning(item.productName, products);

      final suggestions = matchResult.suggestions
          .where((candidate) => candidate.product.id != null)
          .map(
            (candidate) => OcrProductSuggestion(
              productId: candidate.product.id!,
              productName: candidate.product.name,
              matchScore: candidate.score,
            ),
          )
          .toList(growable: false);

      if (matchResult.usedLearnedMapping) {
        learnedAppliedIndexes.add(i);
      }

      matchedItems.add(
        item.copyWith(
          matchedProductId: matchResult.autoMatchedProductId,
          suggestedProducts: suggestions,
        ),
      );
    }

    final hydrated = parsed.copyWith(
      supplierId: resolveSupplierId(parsed.supplierName),
      items: matchedItems,
    );

    var temporalInsights = const <PurchaseOcrTemporalInsight>[];
    var trendAnomalies = const <PurchaseOcrTrendAnomaly>[];
    var behavioralSignals = const <PurchaseOcrBehavioralSignal>[];
    var temporalRisk = 0.0;

    var temporalAdjusted = hydrated;
    final layer = _temporalLayer;
    if (layer != null) {
      try {
        final temporalOutput = await layer.analyze(
          draft: hydrated,
          normalizeText: _matcher.normalizeName,
        );
        temporalAdjusted = hydrated.copyWith(items: temporalOutput.items);
        temporalInsights = temporalOutput.temporalInsights;
        trendAnomalies = temporalOutput.trendAnomalies;
        behavioralSignals = temporalOutput.behavioralSignals;
        temporalRisk = temporalOutput.riskContribution;
      } catch (_) {
        // Non-blocking optional layer: ignore temporal failures.
      }
    }

    final anomalies = await _anomalyDetector.detect(temporalAdjusted);
    final reviewed = temporalAdjusted.copyWith(anomalies: anomalies);
    final confidence = _buildConfidenceScores(reviewed);
    final risk = _computeRiskScore(reviewed, confidence, temporalRisk);
    final recommendations = _buildActionableRecommendations(
      draft: reviewed,
      trendAnomalies: trendAnomalies,
      behavioralSignals: behavioralSignals,
      riskScore: risk,
      learnedMappingsAppliedCount: learnedAppliedIndexes.length,
    );

    return PurchaseOcrIntelligenceResult(
      parsedInvoice: reviewed,
      matchedItems: matchedItems,
      learnedMappingsApplied: learnedAppliedIndexes,
      anomalies: anomalies,
      confidenceScores: confidence,
      temporalInsights: temporalInsights,
      trendAnomalies: trendAnomalies,
      behavioralSignals: behavioralSignals,
      actionableRecommendations: recommendations,
      riskScore: risk,
    );
  }

  List<PurchaseOcrActionableRecommendation> _buildActionableRecommendations({
    required PurchaseOcrDraft draft,
    required List<PurchaseOcrTrendAnomaly> trendAnomalies,
    required List<PurchaseOcrBehavioralSignal> behavioralSignals,
    required double riskScore,
    required int learnedMappingsAppliedCount,
  }) {
    final recommendations = <PurchaseOcrActionableRecommendation>[];

    final hasSupplierRisk =
        draft.anomalies.any((a) => a.type == OcrAnomalyType.supplier) ||
        trendAnomalies.any((a) => a.message.toLowerCase().contains('supplier'));
    if (hasSupplierRisk) {
      recommendations.add(
        const PurchaseOcrActionableRecommendation(
          type: PurchaseOcrRecommendationType.supplier,
          severity: OcrAnomalySeverity.medium,
          message: 'Supplier behavior looks unstable compared to past invoices.',
          suggestedAction:
              'Review this supplier invoice history and consider comparing with alternative suppliers.',
        ),
      );
    }

    final hasPriceRisk =
        draft.anomalies.any((a) => a.type == OcrAnomalyType.price) ||
        trendAnomalies.any((a) {
          final text = a.message.toLowerCase();
          return text.contains('price') || text.contains('drift');
        });
    if (hasPriceRisk) {
      recommendations.add(
        const PurchaseOcrActionableRecommendation(
          type: PurchaseOcrRecommendationType.product,
          severity: OcrAnomalySeverity.high,
          message: 'Unusual product pricing detected in this invoice.',
          suggestedAction:
              'Check recent invoices for this product and verify whether the price change is intentional.',
        ),
      );
    }

    final correctionSignals = behavioralSignals.where(
      (s) => s.signal == 'user_correction_preference',
    );
    final hasSystemOptimizationNeed = correctionSignals.isNotEmpty ||
        learnedMappingsAppliedCount > 0 ||
        riskScore >= 0.7;
    if (hasSystemOptimizationNeed) {
      recommendations.add(
        const PurchaseOcrActionableRecommendation(
          type: PurchaseOcrRecommendationType.system,
          severity: OcrAnomalySeverity.low,
          message: 'The system observed repeated manual adjustments.',
          suggestedAction:
              'Improve automation using barcode linking, better aliases, or faster autofill shortcuts.',
        ),
      );
    }

    return recommendations;
  }

  PurchaseOcrConfidenceScores _buildConfidenceScores(PurchaseOcrDraft draft) {
    final itemValues = draft.items
        .map((e) => _confidenceValue(e.confidence))
        .toList(growable: false);

    final averageItems = itemValues.isEmpty
        ? 0.0
        : itemValues.reduce((a, b) => a + b) / itemValues.length;

    final lowCount = draft.items
        .where((item) => item.confidence == OcrConfidence.low)
        .length;

    return PurchaseOcrConfidenceScores(
      supplier: draft.supplierConfidence,
      total: draft.totalAmountConfidence,
      averageItems: averageItems,
      lowConfidenceItemsCount: lowCount,
    );
  }

  double _computeRiskScore(
    PurchaseOcrDraft draft,
    PurchaseOcrConfidenceScores confidence,
    double temporalRisk,
  ) {
    var risk = 0.0;

    for (final anomaly in draft.anomalies) {
      switch (anomaly.severity) {
        case OcrAnomalySeverity.low:
          risk += 0.08;
          break;
        case OcrAnomalySeverity.medium:
          risk += 0.18;
          break;
        case OcrAnomalySeverity.high:
          risk += 0.32;
          break;
      }
    }

    risk += (1 - confidence.averageItems).clamp(0, 1) * 0.25;

    if (confidence.supplier != null) {
      risk += (1 - _confidenceValue(confidence.supplier!)) * 0.1;
    }
    if (confidence.total != null) {
      risk += (1 - _confidenceValue(confidence.total!)) * 0.12;
    }

    final uncertainMatches = draft.items.where((item) {
      if (item.matchedProductId != null) {
        return false;
      }
      if (item.suggestedProducts.isEmpty) {
        return true;
      }
      return item.suggestedProducts.first.matchScore <
          PurchaseOcrProductMatcher.autoMatchThreshold;
    }).length;

    if (draft.items.isNotEmpty) {
      risk += (uncertainMatches / draft.items.length) * 0.3;
    }

    risk += temporalRisk;

    if (risk < 0) return 0;
    if (risk > 1) return 1;
    return double.parse(risk.toStringAsFixed(4));
  }

  double _confidenceValue(OcrConfidence confidence) {
    switch (confidence) {
      case OcrConfidence.high:
        return 1.0;
      case OcrConfidence.medium:
        return 0.6;
      case OcrConfidence.low:
        return 0.25;
    }
  }
}
