import 'package:delta_erp/features/purchases/domain/purchase_models.dart';
import 'package:delta_erp/features/purchases/presentation/utils/purchases_formatters.dart';
import 'package:delta_erp/services/printing/thermal_printer_presets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolvePurchaseCartBarcodeCopies', () {
    const item = PurchaseDraftItem(
      productId: 1,
      productName: 'Test',
      barcode: '1234',
      unitType: 'piece',
      quantity: 5,
      unitPrice: 10,
    );

    test('uses cubit quantity when no draft or controller text', () {
      final result = resolvePurchaseCartBarcodeCopies(
        item: item,
        inlineQuantityDrafts: const {},
        controllerText: null,
      );
      expect(result.copies, 5);
      expect(result.requested, 5);
    });

    test('prefers inline draft over cubit quantity', () {
      final result = resolvePurchaseCartBarcodeCopies(
        item: item,
        inlineQuantityDrafts: const {1: '12'},
        controllerText: '3',
      );
      expect(result.copies, 12);
      expect(result.requested, 12);
    });

    test('uses controller text when draft is empty', () {
      final result = resolvePurchaseCartBarcodeCopies(
        item: item,
        inlineQuantityDrafts: const {1: '  '},
        controllerText: '8',
      );
      expect(result.copies, 8);
      expect(result.requested, 8);
    });

    test('clamps to max copies', () {
      final overMax = ThermalPrinterPresets.maxBarcodeLabelCopies + 10;
      final result = resolvePurchaseCartBarcodeCopies(
        item: item,
        inlineQuantityDrafts: {1: '$overMax'},
        controllerText: null,
      );
      expect(result.requested, overMax);
      expect(result.copies, ThermalPrinterPresets.maxBarcodeLabelCopies);
    });
  });
}
