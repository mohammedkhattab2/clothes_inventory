import 'package:delta_erp/features/products/domain/product_price_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProductPriceValidators', () {
    test('anyActiveSalePriceBelowCost flags retail below purchase', () {
      expect(
        ProductPriceValidators.anyActiveSalePriceBelowCost(
          retail: 80,
          purchase: 100,
          halfWholesale: 0,
          wholesale: 0,
        ),
        isTrue,
      );
    });

    test('anyActiveSalePriceBelowCost ignores zero tier prices', () {
      expect(
        ProductPriceValidators.anyActiveSalePriceBelowCost(
          retail: 150,
          purchase: 100,
          halfWholesale: 0,
          wholesale: 0,
        ),
        isFalse,
      );
    });

    test('anyActiveSalePriceBelowCost flags active tier below purchase', () {
      expect(
        ProductPriceValidators.anyActiveSalePriceBelowCost(
          retail: 150,
          purchase: 100,
          halfWholesale: 50,
          wholesale: 0,
        ),
        isTrue,
      );
    });

    test('retailPriceValidator requires retail and checks below cost only when purchase set', () {
      expect(
        ProductPriceValidators.retailPriceValidator(
          '150',
          (raw) => double.tryParse(raw),
          purchasePrice: 100,
          belowCostMessage: 'below',
        ),
        isNull,
      );

      expect(
        ProductPriceValidators.retailPriceValidator(
          '80',
          (raw) => double.tryParse(raw),
          purchasePrice: 100,
          belowCostMessage: 'below',
        ),
        'below',
      );

      expect(
        ProductPriceValidators.retailPriceValidator(
          '150',
          (raw) => double.tryParse(raw),
          purchasePrice: 0,
          belowCostMessage: 'below',
        ),
        isNull,
      );
    });
  });
}
