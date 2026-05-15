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
              'sale_amend_test_',
            );
            return dir.path;
          }
          return null;
        });

    await TestAppIsolation.bootstrap();
    appDatabase = getIt<AppDatabase>();
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

  test('amendSale replaces lines, stock, totals, and ledger debit', () async {
    final customerId = await accountsRepository.createAccount(
      name: 'Amend Customer',
      accountType: 'customer',
    );
    final supplierId = await accountsRepository.createAccount(
      name: 'Amend Supplier',
      accountType: 'supplier',
    );
    final product = await productRepository.createProduct(
      const Product(
        id: null,
        name: 'Amend Product',
        unitType: UnitType.piece,
        salePrice: 100,
        purchasePrice: 40,
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
        paidAmount: 400,
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

    final draft = await salesRepository.loadSaleDraftForAmendment(saleId);
    expect(draft.amendmentPayments, isNotNull);
    expect(draft.items, hasLength(1));
    expect(draft.items.single.quantity, 5);

    await salesRepository.amendSale(
      SaleAmendRequest(
        saleId: saleId,
        items: [
          draft.items.single.copyWith(quantity: 4),
        ],
        headerDiscountKind: draft.headerDiscountKind,
        headerDiscountValue: draft.headerDiscountValue,
      ),
    );

    final db = await appDatabase.database;
    final itemRows = await db.query(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [saleId],
    );
    expect(itemRows, hasLength(1));
    expect((itemRows.single['quantity'] as num).toInt(), 4);

    final outs = await db.query(
      'stock_movements',
      where: 'invoice_type = ? AND invoice_id = ? AND movement_type = ?',
      whereArgs: ['sale', saleId, 'out'],
    );
    expect(outs, hasLength(1));
    expect((outs.single['quantity'] as num).toInt(), 4);

    expect(await productRepository.getCurrentStock(product.id!), 6);

    final saleRows = await db.query(
      'sales',
      columns: ['total_amount', 'status'],
      where: 'id = ?',
      whereArgs: [saleId],
    );
    expect((saleRows.single['total_amount'] as num).toDouble(), 400);
    expect(saleRows.single['status'], 'completed');

    final ledgerRows = await db.query(
      'ledger_transactions',
      columns: ['amount'],
      where:
          'source_type = ? AND source_id = ? AND entry_kind = ?',
      whereArgs: ['sale', saleId, 'debit'],
    );
    expect(ledgerRows, hasLength(1));
    expect((ledgerRows.single['amount'] as num).toDouble(), 400);
  });

  test('load and amend blocked when sale has returns', () async {
    final customerId = await accountsRepository.createAccount(
      name: 'Return Amend Customer',
      accountType: 'customer',
    );
    final supplierId = await accountsRepository.createAccount(
      name: 'Return Amend Supplier',
      accountType: 'supplier',
    );
    final product = await productRepository.createProduct(
      const Product(
        id: null,
        name: 'Return Amend Product',
        unitType: UnitType.piece,
        salePrice: 50,
        purchasePrice: 20,
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
        paidAmount: 100,
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
            quantity: 4,
            unitPrice: product.salePrice,
          ),
        ],
        paidAmount: 200,
        paymentMethod: PaymentMethod.cash,
      ),
    );

    final linesBefore = await salesRepository.listInvoiceLines(saleId);
    await salesRepository.returnSaleItem(
      saleId: saleId,
      saleItemId: linesBefore.single.id,
      quantity: 1,
      paymentMethod: PaymentMethod.cash,
    );

    await expectLater(
      salesRepository.loadSaleDraftForAmendment(saleId),
      throwsA(isA<StateError>()),
    );

    await expectLater(
      salesRepository.amendSale(
        SaleAmendRequest(
          saleId: saleId,
          items: [
            SaleDraftItem(
              productId: product.id!,
              productName: product.name,
              unitType: product.unitType.name,
              availableStock: 999,
              minUnitPrice: product.purchasePrice,
              quantity: 3,
              unitPrice: product.salePrice,
            ),
          ],
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });
}