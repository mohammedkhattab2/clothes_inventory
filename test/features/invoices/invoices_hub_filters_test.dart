import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delta_erp/features/accounts/data/accounts_repository.dart';
import 'package:delta_erp/features/auth/domain/auth_user.dart';
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
  late ProductRepository productRepository;
  late AccountsRepository accountsRepository;
  late PurchasesRepository purchasesRepository;
  late SalesRepository salesRepository;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          if (methodCall.method == 'getApplicationSupportDirectory') {
            final dir = await Directory.systemTemp.createTemp(
              'invoice_filters_test_',
            );
            return dir.path;
          }
          return null;
        });

    await TestAppIsolation.bootstrap();
    productRepository = getIt<ProductRepository>();
    accountsRepository = getIt<AccountsRepository>();
    purchasesRepository = getIt<PurchasesRepository>();
    salesRepository = getIt<SalesRepository>();
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

  test('generateNextShortBarcode produces numeric-only sequence', () async {
    final first = await productRepository.generateNextShortBarcode();
    expect(first, '2000');

    await productRepository.createProduct(
      const Product(
        id: null,
        name: 'Barcode Product 1',
        barcode: '2000',
        unitType: UnitType.piece,
        salePrice: 10,
        purchasePrice: 5,
        lowStockThreshold: 0,
      ),
    );

    await productRepository.createProduct(
      const Product(
        id: null,
        name: 'Barcode Product 2',
        barcode: '2002',
        unitType: UnitType.piece,
        salePrice: 10,
        purchasePrice: 5,
        lowStockThreshold: 0,
      ),
    );

    await productRepository.createProduct(
      const Product(
        id: null,
        name: 'Legacy Prefix Barcode',
        barcode: 'P2009',
        unitType: UnitType.piece,
        salePrice: 10,
        purchasePrice: 5,
        lowStockThreshold: 0,
      ),
    );

    final next = await productRepository.generateNextShortBarcode();
    expect(next, '2003');
  });

  test(
    'sales invoice search works by customer name and invoice number',
    () async {
      final customerA = await accountsRepository.createAccount(
        name: 'Ahmed Test Customer',
        accountType: 'customer',
      );
      final customerB = await accountsRepository.createAccount(
        name: 'Other Customer',
        accountType: 'customer',
      );
      final supplierId = await accountsRepository.createAccount(
        name: 'Search Supplier',
        accountType: 'supplier',
      );

      final product = await productRepository.createProduct(
        const Product(
          id: null,
          name: 'Search Product',
          unitType: UnitType.piece,
          salePrice: 100,
          purchasePrice: 60,
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
          paidAmount: 600,
          paymentMethod: PaymentMethod.cash,
        ),
      );

      await salesRepository.createSale(
        SaleCreateRequest(
          customerId: customerA,
          items: [
            SaleDraftItem(
              productId: product.id!,
              productName: product.name,
              unitType: product.unitType.name,
              availableStock: 999999,
              minUnitPrice: product.purchasePrice,
              quantity: 1,
              unitPrice: product.salePrice,
            ),
          ],
          paidAmount: 100,
          paymentMethod: PaymentMethod.cash,
        ),
      );

      await salesRepository.createSale(
        SaleCreateRequest(
          customerId: customerB,
          items: [
            SaleDraftItem(
              productId: product.id!,
              productName: product.name,
              unitType: product.unitType.name,
              availableStock: 999999,
              minUnitPrice: product.purchasePrice,
              quantity: 1,
              unitPrice: product.salePrice,
            ),
          ],
          paidAmount: 100,
          paymentMethod: PaymentMethod.cash,
        ),
      );

      final byName = await salesRepository.listInvoices(
        searchQuery: 'Ahmed',
        limit: 20,
        offset: 0,
      );
      expect(byName, isNotEmpty);
      expect(
        byName.every((row) => row.accountName.toLowerCase().contains('ahmed')),
        isTrue,
      );

      final targetInvoice = byName.first;
      final byInvoiceNumber = await salesRepository.listInvoices(
        searchQuery: targetInvoice.invoiceNumber,
        limit: 20,
        offset: 0,
      );
      expect(byInvoiceNumber.any((row) => row.id == targetInvoice.id), isTrue);
    },
  );
}
