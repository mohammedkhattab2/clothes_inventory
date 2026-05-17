enum UserRole { owner, manager, cashier, purchaser }

extension UserRoleCodec on UserRole {
  String get dbValue {
    switch (this) {
      case UserRole.owner:
        return 'owner';
      case UserRole.manager:
        return 'manager';
      case UserRole.cashier:
        return 'cashier';
      case UserRole.purchaser:
        return 'purchaser';
    }
  }

  bool get canViewAllInvoices =>
      this == UserRole.owner ||
      this == UserRole.manager ||
      this == UserRole.cashier;
}

UserRole userRoleFromDb(String raw) {
  switch (raw) {
    case 'owner':
      return UserRole.owner;
    case 'manager':
      return UserRole.manager;
    case 'cashier':
      return UserRole.cashier;
    case 'purchaser':
      return UserRole.purchaser;
    default:
      return UserRole.cashier;
  }
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.isActive,
  });

  final int id;
  final String username;
  final String fullName;
  final UserRole role;
  final bool isActive;
}
