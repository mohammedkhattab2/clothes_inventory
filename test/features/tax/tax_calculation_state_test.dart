import 'package:flutter_test/flutter_test.dart';
import 'package:clothes_inventory/features/purchases/domain/purchase_models.dart';
import 'package:clothes_inventory/features/purchases/presentation/purchases_cubit.dart';
import 'package:clothes_inventory/features/sales/domain/sale_models.dart';
import 'package:clothes_inventory/features/sales/presentation/sales_cubit.dart';

void main() {
  group('SalesState tax calculations', () {
    test('computes subtotal, tax amount, and total correctly', () {
      const state = SalesState(
        cart: [
          SaleDraftItem(
            productId: 1,
            productName: 'A',
            unitType: 'piece',
            availableStock: 10,
            minUnitPrice: 10,
            quantity: 2,
            unitPrice: 50,
            discount: 5,
          ),
          SaleDraftItem(
            productId: 2,
            productName: 'B',
            unitType: 'piece',
            availableStock: 10,
            minUnitPrice: 10,
            quantity: 1,
            unitPrice: 20,
          ),
        ],
        taxPercentage: 14,
      );

      expect(state.subtotal, 115);
      expect(state.taxAmount, 16.1);
      expect(state.total, 131.1);
    });

    test('keeps total equal to subtotal when tax is zero', () {
      const state = SalesState(
        cart: [
          SaleDraftItem(
            productId: 1,
            productName: 'A',
            unitType: 'piece',
            availableStock: 10,
            minUnitPrice: 10,
            quantity: 3,
            unitPrice: 40,
          ),
        ],
      );

      expect(state.taxAmount, 0);
      expect(state.total, state.subtotal);
    });
  });

  group('PurchasesState tax calculations', () {
    test('computes subtotal, tax amount, and total correctly', () {
      const state = PurchasesState(
        cart: [
          PurchaseDraftItem(
            productId: 1,
            productName: 'A',
            unitType: 'piece',
            quantity: 4,
            unitPrice: 25,
            discount: 10,
          ),
          PurchaseDraftItem(
            productId: 2,
            productName: 'B',
            unitType: 'piece',
            quantity: 1,
            unitPrice: 30,
          ),
        ],
        taxPercentage: 10,
      );

      expect(state.subtotal, 120);
      expect(state.taxAmount, 12);
      expect(state.total, 132);
    });

    test('keeps total equal to subtotal when tax is zero', () {
      const state = PurchasesState(
        cart: [
          PurchaseDraftItem(
            productId: 1,
            productName: 'A',
            unitType: 'piece',
            quantity: 2,
            unitPrice: 75,
          ),
        ],
      );

      expect(state.taxAmount, 0);
      expect(state.total, state.subtotal);
    });
  });
}
