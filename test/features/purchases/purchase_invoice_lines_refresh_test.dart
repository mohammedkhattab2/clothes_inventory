import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delta_erp/features/accounts/data/accounts_repository.dart';
import 'package:delta_erp/features/auth/domain/auth_user.dart';
import 'package:delta_erp/features/products/data/product_repository.dart';
import 'package:delta_erp/features/products/domain/product.dart';
import 'package:delta_erp/features/purchases/data/purchases_repository.dart';
import 'package:delta_erp/features/purchases/domain/purchase_models.dart';
import 'package:delta_erp/services/auth/session_service.dart';
import 'package:delta_erp/services/database/app_database.dart';
import 'package:delta_erp/services/di/service_locator.dart';

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

  test(
    'listInvoiceLines reflects returns while preserving purchased quantity',
    () async {
      final supplierId = await accountsRepository.createAccount(
        name: 'Invoice Lines Supplier',
        accountType: 'supplier',
      );
      final product = await productRepository.createProduct(
        const Product(
          id: null,
          name: 'Invoice Lines Product',
          unitType: UnitType.piece,
          salePrice: 50,
          purchasePrice: 30,
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
              quantity: 7,
              unitPrice: product.purchasePrice,
            ),
          ],
          paidAmount: 210,
          paymentMethod: PaymentMethod.cash,
        ),
      );

      final beforeReturn = await purchasesRepository.listInvoiceLines(
        purchaseId,
      );
      expect(beforeReturn, hasLength(1));
      expect(beforeReturn.first.quantity, 7);
      expect(beforeReturn.first.returnedQuantity, 0);
      expect(beforeReturn.first.remainingQuantity, 7);

      await purchasesRepository.returnPurchaseItem(
        purchaseId: purchaseId,
        purchaseItemId: beforeReturn.first.id,
        quantity: 2,
      );

      final afterFirstReturn = await purchasesRepository.listInvoiceLines(
        purchaseId,
      );
      expect(afterFirstReturn, hasLength(1));
      expect(afterFirstReturn.first.quantity, 7);
      expect(afterFirstReturn.first.returnedQuantity, 2);
      expect(afterFirstReturn.first.remainingQuantity, 5);

      await purchasesRepository.returnPurchaseItem(
        purchaseId: purchaseId,
        purchaseItemId: afterFirstReturn.first.id,
        quantity: 1,
      );

      final afterSecondReturn = await purchasesRepository.listInvoiceLines(
        purchaseId,
      );
      expect(afterSecondReturn, hasLength(1));
      expect(afterSecondReturn.first.quantity, 7);
      expect(afterSecondReturn.first.returnedQuantity, 3);
      expect(afterSecondReturn.first.remainingQuantity, 4);
    },
  );

  test('listInvoiceLines remaining quantity never drops below zero', () async {
    final supplierId = await accountsRepository.createAccount(
      name: 'No Negative Remaining Supplier',
      accountType: 'supplier',
    );
    final product = await productRepository.createProduct(
      const Product(
        id: null,
        name: 'No Negative Remaining Product',
        unitType: UnitType.piece,
        salePrice: 20,
        purchasePrice: 10,
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
            quantity: 3,
            unitPrice: product.purchasePrice,
          ),
        ],
        paidAmount: 30,
        paymentMethod: PaymentMethod.cash,
      ),
    );

    final lines = await purchasesRepository.listInvoiceLines(purchaseId);
    final itemId = lines.first.id;

    await purchasesRepository.returnPurchaseItem(
      purchaseId: purchaseId,
      purchaseItemId: itemId,
      quantity: 3,
    );

    final afterFullReturn = await purchasesRepository.listInvoiceLines(
      purchaseId,
    );
    expect(afterFullReturn.first.remainingQuantity, 0);

    await expectLater(
      purchasesRepository.returnPurchaseItem(
        purchaseId: purchaseId,
        purchaseItemId: itemId,
        quantity: 1,
      ),
      throwsA(isA<StateError>()),
    );

    final afterRejectedExtraReturn = await purchasesRepository.listInvoiceLines(
      purchaseId,
    );
    expect(afterRejectedExtraReturn.first.quantity, 3);
    expect(afterRejectedExtraReturn.first.returnedQuantity, 3);
    expect(afterRejectedExtraReturn.first.remainingQuantity, 0);
  });
}
