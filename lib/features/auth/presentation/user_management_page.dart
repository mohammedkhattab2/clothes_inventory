import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:delta_erp/core/widgets/app_page_shell.dart';
import 'package:delta_erp/features/auth/data/auth_repository.dart';
import 'package:delta_erp/features/auth/domain/access_policy.dart';
import 'package:delta_erp/features/auth/domain/auth_user.dart';
import 'package:delta_erp/features/auth/domain/user_audit_log_entry.dart';
import 'package:delta_erp/services/auth/session_service.dart';
import 'package:delta_erp/services/di/service_locator.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

enum _UserRowAction { edit, resetCredentials, delete }

class _UserManagementPageState extends State<UserManagementPage> {
  final AuthRepository _authRepository = getIt<AuthRepository>();
  final SessionService _sessionService = getIt<SessionService>();

  bool _loading = true;
  bool _saving = false;
  List<AuthUser> _users = const <AuthUser>[];
  List<UserAuditLogEntry> _auditLogs = const <UserAuditLogEntry>[];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
    });
    try {
      final results = await Future.wait([
        _authRepository.listUsers(),
        _authRepository.listAuditLogs(limit: 40),
      ]);
      final users = results[0] as List<AuthUser>;
      final auditLogs = results[1] as List<UserAuditLogEntry>;
      if (!mounted) return;
      setState(() {
        _users = users;
        _auditLogs = auditLogs;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  bool get _isOwner => _sessionService.currentUser?.role == UserRole.owner;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 900;

    return AppPageShell(
      isCompact: isCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'User Management'.tr(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: !_isOwner || _saving ? null : _showCreateUserDialog,
                icon: const Icon(Icons.person_add_alt_1),
                label: Text('Add User'.tr()),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_isOwner)
            _buildOwnerOnlyNotice(context)
          else
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildOwnerContent(context),
            ),
        ],
      ),
    );
  }

  Widget _buildOwnerContent(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _buildUsersTable(context)),
        const SizedBox(height: 12),
        _buildAuditLogsCard(context),
      ],
    );
  }

  Widget _buildOwnerOnlyNotice(BuildContext context) {
    return Expanded(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(
              context,
            ).colorScheme.errorContainer.withValues(alpha: 0.35),
            border: Border.all(color: Theme.of(context).colorScheme.error),
          ),
          child: Text(
            'Only owner can manage users.'.tr(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
    );
  }

  Widget _buildUsersTable(BuildContext context) {
    if (_users.isEmpty) {
      return Center(child: Text('No users found.'.tr()));
    }

    final useBottomSheetActions = MediaQuery.sizeOf(context).width < 1100;

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 18,
          columns: [
            DataColumn(label: Text('Name'.tr())),
            DataColumn(label: Text('Username'.tr())),
            DataColumn(label: Text('Role'.tr())),
            DataColumn(label: Text('Status'.tr())),
            DataColumn(label: Text('Security'.tr())),
            DataColumn(label: Text('Actions'.tr())),
          ],
          rows: _users
              .map((user) {
                return DataRow(
                  cells: [
                    DataCell(Text(user.fullName)),
                    DataCell(Text(user.username)),
                    DataCell(Text(_roleLabel(user.role))),
                    DataCell(
                      SizedBox(
                        width: 170,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: user.isActive,
                              onChanged: _saving
                                  ? null
                                  : (value) => _toggleUserActive(
                                      user: user,
                                      isActive: value,
                                    ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                user.isActive ? 'Active'.tr() : 'Disabled'.tr(),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => _showResetCredentialsDialog(user),
                        child: Text('Reset Credentials'.tr()),
                      ),
                    ),
                    DataCell(
                      useBottomSheetActions
                          ? IconButton(
                              tooltip: 'Actions'.tr(),
                              onPressed: _saving
                                  ? null
                                  : () => _showRowActionsBottomSheet(user),
                              icon: const Icon(Icons.more_vert),
                            )
                          : PopupMenuButton<_UserRowAction>(
                              enabled: !_saving,
                              tooltip: 'Actions'.tr(),
                              onSelected: (action) =>
                                  _handleRowAction(user, action),
                              itemBuilder: (context) => [
                                PopupMenuItem<_UserRowAction>(
                                  value: _UserRowAction.edit,
                                  child: Text('Edit'.tr()),
                                ),
                                PopupMenuItem<_UserRowAction>(
                                  value: _UserRowAction.resetCredentials,
                                  child: Text('Reset Credentials'.tr()),
                                ),
                                PopupMenuItem<_UserRowAction>(
                                  value: _UserRowAction.delete,
                                  child: Text('Delete'.tr()),
                                ),
                              ],
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Icon(Icons.more_vert),
                              ),
                            ),
                    ),
                  ],
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }

  Widget _buildAuditLogsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent User Activity'.tr(),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (_auditLogs.isEmpty)
              Text('No activity yet.'.tr())
            else
              SizedBox(
                height: 200,
                child: ListView.separated(
                  itemCount: _auditLogs.length,
                  separatorBuilder: (context, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entry = _auditLogs[index];
                    final actor = entry.actorUsername ?? '-';
                    final target = entry.targetUsername ?? '-';
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${_actionLabel(entry.action)} • ${_formatTimestamp(entry.createdAt)}',
                      ),
                      subtitle: Text(
                        '${'By'.tr()}: $actor | ${'Target'.tr()}: $target',
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleUserActive({
    required AuthUser user,
    required bool isActive,
  }) async {
    setState(() {
      _saving = true;
    });
    try {
      await _authRepository.setUserActive(
        userId: user.id,
        isActive: isActive,
        actorUserId: _sessionService.currentUser?.id,
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'Failed to update user.'.tr()}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _handleRowAction(AuthUser user, _UserRowAction action) {
    switch (action) {
      case _UserRowAction.edit:
        _showEditUserDialog(user);
        return;
      case _UserRowAction.resetCredentials:
        _showResetCredentialsDialog(user);
        return;
      case _UserRowAction.delete:
        _showDeleteUserDialog(user);
        return;
    }
  }

  Future<void> _showRowActionsBottomSheet(AuthUser user) async {
    final selected = await showModalBottomSheet<_UserRowAction>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text('Edit'.tr()),
                onTap: () => Navigator.of(context).pop(_UserRowAction.edit),
              ),
              ListTile(
                leading: const Icon(Icons.lock_reset),
                title: Text('Reset Credentials'.tr()),
                onTap: () =>
                    Navigator.of(context).pop(_UserRowAction.resetCredentials),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text('Delete'.tr()),
                onTap: () => Navigator.of(context).pop(_UserRowAction.delete),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null || !mounted) return;
    _handleRowAction(user, selected);
  }

  Future<void> _showCreateUserDialog() async {
    final fullNameController = TextEditingController();
    final usernameController = TextEditingController();
    final pinController = TextEditingController();
    final passwordController = TextEditingController();
    UserRole selectedRole = UserRole.cashier;
    bool active = true;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Create User'.tr()),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: fullNameController,
                        decoration: InputDecoration(labelText: 'Name'.tr()),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: usernameController,
                        decoration: InputDecoration(labelText: 'Username'.tr()),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: pinController,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: 'PIN'.tr()),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(labelText: 'Password'.tr()),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<UserRole>(
                        initialValue: selectedRole,
                        decoration: InputDecoration(labelText: 'Role'.tr()),
                        items: ownerAssignableRoles
                            .map(
                              (role) => DropdownMenuItem<UserRole>(
                                value: role,
                                child: Text(_roleLabel(role)),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            selectedRole = value;
                          });
                        },
                      ),
                      const SizedBox(height: 4),
                      SwitchListTile.adaptive(
                        value: active,
                        onChanged: (value) {
                          setDialogState(() {
                            active = value;
                          });
                        },
                        title: Text('Active'.tr()),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'.tr()),
                ),
                FilledButton(
                  onPressed: () async {
                    try {
                      await _authRepository.createUser(
                        username: usernameController.text,
                        fullName: fullNameController.text,
                        pin: pinController.text,
                        password: passwordController.text,
                        role: selectedRole,
                        isActive: active,
                        actorUserId: _sessionService.currentUser?.id,
                      );
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                      await _loadData();
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${'Failed to create user.'.tr()}: $e'),
                        ),
                      );
                    }
                  },
                  child: Text('Save'.tr()),
                ),
              ],
            );
          },
        );
      },
    );

    fullNameController.dispose();
    usernameController.dispose();
    pinController.dispose();
    passwordController.dispose();
  }

  Future<void> _showEditUserDialog(AuthUser user) async {
    final fullNameController = TextEditingController(text: user.fullName);
    UserRole selectedRole = user.role;
    final isCurrentSessionUser = _sessionService.currentUser?.id == user.id;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('${'Edit User'.tr()} - ${user.username}'),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: fullNameController,
                        decoration: InputDecoration(labelText: 'Name'.tr()),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<UserRole>(
                        initialValue: selectedRole,
                        decoration: InputDecoration(labelText: 'Role'.tr()),
                        items: _rolesForOwnerEditDropdown(user.role)
                            .map(
                              (role) => DropdownMenuItem<UserRole>(
                                value: role,
                                child: Text(_roleLabel(role)),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: isCurrentSessionUser
                            ? null
                            : (value) {
                                if (value == null) return;
                                setDialogState(() {
                                  selectedRole = value;
                                });
                              },
                      ),
                      if (isCurrentSessionUser)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Cannot change your role during active session.'
                                .tr(),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'.tr()),
                ),
                FilledButton(
                  onPressed: () async {
                    try {
                      await _authRepository.updateUserProfile(
                        userId: user.id,
                        fullName: fullNameController.text,
                        role: selectedRole,
                        currentSessionUserId: _sessionService.currentUser?.id,
                        actorUserId: _sessionService.currentUser?.id,
                      );
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                      await _loadData();
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${'Failed to update user.'.tr()}: $e'),
                        ),
                      );
                    }
                  },
                  child: Text('Update'.tr()),
                ),
              ],
            );
          },
        );
      },
    );

    fullNameController.dispose();
  }

  Future<void> _showResetCredentialsDialog(AuthUser user) async {
    final pinController = TextEditingController();
    final passwordController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${'Reset Credentials'.tr()} - ${user.username}'),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'PIN (leave empty to keep)'.tr(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password (leave empty to keep)'.tr(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'.tr()),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await _authRepository.updateUserCredentials(
                    userId: user.id,
                    pin: pinController.text,
                    password: passwordController.text,
                    actorUserId: _sessionService.currentUser?.id,
                  );
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  await _loadData();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${'Failed to update credentials.'.tr()}: $e',
                      ),
                    ),
                  );
                }
              },
              child: Text('Update'.tr()),
            ),
          ],
        );
      },
    );

    pinController.dispose();
    passwordController.dispose();
  }

  Future<void> _showDeleteUserDialog(AuthUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete User'.tr()),
          content: Text(
            '${'Are you sure you want to delete this user?'.tr()} (${user.username})',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Delete'.tr()),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _saving = true;
    });
    try {
      await _authRepository.deleteUser(
        userId: user.id,
        actorUserId: _sessionService.currentUser?.id,
        currentSessionUserId: _sessionService.currentUser?.id,
      );
      if (!mounted) return;
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'Failed to delete user.'.tr()}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return 'Owner'.tr();
      case UserRole.manager:
        return 'Manager'.tr();
      case UserRole.cashier:
        return 'Cashier'.tr();
      case UserRole.purchaser:
        return 'Purchaser'.tr();
    }
  }

  /// Includes [current] when it is not in [ownerAssignableRoles] (legacy users).
  List<UserRole> _rolesForOwnerEditDropdown(UserRole current) {
    final items = List<UserRole>.from(ownerAssignableRoles);
    if (!items.contains(current)) {
      items.insert(0, current);
    }
    return items;
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'create_user':
        return 'Create User'.tr();
      case 'set_user_active':
        return 'Update User Status'.tr();
      case 'update_credentials':
        return 'Reset Credentials'.tr();
      case 'update_user_profile':
        return 'Edit User'.tr();
      case 'delete_user':
        return 'Delete User'.tr();
      default:
        return action;
    }
  }

  String _formatTimestamp(DateTime value) {
    final raw = value.toLocal().toIso8601String();
    return raw.replaceFirst('T', ' ').split('.').first;
  }
}
