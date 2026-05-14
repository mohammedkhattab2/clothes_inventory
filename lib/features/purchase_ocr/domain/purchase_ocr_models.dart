import 'package:equatable/equatable.dart';

enum OcrConfidence { high, medium, low }

enum OcrAnomalyType { price, structural, supplier }

enum OcrAnomalySeverity { low, medium, high }

enum OcrErrorType {
  missingExecutable,
  missingTessdata,
  missingLanguageData,
  processFailed,
  timeout,
  emptyResult,
  invalidImage,
  unknown,
}

enum OcrErrorSeverity { low, medium, high, critical }

extension OcrErrorTypeCodeX on OcrErrorType {
  String get stableCode {
    switch (this) {
      case OcrErrorType.missingExecutable:
        return 'OCR_001';
      case OcrErrorType.missingTessdata:
        return 'OCR_002';
      case OcrErrorType.missingLanguageData:
        return 'OCR_003';
      case OcrErrorType.processFailed:
        return 'OCR_004';
      case OcrErrorType.timeout:
        return 'OCR_005';
      case OcrErrorType.emptyResult:
        return 'OCR_006';
      case OcrErrorType.invalidImage:
        return 'OCR_007';
      case OcrErrorType.unknown:
        return 'OCR_999';
    }
  }
}

extension OcrErrorTypeSeverityX on OcrErrorType {
  OcrErrorSeverity get severity {
    switch (this) {
      case OcrErrorType.missingExecutable:
        return OcrErrorSeverity.critical;
      case OcrErrorType.missingTessdata:
        return OcrErrorSeverity.critical;
      case OcrErrorType.missingLanguageData:
        return OcrErrorSeverity.high;
      case OcrErrorType.processFailed:
        return OcrErrorSeverity.high;
      case OcrErrorType.timeout:
        return OcrErrorSeverity.medium;
      case OcrErrorType.emptyResult:
        return OcrErrorSeverity.medium;
      case OcrErrorType.invalidImage:
        return OcrErrorSeverity.low;
      case OcrErrorType.unknown:
        return OcrErrorSeverity.medium;
    }
  }
}

enum PurchaseOcrRecommendationType { supplier, product, system }

class PurchaseOcrActionableRecommendation extends Equatable {
  const PurchaseOcrActionableRecommendation({
    required this.type,
    required this.message,
    required this.severity,
    required this.suggestedAction,
  });

  final PurchaseOcrRecommendationType type;
  final String message;
  final OcrAnomalySeverity severity;
  final String suggestedAction;

  @override
  List<Object?> get props => [type, message, severity, suggestedAction];
}

class PurchaseOcrAnomaly extends Equatable {
  const PurchaseOcrAnomaly({
    required this.type,
    required this.severity,
    required this.message,
  });

  final OcrAnomalyType type;
  final OcrAnomalySeverity severity;
  final String message;

  @override
  List<Object?> get props => [type, severity, message];
}

class OcrProductSuggestion extends Equatable {
  const OcrProductSuggestion({
    required this.productId,
    required this.productName,
    required this.matchScore,
  });

  final int productId;
  final String productName;
  final double matchScore;

  @override
  List<Object?> get props => [productId, productName, matchScore];
}

class PurchaseOcrLineItemDraft extends Equatable {
  const PurchaseOcrLineItemDraft({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.confidence = OcrConfidence.low,
    this.matchedProductId,
    this.suggestedProducts = const <OcrProductSuggestion>[],
  });

  final String productName;
  final double quantity;
  final double unitPrice;
  final OcrConfidence confidence;
  final int? matchedProductId;
  final List<OcrProductSuggestion> suggestedProducts;

  double get lineTotal => quantity * unitPrice;

  PurchaseOcrLineItemDraft copyWith({
    String? productName,
    double? quantity,
    double? unitPrice,
    OcrConfidence? confidence,
    int? matchedProductId,
    List<OcrProductSuggestion>? suggestedProducts,
    bool clearMatchedProduct = false,
  }) {
    return PurchaseOcrLineItemDraft(
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      confidence: confidence ?? this.confidence,
      matchedProductId: clearMatchedProduct
          ? null
          : (matchedProductId ?? this.matchedProductId),
      suggestedProducts: suggestedProducts ?? this.suggestedProducts,
    );
  }

  @override
  List<Object?> get props => [
    productName,
    quantity,
    unitPrice,
    confidence,
    matchedProductId,
    suggestedProducts,
  ];
}

class PurchaseOcrDraft extends Equatable {
  const PurchaseOcrDraft({
    required this.rawText,
    required this.normalizedText,
    required this.imagePath,
    this.supplierName,
    this.supplierConfidence,
    this.supplierId,
    this.invoiceDate,
    this.totalAmount,
    this.totalAmountConfidence,
    this.items = const <PurchaseOcrLineItemDraft>[],
    this.anomalies = const <PurchaseOcrAnomaly>[],
  });

  final String rawText;
  final String normalizedText;
  final String imagePath;
  final String? supplierName;
  final OcrConfidence? supplierConfidence;
  final int? supplierId;
  final DateTime? invoiceDate;
  final double? totalAmount;
  final OcrConfidence? totalAmountConfidence;
  final List<PurchaseOcrLineItemDraft> items;
  final List<PurchaseOcrAnomaly> anomalies;

  double get computedSubtotal =>
      items.fold<double>(0, (sum, item) => sum + item.lineTotal);

  PurchaseOcrDraft copyWith({
    String? rawText,
    String? normalizedText,
    String? imagePath,
    String? supplierName,
    OcrConfidence? supplierConfidence,
    int? supplierId,
    DateTime? invoiceDate,
    double? totalAmount,
    OcrConfidence? totalAmountConfidence,
    List<PurchaseOcrLineItemDraft>? items,
    List<PurchaseOcrAnomaly>? anomalies,
    bool clearSupplier = false,
    bool clearSupplierConfidence = false,
    bool clearSupplierId = false,
    bool clearDate = false,
    bool clearTotal = false,
    bool clearTotalConfidence = false,
  }) {
    return PurchaseOcrDraft(
      rawText: rawText ?? this.rawText,
      normalizedText: normalizedText ?? this.normalizedText,
      imagePath: imagePath ?? this.imagePath,
      supplierName: clearSupplier ? null : (supplierName ?? this.supplierName),
      supplierConfidence: clearSupplierConfidence
          ? null
          : (supplierConfidence ?? this.supplierConfidence),
      supplierId: clearSupplierId ? null : (supplierId ?? this.supplierId),
      invoiceDate: clearDate ? null : (invoiceDate ?? this.invoiceDate),
      totalAmount: clearTotal ? null : (totalAmount ?? this.totalAmount),
      totalAmountConfidence: clearTotalConfidence
          ? null
          : (totalAmountConfidence ?? this.totalAmountConfidence),
      items: items ?? this.items,
      anomalies: anomalies ?? this.anomalies,
    );
  }

  @override
  List<Object?> get props => [
    rawText,
    normalizedText,
    imagePath,
    supplierName,
    supplierConfidence,
    supplierId,
    invoiceDate,
    totalAmount,
    totalAmountConfidence,
    items,
    anomalies,
  ];
}
