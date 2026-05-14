import 'package:flutter_test/flutter_test.dart';
import 'package:clothes_inventory/core/utils/return_rules.dart';

void main() {
  group('ReturnRules.validate', () {
    test('rejects non-positive quantities', () {
      final result = ReturnRules.validate(
        originalQuantity: 10,
        alreadyReturned: 0,
        requestedQuantity: 0,
        unitType: 'piece',
      );

      expect(result.isValid, isFalse);
      expect(result.error, isNotNull);
    });

    test('rejects fractional quantity for piece unit', () {
      final result = ReturnRules.validate(
        originalQuantity: 10,
        alreadyReturned: 0,
        requestedQuantity: 1.25,
        unitType: 'piece',
      );

      expect(result.isValid, isFalse);
      expect(result.error, contains('whole quantity'));
    });

    test('rejects quantity above remaining', () {
      final result = ReturnRules.validate(
        originalQuantity: 10,
        alreadyReturned: 8,
        requestedQuantity: 3,
        unitType: 'weight',
      );

      expect(result.isValid, isFalse);
      expect(result.remainingQuantity, 2);
    });

    test('accepts valid return quantity', () {
      final result = ReturnRules.validate(
        originalQuantity: 10,
        alreadyReturned: 4,
        requestedQuantity: 2,
        unitType: 'piece',
      );

      expect(result.isValid, isTrue);
      expect(result.error, isNull);
      expect(result.remainingQuantity, 6);
    });
  });
}
