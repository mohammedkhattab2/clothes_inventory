import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clothes_inventory/features/accounts/data/accounts_repository.dart';
import 'package:clothes_inventory/features/auth/domain/auth_user.dart';
import 'package:clothes_inventory/features/products/data/product_repository.dart';
import 'package:clothes_inventory/features/products/domain/product.dart';
import 'package:clothes_inventory/features/purchase_ocr/data/purchase_ocr_service.dart';
import 'package:clothes_inventory/features/purchase_ocr/domain/purchase_ocr_anomaly_detector.dart';
import 'package:clothes_inventory/features/purchase_ocr/domain/purchase_invoice_parser.dart';
import 'package:clothes_inventory/features/purchase_ocr/domain/purchase_ocr_product_matcher.dart';
import 'package:clothes_inventory/features/purchase_ocr/presentation/purchase_ocr_cubit.dart';
import 'package:clothes_inventory/features/purchases/data/purchases_repository.dart';
import 'package:clothes_inventory/services/auth/session_service.dart';
import 'package:clothes_inventory/services/database/app_database.dart';
import 'package:clothes_inventory/services/di/service_locator.dart';

import '../../support/test_app_isolation.dart';

class _FakePurchaseOcrService implements PurchaseOcrService {
  const _FakePurchaseOcrService(this.text);

  final String text;

  @override
  Future<String> extractText({required String imagePath}) async => text;

  @override
  Map<String, bool> debugHealthCheck() => const {
    'tesseract_exists': true,
    'tessdata_exists': true,
    'eng_traineddata': true,
    'ara_traineddata': true,
  };

  @override
  Future<String> getTesseractVersion() async => 'fake-tesseract 0.0.0';

  @override
  OcrFailure? getLastFailure() => null;

  @override
  void markFingerprintResolved(String fingerprint) {}

  @override
  String getFingerprintResolutionStatus(String fingerprint) => 'unresolved';

  @override
  String getLastFailureResolutionStatus() => 'unresolved';

  @override
  void resetFingerprintCount(String fingerprint) {}

  @override
  Map<String, int> getFingerprintOccurrenceSnapshot() => const {};

  @override
  Map<String, bool> getFingerprintResolutionSnapshot() => const {};

  @override
  Map<String, OcrFailure> getFingerprintLastFailureSnapshot() => const {};
}

class _NoopMappingsStore implements OcrProductMappingsStore {
  @override
  Future<LearnedProductMapping?> findPreferredMapping(
    String normalizedOcrText,
  ) async => null;

  @override
  Future<void> saveOrIncrementMapping({
    required String normalizedOcrText,
    required int productId,
  }) async {}
}

class _NoopAnomalyHistoryProvider implements PurchaseOcrAnomalyHistoryProvider {
  @override
  Future<double?> averageProductUnitPrice(int productId) async => null;

  @override
  Future<int> supplierInvoiceCount(int supplierId) async => 0;

  @override
  Future<double?> supplierAverageItemsPerInvoice(int supplierId) async => null;
}

Future<void> _clearTestData() async {
  final db = await getIt<AppDatabase>().database;
  await db.delete('returns');
  await db.delete('payments');
  await db.delete('ledger_transactions');
  await db.delete('stock_movements');
  await db.delete('sale_items');
  await db.delete('purchase_items');
  await db.delete('sales');
  await db.delete('purchases');
  await db.delete('ocr_product_mappings');
  await db.delete('products');
  await db.delete('accounts');
  await db.delete('categories');
}

void main() {
  late AccountsRepository accountsRepository;
  late ProductRepository productRepository;
  late PurchasesRepository purchasesRepository;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          if (methodCall.method == 'getApplicationSupportDirectory') {
            final dir = await Directory.systemTemp.createTemp(
              'purchase_ocr_test_',
            );
            return dir.path;
          }
          return null;
        });

    await TestAppIsolation.bootstrap();
    accountsRepository = getIt<AccountsRepository>();
    productRepository = getIt<ProductRepository>();
    purchasesRepository = getIt<PurchasesRepository>();
  });

  tearDownAll(() async {
    await TestAppIsolation.shutdown();
  });

  setUp(() async {
    await _clearTestData();
    getIt<SessionService>().login(
      const AuthUser(
        id: 1,
        username: 'owner',
        fullName: 'Owner',
        role: UserRole.owner,
        isActive: true,
      ),
    );
  });

  tearDown(() {
    getIt<SessionService>().logout();
  });

  test('process image then save creates purchase and side effects', () async {
    final supplierId = await accountsRepository.createAccount(
      name: 'Raw Supplier',
      accountType: 'supplier',
    );

    final existingProduct = await productRepository.createProduct(
      const Product(
        id: null,
        name: 'Steel Wire',
        unitType: UnitType.piece,
        salePrice: 20,
        purchasePrice: 15,
        lowStockThreshold: 0,
      ),
    );

    final cubit = PurchaseOcrCubit(
      ocrService: const _FakePurchaseOcrService('''
Supplier: Raw Supplier
Date: 2026-04-10
Steel Wire 2 x 15
Copper Tube 3 12
Grand Total: 66
'''),
      parser: const PurchaseInvoiceParser(),
      matcher: PurchaseOcrProductMatcher(mappingsStore: _NoopMappingsStore()),
      anomalyDetector: PurchaseOcrAnomalyDetector(
        historyProvider: _NoopAnomalyHistoryProvider(),
      ),
      accountsRepository: accountsRepository,
      productRepository: productRepository,
      purchasesRepository: purchasesRepository,
    );

    await cubit.processImage('fake.png');

    expect(cubit.state.status, PurchaseOcrStatus.ready);
    expect(cubit.state.draft, isNotNull);
    expect(cubit.state.draft!.supplierId, supplierId);
    expect(cubit.state.draft!.items, hasLength(2));
    expect(cubit.state.draft!.items.first.matchedProductId, existingProduct.id);
    expect(cubit.state.draft!.items.first.suggestedProducts, isNotEmpty);
    expect(
      cubit.state.draft!.items.first.suggestedProducts.first.productId,
      existingProduct.id,
    );
    expect(
      cubit.state.draft!.items.first.suggestedProducts.first.matchScore,
      inInclusiveRange(0.0, 1.0),
    );

    await cubit.savePurchaseInvoice();

    expect(cubit.state.status, PurchaseOcrStatus.success);
    final invoiceId = cubit.state.successInvoiceId;
    expect(invoiceId, isNotNull);

    final lines = await purchasesRepository.listInvoiceLines(invoiceId!);
    expect(lines, hasLength(2));

    final stockAfter = await productRepository.getCurrentStock(
      existingProduct.id!,
    );
    expect(stockAfter, 2);

    final productsByName = await productRepository.listProducts(
      nameQuery: 'Copper Tube',
    );
    expect(productsByName, isNotEmpty);

    final db = await getIt<AppDatabase>().database;
    final paymentRows = await db.query(
      'payments',
      where: 'invoice_type = ? AND invoice_id = ?',
      whereArgs: ['purchase', invoiceId],
    );
    final purchaseLedgerRows = await db.query(
      'ledger_transactions',
      where: 'source_type = ? AND source_id = ?',
      whereArgs: ['purchase', invoiceId],
    );

    expect(paymentRows, isNotEmpty);
    expect(purchaseLedgerRows, isNotEmpty);

    await cubit.close();
  });
}
