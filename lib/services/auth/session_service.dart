import 'package:flutter/foundation.dart';
import 'package:delta_erp/features/auth/domain/auth_user.dart';

class SessionService {
  final ValueNotifier<AuthUser?> currentUserListenable =
      ValueNotifier<AuthUser?>(null);

  AuthUser? get currentUser => currentUserListenable.value;

  bool get isLoggedIn => currentUser != null;

  bool get canViewAllInvoices => currentUser?.role.canViewAllInvoices ?? false;

  int requireUserId() {
    final user = currentUser;
    if (user == null) {
      throw StateError('No authenticated user in session.');
    }
    return user.id;
  }

  void login(AuthUser user) {
    currentUserListenable.value = user;
  }

  void logout() {
    currentUserListenable.value = null;
  }
}
