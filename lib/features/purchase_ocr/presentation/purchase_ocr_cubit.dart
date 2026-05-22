import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:delta_erp/core/utils/number_utils.dart';
import 'package:delta_erp/features/accounts/data/accounts_repository.dart';
import 'package:delta_erp/features/products/data/product_repository.dart';
import 'package:delta_erp/features/products/domain/product.dart';
import 'package:delta_erp/features/purchase_ocr/data/purchase_ocr_service.dart';
import 'package:delta_erp/features/purchase_ocr/domain/purchase_ocr_anomaly_detector.dart';
import 'package:delta_erp/features/purchase_ocr/domain/purchase_ocr_intelligence_engine.dart';
import 'package:delta_erp/features/purchase_ocr/domain/purchase_invoice_parser.dart';
import 'package:delta_erp/features/purchase_ocr/domain/purchase_ocr_models.dart';
import 'package:delta_erp/features/purchase_ocr/domain/purchase_ocr_product_matcher.dart';
import 'package:delta_erp/features/purchase_ocr/domain/purchase_ocr_temporal_intelligence.dart';
import 'package:delta_erp/features/purchases/data/purchases_repository.dart';
import 'package:delta_erp/features/purchases/domain/purchase_models.dart';

enum PurchaseOcrStatus { idle, processing, ready, saving, success, failure }

class PurchaseOcrState extends Equatable {
  const PurchaseOcrState({
    this.status = PurchaseOcrStatus.idle,
    this.draft,
    this.suppliers = const <AccountLookup>[],
    this.products = const <Product>[],
    this.temporalInsights = const <PurchaseOcrTemporalInsight>[],
    this.trendAnomalies = const <PurchaseOcrTrendAnomaly>[],
    this.behavioralSignals = const <PurchaseOcrBehavioralSignal>[],
    this.learnedMappingsApplied = const <int>[],
    this.actionableRecommendations =
        const <PurchaseOcrActionableRecommendation>[],
    this.riskScore = 0,
    this.error,
    this.successInvoiceId,
  });

  final PurchaseOcrStatus status;
  final PurchaseOcrDraft? draft;
  final List<AccountLookup> suppliers;
  final List<Product> products;
  final List<PurchaseOcrTemporalInsight> temporalInsights;
  final List<PurchaseOcrTrendAnomaly> trendAnomalies;
  final List<PurchaseOcrBehavioralSignal> behavioralSignals;
  final List<int> learnedMappingsApplied;
  final List<PurchaseOcrActionableRecommendation> actionableRecommendations;
  final double riskScore;
  final String? error;
  final int? successInvoiceId;

  bool get isBusy =>
      status == PurchaseOcrStatus.processing ||
      status == PurchaseOcrStatus.saving;

  PurchaseOcrState copyWith({
    PurchaseOcrStatus? status,
    PurchaseOcrDraft? draft,
    List<AccountLookup>? suppliers,
    List<Product>? products,
    List<PurchaseOcrTemporalInsight>? temporalInsights,
    List<PurchaseOcrTrendAnomaly>? trendAnomalies,
    List<PurchaseOcrBehavioralSignal>? behavioralSignals,
    List<int>? learnedMappingsApplied,
    List<PurchaseOcrActionableRecommendation>? actionableRecommendations,
    double? riskScore,
    String? error,
    int? successInvoiceId,
    bool clearError = false,
  }) {
    return PurchaseOcrState(
      status: status ?? this.status,
      draft: draft ?? this.draft,
      suppliers: suppliers ?? this.suppliers,
      products: products ?? this.products,
      temporalInsights: temporalInsights ?? this.temporalInsights,
      trendAnomalies: trendAnomalies ?? this.trendAnomalies,
      behavioralSignals: behavioralSignals ?? this.behavioralSignals,
      learnedMappingsApplied:
          learnedMappingsApplied ?? this.learnedMappingsApplied,
      actionableRecommendations:
          actionableRecommendations ?? this.actionableRecommendations,
      riskScore: riskScore ?? this.riskScore,
      error: clearError ? null : (error ?? this.error),
      successInvoiceId: successInvoiceId ?? this.successInvoiceId,
    );
  }

  @override
  List<Object?> get props => [
    status,
    draft,
    suppliers,
    products,
    temporalInsights,
    trendAnomalies,
    behavioralSignals,
    learnedMappingsApplied,
    actionableRecommendations,
    riskScore,
    error,
    successInvoiceId,
  ];
}

class PurchaseOcrCubit extends Cubit<PurchaseOcrState> {
  PurchaseOcrCubit({
    required PurchaseOcrService ocrService,
    required PurchaseInvoiceParser parser,
    required PurchaseOcrProductMatcher matcher,
    required PurchaseOcrAnomalyDetector anomalyDetector,
    PurchaseOcrIntelligenceEngine? intelligenceEngine,
    PurchaseOcrTemporalIntelligenceLayer? temporalLayer,
    required AccountsRepository accountsRepository,
    required ProductRepository productRepository,
    required PurchasesRepository purchasesRepository,
  }) : _ocrService = ocrService,
       _matcher = matcher,
       _intelligenceEngine =
           intelligenceEngine ??
           PurchaseOcrIntelligenceEngine(
             parser: parser,
             matcher: matcher,
             anomalyDetector: anomalyDetector,
             temporalLayer: temporalLayer,
           ),
       _temporalLayer = temporalLayer,
       _accountsRepository = accountsRepository,
       _productRepository = productRepository,
       _purchasesRepository = purchasesRepository,
       super(const PurchaseOcrState());

  final PurchaseOcrService _ocrService;
  final PurchaseOcrProductMatcher _matcher;
  final PurchaseOcrIntelligenceEngine _intelligenceEngine;
  final PurchaseOcrTemporalIntelligenceLayer? _temporalLayer;
  final AccountsRepository _accountsRepository;
  final ProductRepository _productRepository;
  final PurchasesRepository _purchasesRepository;
  static const Duration _ocrExecutionDelay = Duration(milliseconds: 300);

  Future<void> processImage(
    String imagePath, {
    bool userInitiated = true,
  }) async {
    if (!userInitiated) {
      _emitFailure('OCR execution requires explicit user action.');
      return;
    }

    emit(
      state.copyWith(status: PurchaseOcrStatus.processing, clearError: true),
    );

    try {
      await Future<void>.delayed(_ocrExecutionDelay);
      final rawText = await _ocrService.extractText(imagePath: imagePath);
      final suppliers = await _accountsRepository.listByType('supplier');
      final products = await _productRepository.listProducts();

      final intelligence = await _intelligenceEngine.analyze(
        rawText: rawText,
        imagePath: imagePath,
        products: products,
        resolveSupplierId: (supplierName) =>
            _findSupplierId(supplierName, suppliers),
      );

      emit(
        state.copyWith(
          status: PurchaseOcrStatus.ready,
          draft: intelligence.parsedInvoice,
          suppliers: suppliers,
          products: products,
          temporalInsights: intelligence.temporalInsights,
          trendAnomalies: intelligence.trendAnomalies,
          behavioralSignals: intelligence.behavioralSignals,
          learnedMappingsApplied: intelligence.learnedMappingsApplied,
          actionableRecommendations: intelligence.actionableRecommendations,
          riskScore: intelligence.riskScore,
          clearError: true,
        ),
      );
    } catch (error) {
      _emitFailure(_errorMessage(error));
    }
  }

  int? _findSupplierId(String? supplierName, List<AccountLookup> suppliers) {
    final normalizedTarget = _normalizeName(supplierName);
    if (normalizedTarget.isEmpty) return null;

    for (final supplier in suppliers) {
      final candidate = _normalizeName(supplier.name);
      if (candidate == normalizedTarget) {
        return supplier.id;
      }
    }
    return null;
  }

  String _normalizeName(String? raw) {
    if (raw == null) return '';
    return raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  void setSupplierId(int? supplierId) {
    final draft = state.draft;
    if (draft == null) return;

    String? supplierName = draft.supplierName;
    if (supplierId != null) {
      final matched = state.suppliers.where(
        (supplier) => supplier.id == supplierId,
      );
      if (matched.isNotEmpty) {
        supplierName = matched.first.name;
      }
    }

    emit(
      state.copyWith(
        draft: draft.copyWith(
          supplierId: supplierId,
          supplierName: supplierName,
        ),
      ),
    );
  }

  void setSupplierName(String value) {
    final draft = state.draft;
    if (draft == null) return;

    emit(
      state.copyWith(
        draft: draft.copyWith(supplierName: value, clearSupplierId: true),
      ),
    );
  }

  void setInvoiceDate(DateTime? date) {
    final draft = state.draft;
    if (draft == null) return;

    emit(
      state.copyWith(
        draft: draft.copyWith(invoiceDate: date, clearDate: date == null),
      ),
    );
  }

  Future<void> updateItem({
    required int index,
    String? productName,
    double? quantity,
    double? unitPrice,
    int? matchedProductId,
    bool clearMatchedProduct = false,
  }) async {
    final draft = state.draft;
    if (draft == null) return;
    if (index < 0 || index >= draft.items.length) return;

    final updated = [...draft.items];
    final current = updated[index];
    final hasNameEdit = productName != null;
    var next = current.copyWith(
      productName: productName,
      quantity: quantity,
      unitPrice: unitPrice,
      matchedProductId: matchedProductId,
      clearMatchedProduct: clearMatchedProduct,
    );

    final updatedName = productName ?? current.productName;
    if (hasNameEdit && updatedName.trim().isNotEmpty) {
      next = await _applyProductMatching(item: next, products: state.products);
      if (matchedProductId != null) {
        final previousAutoMatch = current.matchedProductId;
        next = next.copyWith(matchedProductId: matchedProductId);
        await _matcher.learnFromUserSelection(
          ocrText: next.productName,
          productId: matchedProductId,
        );
        final layer = _temporalLayer;
        if (layer != null) {
          try {
            await layer.recordUserCorrection(
              normalizedOcrText: _matcher.normalizeName(next.productName),
              suggestedProductId: previousAutoMatch,
              selectedProductId: matchedProductId,
            );
          } catch (_) {
            // Non-blocking temporal persistence.
          }
        }
      }
    }

    if (updatedName.trim().isNotEmpty && matchedProductId != null) {
      final previousAutoMatch = current.matchedProductId;
      next = next.copyWith(matchedProductId: matchedProductId);
      await _matcher.learnFromUserSelection(
        ocrText: next.productName,
        productId: matchedProductId,
      );
      final layer = _temporalLayer;
      if (layer != null) {
        try {
          await layer.recordUserCorrection(
            normalizedOcrText: _matcher.normalizeName(next.productName),
            suggestedProductId: previousAutoMatch,
            selectedProductId: matchedProductId,
          );
        } catch (_) {
          // Non-blocking temporal persistence.
        }
      }
    }

    if (clearMatchedProduct) {
      next = next.copyWith(clearMatchedProduct: true);
    }

    updated[index] = next;

    emit(
      state.copyWith(draft: draft.copyWith(items: updated), clearError: true),
    );
  }

  void addItem() {
    final draft = state.draft;
    if (draft == null) return;

    final updated = [
      ...draft.items,
      const PurchaseOcrLineItemDraft(
        productName: '',
        quantity: 1,
        unitPrice: 0,
      ),
    ];
    emit(
      state.copyWith(draft: draft.copyWith(items: updated), clearError: true),
    );
  }

  void removeItem(int index) {
    final draft = state.draft;
    if (draft == null) return;
    if (index < 0 || index >= draft.items.length) return;

    final updated = [...draft.items]..removeAt(index);
    emit(
      state.copyWith(draft: draft.copyWith(items: updated), clearError: true),
    );
  }

  void addOrUpdateProductInState(Product product) {
    final id = product.id;
    if (id == null) return;

    final updated = [...state.products];
    final index = updated.indexWhere((p) => p.id == id);
    if (index >= 0) {
      updated[index] = product;
    } else {
      updated.add(product);
    }
    updated.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    emit(state.copyWith(products: updated));
  }

  Future<void> savePurchaseInvoice() async {
    final draft = state.draft;
    if (draft == null) {
      emit(
        state.copyWith(
          status: PurchaseOcrStatus.failure,
          error: 'No OCR data to save.',
        ),
      );
      return;
    }

    if (draft.items.isEmpty) {
      emit(
        state.copyWith(
          status: PurchaseOcrStatus.failure,
          error: 'Add at least one product.',
        ),
      );
      return;
    }

    for (final item in draft.items) {
      if (item.productName.trim().isEmpty) {
        emit(
          state.copyWith(
            status: PurchaseOcrStatus.failure,
            error: 'Item name is required.',
          ),
        );
        return;
      }
      if (item.quantity <= 0) {
        emit(
          state.copyWith(
            status: PurchaseOcrStatus.failure,
            error: 'Quantity must be greater than zero',
          ),
        );
        return;
      }
      if (!isIntegerLike(item.quantity)) {
        emit(
          state.copyWith(
            status: PurchaseOcrStatus.failure,
            error: 'Quantity must be a whole number.',
          ),
        );
        return;
      }
      if (item.unitPrice < 0) {
        emit(
          state.copyWith(
            status: PurchaseOcrStatus.failure,
            error: 'Price cannot be negative.',
          ),
        );
        return;
      }
    }

    emit(state.copyWith(status: PurchaseOcrStatus.saving, clearError: true));

    try {
      final supplierId = await _resolveSupplierId(draft);
      final products = await _productRepository.listProducts();
      final purchaseItems = <PurchaseDraftItem>[];

      for (final line in draft.items) {
        final product = await _resolveProduct(line, products);
        final productId = product.id;
        if (productId != null && line.productName.trim().isNotEmpty) {
          // Treat accepted invoice lines as supervised feedback for future OCR matches.
          await _matcher.learnFromUserSelection(
            ocrText: line.productName,
            productId: productId,
          );
        }
        final quantity = roundQuantity(line.quantity);
        if (product.unitType == UnitType.piece && !isIntegerLike(quantity)) {
          throw StateError('Piece products require integer quantity.');
        }

        purchaseItems.add(
          PurchaseDraftItem(
            productId: product.id!,
            productName: product.name,
            barcode: product.barcode,
            unitType: product.unitType.name,
            quantity: quantity,
            unitPrice: roundCurrency(line.unitPrice),
          ),
        );
      }

      final total = purchaseItems.fold<double>(
        0,
        (sum, item) => sum + item.lineTotal,
      );

      final invoiceId = await _purchasesRepository.createPurchase(
        PurchaseCreateRequest(
          supplierId: supplierId,
          items: purchaseItems,
          paidAmount: roundCurrency(total),
          paymentMethod: PaymentMethod.cash,
          notes: 'Created from offline OCR invoice scan.',
          createdAt: draft.invoiceDate,
        ),
      );

      emit(
        state.copyWith(
          status: PurchaseOcrStatus.success,
          successInvoiceId: invoiceId,
          clearError: true,
        ),
      );

      final layer = _temporalLayer;
      if (layer != null) {
        try {
          await layer.recordAcceptedInvoice(draft: draft);
        } catch (_) {
          // Non-blocking temporal persistence.
        }
      }
    } catch (error) {
      _emitFailure(_errorMessage(error));
    }
  }

  Future<int> _resolveSupplierId(PurchaseOcrDraft draft) async {
    if (draft.supplierId != null) {
      return draft.supplierId!;
    }

    final supplierName = (draft.supplierName ?? '').trim();
    if (supplierName.isEmpty) {
      throw StateError('Supplier is required.');
    }

    final suppliers = await _accountsRepository.listByType('supplier');
    final normalized = _normalizeName(supplierName);

    for (final supplier in suppliers) {
      if (_normalizeName(supplier.name) == normalized) {
        return supplier.id;
      }
    }

    return _accountsRepository.createAccount(
      name: supplierName,
      accountType: 'supplier',
    );
  }

  Future<Product> _resolveProduct(
    PurchaseOcrLineItemDraft line,
    List<Product> products,
  ) async {
    if (line.matchedProductId != null) {
      for (final product in products) {
        if (product.id == line.matchedProductId) {
          return product;
        }
      }
    }

    final match = _matcher.bestMatch(line.productName, products);
    if (match != null) {
      return match.product;
    }

    final quantityRounded = roundQuantity(line.quantity);
    final unitType = isIntegerLike(quantityRounded)
        ? UnitType.piece
        : UnitType.weight;

    final created = await _productRepository.createProduct(
      Product(
        id: null,
        name: line.productName.trim(),
        unitType: unitType,
        salePrice: roundCurrency(line.unitPrice),
        purchasePrice: roundCurrency(line.unitPrice),
        lowStockThreshold: 0,
      ),
    );

    products.add(created);
    return created;
  }

  String _errorMessage(Object error) {
    if (error is OcrFailure) {
      if (error.debugMessage.trim().isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
            'OCR failure (${error.category.label}): ${error.debugMessage}',
          );
        }
      }
      return error.userMessage;
    }
    if (error is StateError) {
      return error.message.toString();
    }

    const badStatePrefix = 'Bad state: ';
    final text = error.toString();
    if (text.startsWith(badStatePrefix)) {
      return text.substring(badStatePrefix.length);
    }
    return text;
  }

  void _emitFailure(String message) {
    emit(state.copyWith(status: PurchaseOcrStatus.failure, error: message));
    emit(state.copyWith(status: PurchaseOcrStatus.idle, error: message));
  }

  Future<PurchaseOcrLineItemDraft> _applyProductMatching({
    required PurchaseOcrLineItemDraft item,
    required List<Product> products,
  }) async {
    final matchResult = await _matcher.matchWithLearning(
      item.productName,
      products,
    );

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

    return item.copyWith(
      matchedProductId: matchResult.autoMatchedProductId,
      suggestedProducts: suggestions,
    );
  }
}
