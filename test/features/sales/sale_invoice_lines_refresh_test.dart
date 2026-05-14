import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clothes_inventory/features/accounts/data/accounts_repository.dart';
import 'package:clothes_inventory/features/products/data/product_repository.dart';
import 'package:clothes_inventory/features/products/domain/product.dart';
import 'package:clothes_inventory/features/purchases/data/purchases_repository.dart';
import 'package:clothes_inventory/features/purchases/domain/purchase_models.dart';
import 'package:clothes_inventory/features/sales/data/sales_repository.dart';
import 'package:clothes_inventory/features/sales/domain/sale_models.dart';
import 'package:clothes_inventory/services/database/app_database.dart';
import 'package:clothes_inventory/services/di/service_locator.dart';

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

    await setupServiceLocator();
    accountsRepository = getIt<AccountsRepository>();
    productRepository = getIt<ProductRepository>();
    salesRepository = getIt<SalesRepository>();
    purchasesRepository = getIt<PurchasesRepository>();
  });

  setUp(() async {
    await _clearTestData();
  });

  test(
    'listInvoiceLines reflects returns while preserving sold quantity',
    () async {
      final customerId = await accountsRepository.createAccount(
        name: 'Sale Invoice Lines Customer',
        accountType: 'customer',
      );
      final supplierId = await accountsRepository.createAccount(
        name: 'Sale Invoice Lines Supplier',
        accountType: 'supplier',
      );

      final product = await productRepository.createProduct(
        const Product(
          id: null,
          name: 'Sale Invoice Lines Product',
          unitType: UnitType.piece,
          salePrice: 80,
          purchasePrice: 50,
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
          paidAmount: 500,
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
              quantity: 7,
              unitPrice: product.salePrice,
            ),
          ],
          taxPercentage: 0,
          paidAmount: 560,
          paymentMethod: PaymentMethod.cash,
        ),
      );

      final beforeReturn = await salesRepository.listInvoiceLines(saleId);
      expect(beforeReturn, hasLength(1));
      expect(beforeReturn.first.quantity, 7);
      expect(beforeReturn.first.returnedQuantity, 0);
      expect(beforeReturn.first.remainingQuantity, 7);

      await salesRepository.returnSaleItem(
        saleId: saleId,
        saleItemId: beforeReturn.first.id,
        quantity: 2,
        paymentMethod: PaymentMethod.cash,
      );

      final afterFirstReturn = await salesRepository.listInvoiceLines(saleId);
      expect(afterFirstReturn, hasLength(1));
      expect(afterFirstReturn.first.quantity, 7);
      expect(afterFirstReturn.first.returnedQuantity, 2);
      expect(afterFirstReturn.first.remainingQuantity, 5);

      await salesRepository.returnSaleItem(
        saleId: saleId,
        saleItemId: afterFirstReturn.first.id,
        quantity: 1,
        paymentMethod: PaymentMethod.cash,
      );

      final afterSecondReturn = await salesRepository.listInvoiceLines(saleId);
      expect(afterSecondReturn, hasLength(1));
      expect(afterSecondReturn.first.quantity, 7);
      expect(afterSecondReturn.first.returnedQuantity, 3);
      expect(afterSecondReturn.first.remainingQuantity, 4);
    },
  );

  test('listInvoiceLines remaining quantity never drops below zero', () async {
    final customerId = await accountsRepository.createAccount(
      name: 'No Negative Sale Remaining Customer',
      accountType: 'customer',
    );
    final supplierId = await accountsRepository.createAccount(
      name: 'No Negative Sale Remaining Supplier',
      accountType: 'supplier',
    );

    final product = await productRepository.createProduct(
      const Product(
        id: null,
        name: 'No Negative Sale Remaining Product',
        unitType: UnitType.piece,
        salePrice: 40,
        purchasePrice: 25,
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
            quantity: 5,
            unitPrice: product.purchasePrice,
          ),
        ],
        paidAmount: 125,
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
            quantity: 3,
            unitPrice: product.salePrice,
          ),
        ],
        taxPercentage: 0,
        paidAmount: 120,
        paymentMethod: PaymentMethod.cash,
      ),
    );

    final lines = await salesRepository.listInvoiceLines(saleId);
    final itemId = lines.first.id;

    await salesRepository.returnSaleItem(
      saleId: saleId,
      saleItemId: itemId,
      quantity: 3,
      paymentMethod: PaymentMethod.cash,
    );

    final afterFullReturn = await salesRepository.listInvoiceLines(saleId);
    expect(afterFullReturn.first.remainingQuantity, 0);

    await expectLater(
      salesRepository.returnSaleItem(
        saleId: saleId,
        saleItemId: itemId,
        quantity: 1,
        paymentMethod: PaymentMethod.cash,
      ),
      throwsA(isA<StateError>()),
    );

    final afterRejectedExtraReturn = await salesRepository.listInvoiceLines(
      saleId,
    );
    expect(afterRejectedExtraReturn.first.quantity, 3);
    expect(afterRejectedExtraReturn.first.returnedQuantity, 3);
    expect(afterRejectedExtraReturn.first.remainingQuantity, 0);
  });
}
