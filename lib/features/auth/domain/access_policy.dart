import 'package:delta_erp/features/auth/domain/auth_user.dart';

/// Routes the cashier role must not open (prefix match on URI path).
const List<String> cashierForbiddenRoutePrefixes = <String>[
  '/inventory',
  '/purchases',
  '/settings',
  '/users',
];

/// Whether [role] is forbidden to open [locationPath] (e.g. from [GoRouterState.fullPath]).
bool isCashierForbiddenLocation(String locationPath) {
  for (final prefix in cashierForbiddenRoutePrefixes) {
    if (locationPath.startsWith(prefix)) {
      return true;
    }
  }
  return false;
}

/// Roles the owner may assign when creating or editing users (UI + repository guard).
const List<UserRole> ownerAssignableRoles = <UserRole>[
  UserRole.owner,
  UserRole.cashier,
];

bool ownerMayAssignRole(UserRole role) => ownerAssignableRoles.contains(role);

/// Cashiers may list/view products but must not add, edit, delete, or bulk-import them.
bool roleCanManageProducts(UserRole? role) {
  if (role == null) {
    return false;
  }
  return role != UserRole.cashier;
}
