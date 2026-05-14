import 'package:flutter_test/flutter_test.dart';
import 'package:clothes_inventory/features/purchase_ocr/domain/purchase_ocr_models.dart';
import 'package:clothes_inventory/features/purchase_ocr/domain/purchase_ocr_temporal_intelligence.dart';

class _InMemoryTemporalStore implements PurchaseOcrTemporalMemoryStore {
  final Map<int, SupplierStatsSnapshot> supplierStats = <int, SupplierStatsSnapshot>{};
  final Map<int, List<ProductPricePoint>> priceHistory = <int, List<ProductPricePoint>>{};
  final Map<String, List<UserCorrectionPattern>> corrections =
      <String, List<UserCorrectionPattern>>{};

  @override
  Future<void> appendProductPricePoint(ProductPricePoint point) async {
    priceHistory.putIfAbsent(point.productId, () => <ProductPricePoint>[]).insert(0, point);
  }

  @override
  Future<SupplierStatsSnapshot?> getSupplierStats(int supplierId) async {
    return supplierStats[supplierId];
  }

  @override
  Future<void> incrementUserCorrectionPattern({
    required String normalizedOcrText,
    int? suggestedProductId,
    required int selectedProductId,
  }) async {
    final list = corrections.putIfAbsent(
      normalizedOcrText,
      () => <UserCorrectionPattern>[],
    );
    final index = list.indexWhere(
      (p) =>
          p.suggestedProductId == suggestedProductId &&
          p.selectedProductId == selectedProductId,
    );
    if (index >= 0) {
      final current = list[index];
      list[index] = UserCorrectionPattern(
        ocrText: current.ocrText,
        suggestedProductId: current.suggestedProductId,
        selectedProductId: current.selectedProductId,
        correctionCount: current.correctionCount + 1,
        lastCorrectedAt: DateTime.now(),
      );
    } else {
      list.add(
        UserCorrectionPattern(
          ocrText: normalizedOcrText,
          suggestedProductId: suggestedProductId,
          selectedProductId: selectedProductId,
          correctionCount: 1,
          lastCorrectedAt: DateTime.now(),
        ),
      );
    }
    list.sort((a, b) => b.correctionCount.compareTo(a.correctionCount));
  }

  @override
  Future<List<ProductPricePoint>> listProductPriceHistory(
    int productId, {
    int limit = 20,
  }) async {
    final all = priceHistory[productId] ?? const <ProductPricePoint>[];
    return all.take(limit).toList(growable: false);
  }

  @override
  Future<List<UserCorrectionPattern>> listUserCorrectionPatterns(
    String normalizedOcrText,
  ) async {
    return corrections[normalizedOcrText] ?? const <UserCorrectionPattern>[];
  }

  @override
  Future<void> upsertSupplierStats(SupplierStatsSnapshot stats) async {
    supplierStats[stats.supplierId] = stats;
  }
}

void main() {
  late _InMemoryTemporalStore store;
  late PurchaseOcrTemporalIntelligenceLayer layer;

  setUp(() {
    store = _InMemoryTemporalStore();
    layer = PurchaseOcrTemporalIntelligenceLayer(memoryStore: store);
  });

  test('repeated supplier invoice test updates stability memory', () async {
    const baseDraft = PurchaseOcrDraft(
      rawText: 'raw',
      normalizedText: 'norm',
      imagePath: 'img.png',
      supplierId: 7,
      supplierName: 'Stable Supplier',
      items: [
        PurchaseOcrLineItemDraft(
          productName: 'Item A',
          quantity: 2,
          unitPrice: 100,
          matchedProductId: 1,
        ),
      ],
    );

    await layer.recordAcceptedInvoice(draft: baseDraft);
    await layer.recordAcceptedInvoice(draft: baseDraft);

    final stats = await store.getSupplierStats(7);
    expect(stats, isNotNull);
    expect(stats!.invoiceCount, 2);
    expect(stats.priceStabilityScore, greaterThan(0.5));
  });

  test('product price drift test flags trend anomaly', () async {
    store.priceHistory[1] = [
      ProductPricePoint(
        productId: 1,
        unitPrice: 130,
        observedAt: DateTime(2026, 4, 9),
      ),
      ProductPricePoint(
        productId: 1,
        unitPrice: 120,
        observedAt: DateTime(2026, 4, 8),
      ),
      ProductPricePoint(
        productId: 1,
        unitPrice: 110,
        observedAt: DateTime(2026, 4, 7),
      ),
      ProductPricePoint(
        productId: 1,
        unitPrice: 90,
        observedAt: DateTime(2026, 4, 6),
      ),
    ];

    final draft = PurchaseOcrDraft(
      rawText: 'raw',
      normalizedText: 'norm',
      imagePath: 'img.png',
      supplierId: 7,
      items: const [
        PurchaseOcrLineItemDraft(
          productName: 'Item A',
          quantity: 1,
          unitPrice: 170,
          matchedProductId: 1,
        ),
      ],
    );

    final out = await layer.analyze(
      draft: draft,
      normalizeText: (s) => s.toLowerCase().trim(),
    );

    expect(out.trendAnomalies, isNotEmpty);
    expect(out.riskContribution, greaterThan(0));
  });

  test('user correction adaptation test prioritizes corrected product', () async {
    await store.incrementUserCorrectionPattern(
      normalizedOcrText: 'stel wir',
      suggestedProductId: 2,
      selectedProductId: 1,
    );
    await store.incrementUserCorrectionPattern(
      normalizedOcrText: 'stel wir',
      suggestedProductId: 2,
      selectedProductId: 1,
    );
    await store.incrementUserCorrectionPattern(
      normalizedOcrText: 'stel wir',
      suggestedProductId: 2,
      selectedProductId: 1,
    );

    final draft = PurchaseOcrDraft(
      rawText: 'raw',
      normalizedText: 'norm',
      imagePath: 'img.png',
      items: const [
        PurchaseOcrLineItemDraft(
          productName: 'Stel Wir',
          quantity: 1,
          unitPrice: 100,
          matchedProductId: 2,
          suggestedProducts: [
            OcrProductSuggestion(productId: 2, productName: 'Copper Tube', matchScore: 0.82),
            OcrProductSuggestion(productId: 1, productName: 'Steel Wire', matchScore: 0.78),
          ],
        ),
      ],
    );

    final out = await layer.analyze(
      draft: draft,
      normalizeText: (s) => s.toLowerCase().trim(),
    );

    expect(out.items.first.matchedProductId, 1);
    expect(out.behavioralSignals, isNotEmpty);
  });
}
