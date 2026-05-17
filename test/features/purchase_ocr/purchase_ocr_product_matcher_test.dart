import 'package:flutter_test/flutter_test.dart';
import 'package:delta_erp/features/products/domain/product.dart';
import 'package:delta_erp/features/purchase_ocr/domain/purchase_ocr_product_matcher.dart';

class _InMemoryMappingsStore implements OcrProductMappingsStore {
  _InMemoryMappingsStore({DateTime Function()? nowProvider})
    : _nowProvider = nowProvider ?? DateTime.now;

  static const double weightUsage = 0.03;
  static const double weightRecency = 1.0;

  final List<LearnedProductMapping> _mappings = [];
  final DateTime Function() _nowProvider;
  int _nextId = 1;

  @override
  Future<LearnedProductMapping?> findPreferredMapping(String normalizedOcrText) async {
    final matches = _mappings
        .where((m) => m.ocrText == normalizedOcrText)
        .toList(growable: false);
    if (matches.isEmpty) return null;

    final now = _nowProvider();

    matches.sort((a, b) {
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
    return matches.first;
  }

  @override
  Future<void> saveOrIncrementMapping({
    required String normalizedOcrText,
    required int productId,
  }) async {
    final index = _mappings.indexWhere(
      (m) => m.ocrText == normalizedOcrText && m.productId == productId,
    );
    if (index >= 0) {
      final current = _mappings[index];
      _mappings[index] = LearnedProductMapping(
        id: current.id,
        ocrText: current.ocrText,
        productId: current.productId,
        usageCount: current.usageCount + 1,
        lastUsedAt: _nowProvider(),
      );
      return;
    }

    _mappings.add(
      LearnedProductMapping(
        id: _nextId++,
        ocrText: normalizedOcrText,
        productId: productId,
        usageCount: 1,
        lastUsedAt: _nowProvider(),
      ),
    );
  }

  Future<void> seed({
    required String ocrText,
    required int productId,
    required int usageCount,
    required DateTime lastUsedAt,
  }) async {
    _mappings.add(
      LearnedProductMapping(
        id: _nextId++,
        ocrText: ocrText,
        productId: productId,
        usageCount: usageCount,
        lastUsedAt: lastUsedAt,
      ),
    );
  }

  double _weightedScore(LearnedProductMapping mapping, DateTime now) {
    return (mapping.usageCount * weightUsage) +
        (_recencyScore(mapping.lastUsedAt, now) * weightRecency);
  }

  double _recencyScore(DateTime lastUsedAt, DateTime now) {
    final days = now.difference(lastUsedAt).inDays;
    if (days <= 0) return 1.0;
    if (days <= 7) return 0.7;
    if (days <= 30) return 0.4;
    return 0.1;
  }
}

void main() {
  final fixedNow = DateTime(2026, 4, 10, 12);
  late _InMemoryMappingsStore mappingsStore;
  late PurchaseOcrProductMatcher matcher;

  setUp(() {
    mappingsStore = _InMemoryMappingsStore(nowProvider: () => fixedNow);
    matcher = PurchaseOcrProductMatcher(mappingsStore: mappingsStore);
  });

  const products = [
    Product(
      id: 1,
      name: 'Steel Wire',
      unitType: UnitType.piece,
      salePrice: 12,
      purchasePrice: 10,
      lowStockThreshold: 0,
    ),
    Product(
      id: 2,
      name: 'ماسورة PVC',
      unitType: UnitType.piece,
      salePrice: 30,
      purchasePrice: 25,
      lowStockThreshold: 0,
    ),
    Product(
      id: 3,
      name: 'Steel Wire 2mm',
      unitType: UnitType.piece,
      salePrice: 13,
      purchasePrice: 11,
      lowStockThreshold: 0,
    ),
    Product(
      id: 4,
      name: 'Steel Cable',
      unitType: UnitType.piece,
      salePrice: 14,
      purchasePrice: 12,
      lowStockThreshold: 0,
    ),
  ];

  test('returns exact english match with high score', () {
    final match = matcher.bestMatch('Steel Wire', products);
    expect(match, isNotNull);
    expect(match!.product.id, 1);
    expect(match.score, greaterThan(0.9));
  });

  test('returns arabic token overlap match', () {
    final match = matcher.bestMatch('ماسورة pvc', products);
    expect(match, isNotNull);
    expect(match!.product.id, 2);
  });

  test('returns null when score is below threshold', () {
    final match = matcher.bestMatch('Completely Different Product', products);
    expect(match?.score ?? 0, lessThan(PurchaseOcrProductMatcher.suggestionThreshold));
  });

  test('returns partial match suggestions ranked by score', () {
    final suggestions = matcher.rankedSuggestions(
      'steel wire',
      products: products,
      maxCount: 3,
    );

    expect(suggestions, isNotEmpty);
    expect(suggestions.first.product.id, 1);
    expect(suggestions.first.score, greaterThan(0.8));
  });

  test('similar names get different scores in rank order', () {
    final suggestions = matcher.rankedSuggestions(
      'steel wir',
      products: products,
      maxCount: 4,
    );

    expect(suggestions.length, greaterThanOrEqualTo(2));
    final wireScore = suggestions
        .firstWhere((e) => e.product.id == 1)
        .score;
    final cableScore = suggestions
        .firstWhere((e) => e.product.id == 4)
        .score;
    expect(wireScore, greaterThan(cableScore));
  });

  test('mapping reuse auto-selects mapped product', () async {
    await mappingsStore.seed(
      ocrText: 'steel wrie',
      productId: 1,
      usageCount: 7,
      lastUsedAt: DateTime(2026, 4, 10),
    );

    final result = await matcher.matchWithLearning('Steel Wrie', products);
    expect(result.usedLearnedMapping, isTrue);
    expect(result.autoMatchedProductId, 1);
    expect(result.suggestions, isNotEmpty);
    expect(result.suggestions.first.product.id, 1);
  });

  test('recent low-usage mapping can beat old high-usage mapping', () async {
    await mappingsStore.seed(
      ocrText: 'pipe',
      productId: 2,
      usageCount: 20,
      lastUsedAt: DateTime(2026, 2, 20),
    );
    await mappingsStore.seed(
      ocrText: 'pipe',
      productId: 4,
      usageCount: 2,
      lastUsedAt: DateTime(2026, 4, 10),
    );

    final result = await matcher.matchWithLearning('Pipe', products);
    expect(result.usedLearnedMapping, isTrue);
    expect(result.autoMatchedProductId, 4);
  });

  test('deterministic sorting with equal weighted score', () async {
    await mappingsStore.seed(
      ocrText: 'wire tie',
      productId: 1,
      usageCount: 5,
      lastUsedAt: DateTime(2026, 4, 3),
    );
    await mappingsStore.seed(
      ocrText: 'wire tie',
      productId: 3,
      usageCount: 5,
      lastUsedAt: DateTime(2026, 4, 3),
    );

    final preferred = await mappingsStore.findPreferredMapping('wire tie');
    expect(preferred, isNotNull);
    expect(preferred!.productId, 3);
  });

  test('new mapping creation and increment after user selection', () async {
    await matcher.learnFromUserSelection(ocrText: 'PVC tub', productId: 2);
    await matcher.learnFromUserSelection(ocrText: 'PVC tub', productId: 2);

    final stored = await mappingsStore.findPreferredMapping('pvc tub');
    expect(stored, isNotNull);
    expect(stored!.productId, 2);
    expect(stored.usageCount, 2);
  });
}
