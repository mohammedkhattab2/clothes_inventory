import 'package:delta_erp/features/auth/domain/access_policy.dart';
import 'package:delta_erp/features/auth/domain/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('access_policy', () {
    test('cashier forbidden locations', () {
      expect(isCashierForbiddenLocation('/purchases'), isTrue);
      expect(isCashierForbiddenLocation('/purchases?x=1'), isTrue);
      expect(isCashierForbiddenLocation('/settings'), isTrue);
      expect(isCashierForbiddenLocation('/settings/backup'), isTrue);
      expect(isCashierForbiddenLocation('/users'), isTrue);
      expect(isCashierForbiddenLocation('/sales'), isFalse);
      expect(isCashierForbiddenLocation('/products'), isFalse);
    });

    test('owner assignable roles', () {
      expect(ownerMayAssignRole(UserRole.owner), isTrue);
      expect(ownerMayAssignRole(UserRole.cashier), isTrue);
      expect(ownerMayAssignRole(UserRole.manager), isFalse);
      expect(ownerMayAssignRole(UserRole.purchaser), isFalse);
    });

    test('product management by role', () {
      expect(roleCanManageProducts(UserRole.cashier), isFalse);
      expect(roleCanManageProducts(UserRole.owner), isTrue);
      expect(roleCanManageProducts(UserRole.manager), isTrue);
      expect(roleCanManageProducts(null), isFalse);
    });
  });
}
