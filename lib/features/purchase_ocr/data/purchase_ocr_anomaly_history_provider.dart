import 'package:delta_erp/features/purchase_ocr/domain/purchase_ocr_anomaly_detector.dart';
import 'package:delta_erp/features/purchases/data/purchases_repository.dart';

class PurchasesOcrAnomalyHistoryProvider
    implements PurchaseOcrAnomalyHistoryProvider {
  const PurchasesOcrAnomalyHistoryProvider(this._purchasesRepository);

  final PurchasesRepository _purchasesRepository;

  @override
  Future<double?> averageProductUnitPrice(int productId) {
    return _purchasesRepository.averagePurchasedUnitPrice(productId);
  }

  @override
  Future<int> supplierInvoiceCount(int supplierId) {
    return _purchasesRepository.supplierInvoiceCount(supplierId);
  }

  @override
  Future<double?> supplierAverageItemsPerInvoice(int supplierId) {
    return _purchasesRepository.supplierAverageItemsPerInvoice(supplierId);
  }
}
