import 'package:clothes_inventory/features/products/domain/product.dart';

class LearnedProductMapping {
  const LearnedProductMapping({
    required this.id,
    required this.ocrText,
    required this.productId,
    required this.usageCount,
    required this.lastUsedAt,
  });

  final int id;
  final String ocrText;
  final int productId;
  final int usageCount;
  final DateTime lastUsedAt;
}

abstract class OcrProductMappingsStore {
  Future<LearnedProductMapping?> findPreferredMapping(String normalizedOcrText);

  Future<void> saveOrIncrementMapping({
    required String normalizedOcrText,
    required int productId,
  });
}

class ProductMatchCandidate {
  const ProductMatchCandidate({required this.product, required this.score});

  final Product product;
  final double score;
}

class ProductMatchResult {
  const ProductMatchResult({
    required this.autoMatchedProductId,
    required this.suggestions,
    required this.usedLearnedMapping,
  });

  final int? autoMatchedProductId;
  final List<ProductMatchCandidate> suggestions;
  final bool usedLearnedMapping;
}

class PurchaseOcrProductMatcher {
  const PurchaseOcrProductMatcher({required OcrProductMappingsStore mappingsStore})
    : _mappingsStore = mappingsStore;

  final OcrProductMappingsStore _mappingsStore;

  static const double autoMatchThreshold = 0.88;
  static const double suggestionThreshold = 0.35;

  Future<ProductMatchResult> matchWithLearning(
    String input,
    List<Product> products,
  ) async {
    final normalized = _normalize(input);
    final suggestions = rankedSuggestions(
      input,
      products: products,
      maxCount: 5,
    );

    if (normalized.isEmpty) {
      return ProductMatchResult(
        autoMatchedProductId: null,
        suggestions: suggestions,
        usedLearnedMapping: false,
      );
    }

    final learned = await _mappingsStore.findPreferredMapping(normalized);
    if (learned != null) {
      final productExists = products.any((p) => p.id == learned.productId);
      if (productExists) {
        final boosted = _boostLearnedSuggestion(
          learnedProductId: learned.productId,
          products: products,
          existing: suggestions,
        );

        return ProductMatchResult(
          autoMatchedProductId: learned.productId,
          suggestions: boosted,
          usedLearnedMapping: true,
        );
      }
    }

    int? autoMatched;
    if (suggestions.isNotEmpty && suggestions.first.score >= autoMatchThreshold) {
      autoMatched = suggestions.first.product.id;
    }

    return ProductMatchResult(
      autoMatchedProductId: autoMatched,
      suggestions: suggestions,
      usedLearnedMapping: false,
    );
  }

  Future<void> learnFromUserSelection({
    required String ocrText,
    required int productId,
  }) {
    final normalized = _normalize(ocrText);
    if (normalized.isEmpty) {
      return Future.value();
    }
    return _mappingsStore.saveOrIncrementMapping(
      normalizedOcrText: normalized,
      productId: productId,
    );
  }

  ProductMatchCandidate? bestMatch(String input, List<Product> products) {
    final suggestions = rankedSuggestions(input, products: products, maxCount: 1);
    if (suggestions.isEmpty) return null;
    final candidate = suggestions.first;
    if (candidate.score < suggestionThreshold) {
      return null;
    }
    return candidate;
  }

  List<ProductMatchCandidate> rankedSuggestions(
    String input, {
    required List<Product> products,
    int maxCount = 5,
  }) {
    final source = _normalize(input);
    if (source.isEmpty) return const <ProductMatchCandidate>[];

    final scored = <ProductMatchCandidate>[];
    for (final product in products) {
      final target = _normalize(product.name);
      if (target.isEmpty) continue;

      final score = _score(source, target);
      if (score < suggestionThreshold) continue;
      scored.add(ProductMatchCandidate(product: product, score: score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    if (scored.length <= maxCount) {
      return scored;
    }
    return scored.take(maxCount).toList(growable: false);
  }

  List<ProductMatchCandidate> _boostLearnedSuggestion({
    required int learnedProductId,
    required List<Product> products,
    required List<ProductMatchCandidate> existing,
  }) {
    final mutable = [...existing];
    final index = mutable.indexWhere((e) => e.product.id == learnedProductId);

    if (index >= 0) {
      final learned = mutable.removeAt(index);
      mutable.insert(
        0,
        ProductMatchCandidate(
          product: learned.product,
          score: learned.score < 0.97 ? 0.97 : learned.score,
        ),
      );
      return mutable;
    }

    final learnedProduct = products.where((p) => p.id == learnedProductId);
    if (learnedProduct.isEmpty) {
      return mutable;
    }

    mutable.insert(
      0,
      ProductMatchCandidate(product: learnedProduct.first, score: 0.97),
    );
    return mutable.take(5).toList(growable: false);
  }

  String normalizeName(String input) => _normalize(input);

  String _normalize(String value) {
    var result = value.toLowerCase().trim();

    const arabicIndic = {
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
    };

    arabicIndic.forEach((key, replacement) {
      result = result.replaceAll(key, replacement);
    });

    result = result
        .replaceAll(RegExp(r'[\-_/|]'), ' ')
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return result;
  }

  double _score(String source, String target) {
    if (source == target) {
      return 1;
    }

    if (target.startsWith(source) || source.startsWith(target)) {
      return 0.92;
    }

    if (target.contains(source) || source.contains(target)) {
      return 0.85;
    }

    final sourceTokens = source.split(' ').where((x) => x.isNotEmpty).toSet();
    final targetTokens = target.split(' ').where((x) => x.isNotEmpty).toSet();
    if (sourceTokens.isEmpty || targetTokens.isEmpty) {
      return 0;
    }

    var intersection = 0;
    for (final token in sourceTokens) {
      if (targetTokens.contains(token)) {
        intersection++;
      }
    }

    final union = sourceTokens.length + targetTokens.length - intersection;
    final jaccard = union == 0 ? 0.0 : intersection / union;

    final distance = _levenshtein(source, target);
    final maxLen = source.length > target.length ? source.length : target.length;
    final similarity = maxLen == 0 ? 0.0 : 1 - (distance / maxLen);

    return (jaccard * 0.45) + (similarity * 0.55);
  }

  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final prev = List<int>.generate(b.length + 1, (i) => i);
    final curr = List<int>.filled(b.length + 1, 0);

    for (var i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        final deletion = prev[j] + 1;
        final insertion = curr[j - 1] + 1;
        final substitution = prev[j - 1] + cost;
        curr[j] = deletion < insertion
            ? (deletion < substitution ? deletion : substitution)
            : (insertion < substitution ? insertion : substitution);
      }
      for (var j = 0; j <= b.length; j++) {
        prev[j] = curr[j];
      }
    }

    return prev[b.length];
  }
}
