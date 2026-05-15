import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clothes_inventory/features/accounts/data/accounts_repository.dart';
import 'package:clothes_inventory/features/auth/domain/auth_user.dart';
import 'package:clothes_inventory/features/products/data/product_repository.dart';
import 'package:clothes_inventory/features/products/domain/product.dart';
import 'package:clothes_inventory/features/purchases/data/purchases_repository.dart';
import 'package:clothes_inventory/features/purchases/domain/purchase_models.dart';
import 'package:clothes_inventory/features/sales/data/sales_repository.dart';
import 'package:clothes_inventory/features/sales/domain/sale_models.dart';
import 'package:clothes_inventory/services/auth/session_service.dart';
import 'package:clothes_inventory/services/database/app_database.dart';
import 'package:clothes_inventory/services/di/service_locator.dart';

import '../../support/test_app_isolation.dart';

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
  await db.delete('products');
  await db.delete('accounts');
  await db.delete('categories');
}

void main() {
  late AccountsRepository accountsRepository;
  late ProductRepository productRepository;
  late SalesRepository salesRepository;
  late PurchasesRepository purchasesRepository;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          if (methodCall.method == 'getApplicationSupportDirectory') {
            final dir = await Directory.systemTemp.createTemp(
              'inventory_test_',
            );
            return dir.path;
          }
          return null;
        });
    await TestAppIsolation.bootstrap();
    accountsRepository = getIt<AccountsRepository>();
    productRepository = getIt<ProductRepository>();
    salesRepository = getIt<SalesRepository>();
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

  test('cancelSale is rejected when sale has returns', () async {
    final customerId = await accountsRepository.createAccount(
      name: 'Test Customer',
      accountType: 'customer',
    );
    final supplierId = await accountsRepository.createAccount(
      name: 'Seed Supplier',
      accountType: 'supplier',
    );
    final product = await productRepository.createProduct(
      const Product(
        id: null,
        name: 'Sale Product',
        unitType: UnitType.piece,
        salePrice: 100,
        purchasePrice: 70,
        lowStockThreshold: 0,
      ),
    );

    await purchasesRepository.createPurchase(
      PurchaseCreateRequest(
        supplierId: supplierId,
        items: [
          PurchaseDraftItem(
            productId: product.id!,
            productName: product.name,
            unitType: product.unitType.name,
            quantity: 10,
            unitPrice: product.purchasePrice,
          ),
        ],
        paidAmount: 700,
        paymentMethod: PaymentMethod.cash,
      ),
    );

    final saleId = await salesRepository.createSale(
      SaleCreateRequest(
        customerId: customerId,
        items: [
          SaleDraftItem(
            productId: product.id!,
            productName: product.name,
            unitType: product.unitType.name,
            availableStock: 999999,
            minUnitPrice: product.purchasePrice,
            quantity: 5,
            unitPrice: product.salePrice,
          ),
        ],
        paidAmount: 500,
        paymentMethod: PaymentMethod.cash,
      ),
    );

    final lines = await salesRepository.listInvoiceLines(saleId);
    await salesRepository.returnSaleItem(
      saleId: saleId,
      saleItemId: lines.first.id,
      quantity: 1,
      paymentMethod: PaymentMethod.cash,
    );

    expect(
      () => salesRepository.cancelSale(saleId),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Cannot cancel sale with returns'),
        ),
      ),
    );
  });

  test('cancelPurchase is rejected when purchase has returns', () async {
    final supplierId = await accountsRepository.createAccount(
      name: 'Test Supplier',
      accountType: 'supplier',
    );
    final product = await productRepository.createProduct(
      const Product(
        id: null,
        name: 'Purchase Product',
        unitType: UnitType.piece,
        salePrice: 100,
        purchasePrice: 70,
        lowStockThreshold: 0,
      ),
    );

    final purchaseId = await purchasesRepository.createPurchase(
      PurchaseCreateRequest(
        supplierId: supplierId,
        items: [
          PurchaseDraftItem(
            productId: product.id!,
            productName: product.name,
            unitType: product.unitType.name,
            quantity: 5,
            unitPrice: product.purchasePrice,
          ),
        ],
        paidAmount: 350,
        paymentMethod: PaymentMethod.cash,
      ),
    );

    final lines = await purchasesRepository.listInvoiceLines(purchaseId);
    await purchasesRepository.returnPurchaseItem(
      purchaseId: purchaseId,
      purchaseItemId: lines.first.id,
      quantity: 1,
    );

    expect(
      () => purchasesRepository.cancelPurchase(purchaseId),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Cannot cancel purchase with returns'),
        ),
      ),
    );
  });
}
