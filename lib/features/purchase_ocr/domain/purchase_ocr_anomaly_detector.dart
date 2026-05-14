import 'dart:math' as math;

import 'package:clothes_inventory/features/purchase_ocr/domain/purchase_ocr_models.dart';

abstract class PurchaseOcrAnomalyHistoryProvider {
  Future<double?> averageProductUnitPrice(int productId);

  Future<int> supplierInvoiceCount(int supplierId);

  Future<double?> supplierAverageItemsPerInvoice(int supplierId);
}

class PurchaseOcrAnomalyDetector {
  const PurchaseOcrAnomalyDetector({
    required PurchaseOcrAnomalyHistoryProvider historyProvider,
  }) : _historyProvider = historyProvider;

  static const double _priceDeviationThreshold = 0.30;
  static const double _severePriceDeviationThreshold = 0.60;
  static const double _totalMismatchRatioThreshold = 0.10;
  static const double _supplierStructureDeviationThreshold = 0.70;

  final PurchaseOcrAnomalyHistoryProvider _historyProvider;

  Future<List<PurchaseOcrAnomaly>> detect(PurchaseOcrDraft draft) async {
    final anomalies = <PurchaseOcrAnomaly>[];

    anomalies.addAll(await _detectPriceAnomalies(draft));
    anomalies.addAll(_detectStructuralAnomalies(draft));
    anomalies.addAll(await _detectSupplierAnomalies(draft));

    return anomalies;
  }

  Future<List<PurchaseOcrAnomaly>> _detectPriceAnomalies(
    PurchaseOcrDraft draft,
  ) async {
    final anomalies = <PurchaseOcrAnomaly>[];

    for (final item in draft.items) {
      final productId = item.matchedProductId;
      if (productId == null) continue;
      if (item.unitPrice <= 0) continue;

      final avg = await _historyProvider.averageProductUnitPrice(productId);
      if (avg == null || avg <= 0) continue;

      final ratio = ((item.unitPrice - avg).abs()) / avg;
      if (ratio < _priceDeviationThreshold) continue;

      final severity = ratio >= _severePriceDeviationThreshold
          ? OcrAnomalySeverity.high
          : OcrAnomalySeverity.medium;
      final direction = item.unitPrice > avg ? 'above' : 'below';
      anomalies.add(
        PurchaseOcrAnomaly(
          type: OcrAnomalyType.price,
          severity: severity,
          message:
              'Price anomaly for "${item.productName}": ${item.unitPrice.toStringAsFixed(2)} is $direction historical average ${avg.toStringAsFixed(2)}.',
        ),
      );
    }

    return anomalies;
  }

  List<PurchaseOcrAnomaly> _detectStructuralAnomalies(PurchaseOcrDraft draft) {
    final anomalies = <PurchaseOcrAnomaly>[];

    if (draft.totalAmount == null) {
      anomalies.add(
        const PurchaseOcrAnomaly(
          type: OcrAnomalyType.structural,
          severity: OcrAnomalySeverity.medium,
          message: 'Invoice total is missing from OCR result.',
        ),
      );
      return anomalies;
    }

    final total = draft.totalAmount!;
    final subtotal = draft.computedSubtotal;
    final diff = (subtotal - total).abs();
    final base = math.max(total.abs(), 1);
    final ratio = diff / base;

    if (ratio >= _totalMismatchRatioThreshold) {
      anomalies.add(
        PurchaseOcrAnomaly(
          type: OcrAnomalyType.structural,
          severity: OcrAnomalySeverity.high,
          message:
              'Invoice total mismatch: OCR total ${total.toStringAsFixed(2)} vs computed subtotal ${subtotal.toStringAsFixed(2)}.',
        ),
      );
    }

    return anomalies;
  }

  Future<List<PurchaseOcrAnomaly>> _detectSupplierAnomalies(
    PurchaseOcrDraft draft,
  ) async {
    final anomalies = <PurchaseOcrAnomaly>[];

    final supplierId = draft.supplierId;
    final supplierName = (draft.supplierName ?? '').trim();

    if (supplierId == null) {
      if (supplierName.isNotEmpty) {
        anomalies.add(
          PurchaseOcrAnomaly(
            type: OcrAnomalyType.supplier,
            severity: OcrAnomalySeverity.low,
            message:
                'Supplier "${draft.supplierName}" appears new or unmatched. Review before saving.',
          ),
        );
      }
      return anomalies;
    }

    final invoiceCount = await _historyProvider.supplierInvoiceCount(
      supplierId,
    );
    if (invoiceCount == 0) {
      anomalies.add(
        PurchaseOcrAnomaly(
          type: OcrAnomalyType.supplier,
          severity: OcrAnomalySeverity.medium,
          message:
              'Supplier "${draft.supplierName ?? supplierId}" has no historical invoices yet.',
        ),
      );
      return anomalies;
    }

    final avgItems = await _historyProvider.supplierAverageItemsPerInvoice(
      supplierId,
    );
    if (avgItems == null || avgItems <= 0) {
      return anomalies;
    }

    final currentItems = draft.items.length.toDouble();
    final deviation = ((currentItems - avgItems).abs()) / avgItems;
    if (deviation >= _supplierStructureDeviationThreshold) {
      anomalies.add(
        PurchaseOcrAnomaly(
          type: OcrAnomalyType.supplier,
          severity: OcrAnomalySeverity.medium,
          message:
              'Invoice structure differs from supplier history: ${currentItems.toStringAsFixed(0)} items vs average ${avgItems.toStringAsFixed(1)}.',
        ),
      );
    }

    return anomalies;
  }
}
