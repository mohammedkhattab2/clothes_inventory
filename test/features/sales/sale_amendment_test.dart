import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delta_erp/features/accounts/data/accounts_repository.dart';
import 'package:delta_erp/features/auth/domain/auth_user.dart';
import 'package:delta_erp/features/inventory/data/inventory_repository.dart';
import 'package:delta_erp/features/products/data/product_repository.dart';
import 'package:delta_erp/features/products/domain/product.dart';
import 'package:delta_erp/features/purchases/data/purchases_repository.dart';
import 'package:delta_erp/features/purchases/domain/purchase_models.dart';
import 'package:delta_erp/features/sales/data/sales_repository.dart';
import 'package:delta_erp/features/sales/domain/sale_models.dart';
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
  late AppDatabase appDatabase;
  late AccountsRepository accountsRepository;
  late InventoryRepository inventoryRepository;
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
    inventoryRepository = getIt<InventoryRepository>();
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
        items: [draft.items.single.copyWith(quantity: 4)],
        headerDiscountKind: draft.headerDiscountKind,
        headerDiscountValue: draft.headerDiscountValue,
        paymentMethod: PaymentMethod.cash,
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
    final inventoryRows = await inventoryRepository.getCurrentStockRows();
    final inventoryRow = inventoryRows.singleWhere(
      (row) => row.productId == product.id,
    );
    expect(inventoryRow.currentStock, 6);

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
      where: 'source_type = ? AND source_id = ? AND entry_kind = ?',
      whereArgs: ['sale', saleId, 'debit'],
    );
    expect(ledgerRows, hasLength(1));
    expect((ledgerRows.single['amount'] as num).toDouble(), 400);
  });

  test('load and amend remain available after sale returns', () async {
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

    final draft = await salesRepository.loadSaleDraftForAmendment(saleId);
    expect(draft.items, isNotEmpty);

    await salesRepository.amendSale(
      SaleAmendRequest(
        saleId: saleId,
        items: [draft.items.single.copyWith(quantity: 3)],
        headerDiscountKind: draft.headerDiscountKind,
        headerDiscountValue: draft.headerDiscountValue,
        paymentMethod: PaymentMethod.cash,
      ),
    );

    final db = await appDatabase.database;
    final saleRows = await db.query(
      'sales',
      columns: ['total_amount', 'status'],
      where: 'id = ?',
      whereArgs: [saleId],
      limit: 1,
    );
    expect((saleRows.single['total_amount'] as num).toDouble(), 100);
    expect(saleRows.single['status'], 'completed');
  });

  test(
    'amendSale positive delta with defer keeps increase as outstanding',
    () async {
      final customerId = await accountsRepository.createAccount(
        name: 'Amend Defer Customer',
        accountType: 'customer',
      );
      final supplierId = await accountsRepository.createAccount(
        name: 'Amend Defer Supplier',
        accountType: 'supplier',
      );
      final product = await productRepository.createProduct(
        const Product(
          id: null,
          name: 'Amend Defer Product',
          unitType: UnitType.piece,
          salePrice: 100,
          purchasePrice: 30,
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
              quantity: 20,
              unitPrice: product.purchasePrice,
            ),
          ],
          paidAmount: 600,
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

      await salesRepository.amendSale(
        SaleAmendRequest(
          saleId: saleId,
          items: [draft.items.single.copyWith(quantity: 6)],
          headerDiscountKind: draft.headerDiscountKind,
          headerDiscountValue: draft.headerDiscountValue,
          paymentMethod: PaymentMethod.cash,
          positiveAmendmentHandling: PositiveAmendmentHandling.defer,
        ),
      );

      final db = await appDatabase.database;
      final saleRows = await db.query(
        'sales',
        columns: ['total_amount', 'status'],
        where: 'id = ?',
        whereArgs: [saleId],
      );
      expect((saleRows.single['total_amount'] as num).toDouble(), 600);
      expect(saleRows.single['status'], 'partial');

      final paidRows = await db.rawQuery(
        '''
      SELECT COALESCE(SUM(amount), 0) AS paid
      FROM payments
      WHERE invoice_type = 'sale'
        AND invoice_id = ?
        AND reversal_for_id IS NULL
      ''',
        [saleId],
      );
      expect((paidRows.first['paid'] as num).toDouble(), 500);
    },
  );

  test(
    'amendSale positive delta with partial cash collection stays partial',
    () async {
      final customerId = await accountsRepository.createAccount(
        name: 'Amend Partial Customer',
        accountType: 'customer',
      );
      final supplierId = await accountsRepository.createAccount(
        name: 'Amend Partial Supplier',
        accountType: 'supplier',
      );
      final product = await productRepository.createProduct(
        const Product(
          id: null,
          name: 'Amend Partial Product',
          unitType: UnitType.piece,
          salePrice: 100,
          purchasePrice: 30,
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
              quantity: 20,
              unitPrice: product.purchasePrice,
            ),
          ],
          paidAmount: 600,
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

      await salesRepository.amendSale(
        SaleAmendRequest(
          saleId: saleId,
          items: [draft.items.single.copyWith(quantity: 6)],
          headerDiscountKind: draft.headerDiscountKind,
          headerDiscountValue: draft.headerDiscountValue,
          paymentMethod: PaymentMethod.cash,
          positiveAmendmentHandling: PositiveAmendmentHandling.collectNow,
          collectPaymentMethod: PaymentMethod.cash,
          collectAmount: 40,
        ),
      );

      final db = await appDatabase.database;
      final saleRows = await db.query(
        'sales',
        columns: ['total_amount', 'status'],
        where: 'id = ?',
        whereArgs: [saleId],
      );
      expect((saleRows.single['total_amount'] as num).toDouble(), 600);
      expect(saleRows.single['status'], 'partial');

      final paidRows = await db.rawQuery(
        '''
      SELECT COALESCE(SUM(amount), 0) AS paid
      FROM payments
      WHERE invoice_type = 'sale'
        AND invoice_id = ?
        AND reversal_for_id IS NULL
      ''',
        [saleId],
      );
      expect((paidRows.first['paid'] as num).toDouble(), 540);
    },
  );

  test(
    'amendSale positive delta with split collection can complete invoice',
    () async {
      final customerId = await accountsRepository.createAccount(
        name: 'Amend Split Customer',
        accountType: 'customer',
      );
      final supplierId = await accountsRepository.createAccount(
        name: 'Amend Split Supplier',
        accountType: 'supplier',
      );
      final product = await productRepository.createProduct(
        const Product(
          id: null,
          name: 'Amend Split Product',
          unitType: UnitType.piece,
          salePrice: 100,
          purchasePrice: 30,
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
              quantity: 20,
              unitPrice: product.purchasePrice,
            ),
          ],
          paidAmount: 600,
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

      await salesRepository.amendSale(
        SaleAmendRequest(
          saleId: saleId,
          items: [draft.items.single.copyWith(quantity: 6)],
          headerDiscountKind: draft.headerDiscountKind,
          headerDiscountValue: draft.headerDiscountValue,
          paymentMethod: PaymentMethod.cash,
          positiveAmendmentHandling: PositiveAmendmentHandling.collectNow,
          collectPaymentMethod: PaymentMethod.cashAndWallet,
          collectAmount: 100,
          collectWalletAmount: 30,
        ),
      );

      final db = await appDatabase.database;
      final saleRows = await db.query(
        'sales',
        columns: ['total_amount', 'status'],
        where: 'id = ?',
        whereArgs: [saleId],
      );
      expect((saleRows.single['total_amount'] as num).toDouble(), 600);
      expect(saleRows.single['status'], 'completed');

      final paidRows = await db.rawQuery(
        '''
      SELECT COALESCE(SUM(amount), 0) AS paid
      FROM payments
      WHERE invoice_type = 'sale'
        AND invoice_id = ?
        AND reversal_for_id IS NULL
      ''',
        [saleId],
      );
      expect((paidRows.first['paid'] as num).toDouble(), 600);

      final splitRows = await db.rawQuery(
        '''
      SELECT payment_method, amount
      FROM payments
      WHERE invoice_type = 'sale'
        AND invoice_id = ?
        AND reversal_for_id IS NULL
      ORDER BY id ASC
      ''',
        [saleId],
      );
      final cashAmounts = splitRows
          .where((r) => r['payment_method'] == 'cash')
          .map((r) => (r['amount'] as num).toDouble())
          .toList(growable: false);
      final walletAmounts = splitRows
          .where((r) => r['payment_method'] == 'vodafone_cash')
          .map((r) => (r['amount'] as num).toDouble())
          .toList(growable: false);

      expect(cashAmounts, contains(70));
      expect(walletAmounts, contains(30));
    },
  );

  test('previewAmendRefund exposes positive delta and outstanding', () async {
    final customerId = await accountsRepository.createAccount(
      name: 'Preview Delta Customer',
      accountType: 'customer',
    );
    final supplierId = await accountsRepository.createAccount(
      name: 'Preview Delta Supplier',
      accountType: 'supplier',
    );
    final product = await productRepository.createProduct(
      const Product(
        id: null,
        name: 'Preview Delta Product',
        unitType: UnitType.piece,
        salePrice: 100,
        purchasePrice: 30,
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
            quantity: 20,
            unitPrice: product.purchasePrice,
          ),
        ],
        paidAmount: 600,
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
    final preview = await salesRepository.previewAmendRefund(
      SaleAmendRequest(
        saleId: saleId,
        items: [draft.items.single.copyWith(quantity: 6)],
        headerDiscountKind: draft.headerDiscountKind,
        headerDiscountValue: draft.headerDiscountValue,
        paymentMethod: PaymentMethod.cash,
      ),
    );

    expect(preview.oldTotalAmount, 500);
    expect(preview.newTotalAmount, 600);
    expect(preview.totalDelta, 100);
    expect(preview.positiveDelta, 100);
    expect(preview.outstandingAfterAmend, 100);
    expect(preview.maxRefundable, 0);
  });

  test('amendSale rejects collect amount above positive delta', () async {
    final customerId = await accountsRepository.createAccount(
      name: 'Collect Limit Customer',
      accountType: 'customer',
    );
    final supplierId = await accountsRepository.createAccount(
      name: 'Collect Limit Supplier',
      accountType: 'supplier',
    );
    final product = await productRepository.createProduct(
      const Product(
        id: null,
        name: 'Collect Limit Product',
        unitType: UnitType.piece,
        salePrice: 100,
        purchasePrice: 30,
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
            quantity: 20,
            unitPrice: product.purchasePrice,
          ),
        ],
        paidAmount: 600,
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

    await expectLater(
      salesRepository.amendSale(
        SaleAmendRequest(
          saleId: saleId,
          items: [draft.items.single.copyWith(quantity: 6)],
          headerDiscountKind: draft.headerDiscountKind,
          headerDiscountValue: draft.headerDiscountValue,
          paymentMethod: PaymentMethod.cash,
          positiveAmendmentHandling: PositiveAmendmentHandling.collectNow,
          collectPaymentMethod: PaymentMethod.cash,
          collectAmount: 150,
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });
}
