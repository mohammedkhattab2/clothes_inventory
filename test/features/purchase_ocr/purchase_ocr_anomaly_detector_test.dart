import 'package:flutter_test/flutter_test.dart';
import 'package:delta_erp/features/purchase_ocr/domain/purchase_ocr_anomaly_detector.dart';
import 'package:delta_erp/features/purchase_ocr/domain/purchase_ocr_models.dart';

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
  late _FakeHistoryProvider history;
  late PurchaseOcrAnomalyDetector detector;

  setUp(() {
    history = _FakeHistoryProvider();
    detector = PurchaseOcrAnomalyDetector(historyProvider: history);
  });

  test('detects price deviation anomaly', () async {
    history.avgPriceByProduct[1] = 100;

    final draft = PurchaseOcrDraft(
      rawText: 'raw',
      normalizedText: 'norm',
      imagePath: 'x.png',
      totalAmount: 160,
      items: const [
        PurchaseOcrLineItemDraft(
          productName: 'Steel Wire',
          quantity: 1,
          unitPrice: 150,
          matchedProductId: 1,
        ),
      ],
    );

    final anomalies = await detector.detect(draft);
    expect(
      anomalies.where((a) => a.type == OcrAnomalyType.price).isNotEmpty,
      isTrue,
    );
  });

  test('detects missing total structural anomaly', () async {
    final draft = PurchaseOcrDraft(
      rawText: 'raw',
      normalizedText: 'norm',
      imagePath: 'x.png',
      items: const [
        PurchaseOcrLineItemDraft(
          productName: 'A',
          quantity: 1,
          unitPrice: 50,
        ),
      ],
    );

    final anomalies = await detector.detect(draft);
    expect(
      anomalies.any((a) => a.type == OcrAnomalyType.structural),
      isTrue,
    );
  });

  test('detects new supplier anomaly', () async {
    history.invoiceCountBySupplier[77] = 0;

    final draft = PurchaseOcrDraft(
      rawText: 'raw',
      normalizedText: 'norm',
      imagePath: 'x.png',
      supplierId: 77,
      supplierName: 'New Supplier',
      totalAmount: 10,
      items: const [
        PurchaseOcrLineItemDraft(
          productName: 'A',
          quantity: 1,
          unitPrice: 10,
        ),
      ],
    );

    final anomalies = await detector.detect(draft);
    expect(
      anomalies.any((a) => a.type == OcrAnomalyType.supplier),
      isTrue,
    );
  });

  test('returns no anomalies for clean invoice', () async {
    history.avgPriceByProduct[1] = 100;
    history.invoiceCountBySupplier[5] = 4;
    history.avgItemsBySupplier[5] = 2;

    final draft = PurchaseOcrDraft(
      rawText: 'raw',
      normalizedText: 'norm',
      imagePath: 'x.png',
      supplierId: 5,
      supplierName: 'Trusted',
      totalAmount: 200,
      items: const [
        PurchaseOcrLineItemDraft(
          productName: 'Steel Wire',
          quantity: 2,
          unitPrice: 100,
          matchedProductId: 1,
        ),
      ],
    );

    final anomalies = await detector.detect(draft);
    expect(anomalies, isEmpty);
  });
}
