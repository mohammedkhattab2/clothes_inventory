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
  late AppDatabase appDatabase;
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
    appDatabase = getIt<AppDatabase>();
    accountsRepository = getIt<AccountsRepository>();
    productRepository = getIt<ProductRepository>();
    salesRepository = getIt<SalesRepository>();
    purchasesRepository = getIt<PurchasesRepository>();
  });

  setUp(() async {
    await _clearTestData();
  });

  test(
    'sale partial return keeps stock/ledger invariant and blocks cancel',
    () async {
      final customerId = await accountsRepository.createAccount(
        name: 'Invariant Customer',
        accountType: 'customer',
      );
      final supplierId = await accountsRepository.createAccount(
        name: 'Invariant Seed Supplier',
        accountType: 'supplier',
      );
      final product = await productRepository.createProduct(
        const Product(
          id: null,
          name: 'Invariant Sale Product',
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
          taxPercentage: 0,
          paidAmount: 500,
          paymentMethod: PaymentMethod.cash,
        ),
      );

      final saleLines = await salesRepository.listInvoiceLines(saleId);
      await salesRepository.returnSaleItem(
        saleId: saleId,
        saleItemId: saleLines.first.id,
        quantity: 1,
        paymentMethod: PaymentMethod.cash,
      );

      final stockAfterReturn = await productRepository.getCurrentStock(
        product.id!,
      );
      final customerBalance = await accountsRepository.getAccountBalance(
        customerId,
      );

      expect(stockAfterReturn, 6);
      expect(customerBalance, 0);

      await expectLater(
        salesRepository.cancelSale(saleId),
        throwsA(isA<StateError>()),
      );

      final db = await appDatabase.database;
      final saleStatusRow = await db.query(
        'sales',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [saleId],
        limit: 1,
      );
      final cancellationLedgerRows = await db.query(
        'ledger_transactions',
        where: 'source_type = ? AND source_id = ?',
        whereArgs: ['cancellation', saleId],
      );

      expect(saleStatusRow.first['status'], 'completed');
      expect(cancellationLedgerRows, isEmpty);
    },
  );

  test(
    'purchase partial return keeps stock/ledger invariant and blocks cancel',
    () async {
      final supplierId = await accountsRepository.createAccount(
        name: 'Invariant Supplier',
        accountType: 'supplier',
      );
      final product = await productRepository.createProduct(
        const Product(
          id: null,
          name: 'Invariant Purchase Product',
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

      final purchaseLines = await purchasesRepository.listInvoiceLines(
        purchaseId,
      );
      await purchasesRepository.returnPurchaseItem(
        purchaseId: purchaseId,
        purchaseItemId: purchaseLines.first.id,
        quantity: 1,
      );

      final stockAfterReturn = await productRepository.getCurrentStock(
        product.id!,
      );
      final supplierBalance = await accountsRepository.getAccountBalance(
        supplierId,
      );

      expect(stockAfterReturn, 4);
      expect(supplierBalance, -70);

      await expectLater(
        purchasesRepository.cancelPurchase(purchaseId),
        throwsA(isA<StateError>()),
      );

      final db = await appDatabase.database;
      final purchaseStatusRow = await db.query(
        'purchases',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [purchaseId],
        limit: 1,
      );
      final cancellationLedgerRows = await db.query(
        'ledger_transactions',
        where: 'source_type = ? AND source_id = ?',
        whereArgs: ['cancellation', purchaseId],
      );

      expect(purchaseStatusRow.first['status'], 'completed');
      expect(cancellationLedgerRows, isEmpty);
    },
  );
}
