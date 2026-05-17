import 'package:flutter_test/flutter_test.dart';
import 'package:delta_erp/features/products/domain/product.dart';
import 'package:delta_erp/features/purchase_ocr/domain/purchase_invoice_parser.dart';
import 'package:delta_erp/features/purchase_ocr/domain/purchase_ocr_anomaly_detector.dart';
import 'package:delta_erp/features/purchase_ocr/domain/purchase_ocr_intelligence_engine.dart';
import 'package:delta_erp/features/purchase_ocr/domain/purchase_ocr_models.dart';
import 'package:delta_erp/features/purchase_ocr/domain/purchase_ocr_product_matcher.dart';

class _FakeMappingsStore implements OcrProductMappingsStore {
  final Map<String, LearnedProductMapping> _preferred = <String, LearnedProductMapping>{};

  @override
  Future<LearnedProductMapping?> findPreferredMapping(String normalizedOcrText) async {
    return _preferred[normalizedOcrText];
  }

  @override
  Future<void> saveOrIncrementMapping({
    required String normalizedOcrText,
    required int productId,
  }) async {}

  void seed({required String normalizedText, required int productId}) {
    _preferred[normalizedText] = LearnedProductMapping(
      id: 1,
      ocrText: normalizedText,
      productId: productId,
      usageCount: 5,
      lastUsedAt: DateTime(2026, 4, 10),
    );
  }
}

class _FakeHistoryProvider implements PurchaseOcrAnomalyHistoryProvider {
  final Map<int, double> avgPriceByProduct = <int, double>{};
  final Map<int, int> invoiceCountBySupplier = <int, int>{};
  final Map<int, double> avgItemsBySupplier = <int, double>{};

  @override
  Future<double?> averageProductUnitPrice(int productId) async {
    return avgPriceByProduct[productId];
  }

  @override
  Future<int> supplierInvoiceCount(int supplierId) async {
    return invoiceCountBySupplier[supplierId] ?? 0;
  }

  @override
  Future<double?> supplierAverageItemsPerInvoice(int supplierId) async {
    return avgItemsBySupplier[supplierId];
  }
}

void main() {
  late _FakeMappingsStore mappingsStore;
  late _FakeHistoryProvider history;
  late PurchaseOcrIntelligenceEngine engine;

  const products = [
    Product(
      id: 1,
      name: 'Steel Wire',
      unitType: UnitType.piece,
      salePrice: 20,
      purchasePrice: 100,
      lowStockThreshold: 0,
    ),
    Product(
      id: 2,
      name: 'Copper Tube',
      unitType: UnitType.piece,
      salePrice: 30,
      purchasePrice: 60,
      lowStockThreshold: 0,
    ),
  ];

  setUp(() {
    mappingsStore = _FakeMappingsStore();
    history = _FakeHistoryProvider();

    engine = PurchaseOcrIntelligenceEngine(
      parser: const PurchaseInvoiceParser(),
      matcher: PurchaseOcrProductMatcher(mappingsStore: mappingsStore),
      anomalyDetector: PurchaseOcrAnomalyDetector(historyProvider: history),
    );
  });

  test('clean invoice flow', () async {
    history.avgPriceByProduct[1] = 100;
    history.invoiceCountBySupplier[7] = 4;
    history.avgItemsBySupplier[7] = 1;

    const raw = '''
Supplier: Raw Supplier
Date: 2026-04-10
Steel Wire 2 x 100
Grand Total: 200
''';

    final result = await engine.analyze(
      rawText: raw,
      imagePath: 'invoice.png',
      products: products,
      resolveSupplierId: (_) => 7,
    );

    expect(result.parsedInvoice.items, hasLength(1));
    expect(result.parsedInvoice.anomalies, isEmpty);
    expect(result.actionableRecommendations, isEmpty);
    expect(result.riskScore, lessThan(0.35));
  });

  test('noisy invoice flow', () async {
    const raw = '''
@@ ## Invoice
Supplier: Raw Supplier
Steel Wire @@ 90
''';

    final result = await engine.analyze(
      rawText: raw,
      imagePath: 'invoice.png',
      products: products,
      resolveSupplierId: (_) => null,
    );

    expect(result.parsedInvoice.anomalies, isNotEmpty);
    expect(result.riskScore, greaterThan(0.3));
  });

  test('high anomaly invoice', () async {
    history.avgPriceByProduct[1] = 100;
    history.invoiceCountBySupplier[7] = 3;
    history.avgItemsBySupplier[7] = 1;

    const raw = '''
Supplier: Raw Supplier
Date: 2026-04-10
Steel Wire 1 x 240
Grand Total: 50
''';

    final result = await engine.analyze(
      rawText: raw,
      imagePath: 'invoice.png',
      products: products,
      resolveSupplierId: (_) => 7,
    );

    expect(
      result.anomalies.any((a) => a.severity == OcrAnomalySeverity.high),
      isTrue,
    );
    expect(
      result.actionableRecommendations.any(
        (r) => r.type == PurchaseOcrRecommendationType.product,
      ),
      isTrue,
    );
    expect(result.riskScore, greaterThan(0.55));
  });

  test('supplier risk recommendation generated', () async {
    history.invoiceCountBySupplier[7] = 0;

    const raw = '''
Supplier: Risky Supplier
Date: 2026-04-10
Copper Tube 1 x 60
Grand Total: 60
''';

    final result = await engine.analyze(
      rawText: raw,
      imagePath: 'invoice.png',
      products: products,
      resolveSupplierId: (_) => 7,
    );

    expect(
      result.actionableRecommendations.any(
        (r) => r.type == PurchaseOcrRecommendationType.supplier,
      ),
      isTrue,
    );
  });

  test('price anomaly suggestion generated', () async {
    history.avgPriceByProduct[1] = 100;
    history.invoiceCountBySupplier[7] = 3;
    history.avgItemsBySupplier[7] = 1;

    const raw = '''
Supplier: Raw Supplier
Date: 2026-04-10
Steel Wire 1 x 180
Grand Total: 180
''';

    final result = await engine.analyze(
      rawText: raw,
      imagePath: 'invoice.png',
      products: products,
      resolveSupplierId: (_) => 7,
    );

    expect(
      result.actionableRecommendations.any(
        (r) => r.type == PurchaseOcrRecommendationType.product,
      ),
      isTrue,
    );
  });

  test('learning-based auto match case', () async {
    mappingsStore.seed(normalizedText: 'stel wir', productId: 1);
    history.invoiceCountBySupplier[7] = 2;
    history.avgItemsBySupplier[7] = 1;

    const raw = '''
Supplier: Raw Supplier
Date: 2026-04-10
Stel Wir 1 100
Grand Total: 100
''';

    final result = await engine.analyze(
      rawText: raw,
      imagePath: 'invoice.png',
      products: products,
      resolveSupplierId: (_) => 7,
    );

    expect(result.learnedMappingsApplied, isNotEmpty);
    expect(result.matchedItems.first.matchedProductId, 1);
  });
}
