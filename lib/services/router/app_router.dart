import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:delta_erp/features/accounts/presentation/account_statement_page.dart';
import 'package:delta_erp/features/accounts/presentation/account_settlement_page.dart';
import 'package:delta_erp/features/accounts/presentation/accounts_page.dart';
import 'package:delta_erp/features/accounts/presentation/contacts_directory_page.dart';
import 'package:delta_erp/features/auth/domain/auth_user.dart';
import 'package:delta_erp/features/auth/presentation/user_management_page.dart';
import 'package:delta_erp/features/backup/presentation/backup_page.dart';
import 'package:delta_erp/features/accounts/presentation/statement_page.dart';
import 'package:delta_erp/features/dashboard/presentation/dashboard_page.dart';
import 'package:delta_erp/features/dashboard/presentation/dashboard_drilldown_page.dart';
import 'package:delta_erp/features/expenses/presentation/expenses_page.dart';
import 'package:delta_erp/features/invoices/presentation/invoices_hub_page.dart';
import 'package:delta_erp/features/inventory/presentation/inventory_page.dart';
import 'package:delta_erp/features/products/presentation/products_page.dart';
import 'package:delta_erp/features/purchases/presentation/purchases_page.dart';
import 'package:delta_erp/features/sales/presentation/sales_page.dart';
import 'package:delta_erp/features/sales/presentation/sales_cubit.dart';
import 'package:delta_erp/features/settings/presentation/company_settings_page.dart';
import 'package:delta_erp/features/auth/domain/access_policy.dart';
import 'package:delta_erp/services/auth/session_service.dart';
import 'package:delta_erp/services/di/service_locator.dart';
import 'package:delta_erp/services/router/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/dashboard',
  refreshListenable: getIt<SessionService>().currentUserListenable,
  redirect: (context, state) {
    final user = getIt<SessionService>().currentUser;
    if (user?.role != UserRole.cashier) {
      return null;
    }
    if (isCashierForbiddenLocation(state.uri.path)) {
      return '/sales';
    }
    return null;
  },
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: DashboardPage()),
          routes: [
            GoRoute(
              path: 'drilldown/:kind',
              pageBuilder: (context, state) {
                final kind = state.pathParameters['kind'] ?? 'revenue';
                final isOwner =
                    getIt<SessionService>().currentUser?.role == UserRole.owner;
                const allowedForNonOwner = <String>{'revenue', 'expenses'};
                if (!isOwner && !allowedForNonOwner.contains(kind)) {
                  return const NoTransitionPage(child: DashboardPage());
                }
                final fromRaw = state.uri.queryParameters['from'];
                final toRaw = state.uri.queryParameters['to'];
                final granularity =
                    state.uri.queryParameters['granularity'] ?? 'day';
                final categoryId = int.tryParse(
                  state.uri.queryParameters['categoryId'] ?? '',
                );
                final accountId = int.tryParse(
                  state.uri.queryParameters['accountId'] ?? '',
                );

                final from =
                    DateTime.tryParse(fromRaw ?? '') ??
                    DateTime.now().subtract(const Duration(days: 30));
                final to = DateTime.tryParse(toRaw ?? '') ?? DateTime.now();

                return NoTransitionPage(
                  child: DashboardDrillDownPage(
                    kind: kind,
                    fromDate: from,
                    toDate: to,
                    granularity: granularity,
                    categoryId: categoryId,
                    accountId: accountId,
                  ),
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: '/products',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ProductsPage()),
        ),
        GoRoute(
          path: '/sales',
          pageBuilder: (context, state) {
            final selectedInvoiceId = int.tryParse(
              state.uri.queryParameters['selectedInvoiceId'] ?? '',
            );
            final fromDate = DateTime.tryParse(
              state.uri.queryParameters['from'] ?? '',
            );
            final toDate = DateTime.tryParse(
              state.uri.queryParameters['to'] ?? '',
            );
            final accountId = int.tryParse(
              state.uri.queryParameters['accountId'] ?? '',
            );
            final categoryId = int.tryParse(
              state.uri.queryParameters['categoryId'] ?? '',
            );
            final page =
                int.tryParse(state.uri.queryParameters['page'] ?? '') ?? 0;
            final pageSize =
                int.tryParse(state.uri.queryParameters['pageSize'] ?? '') ?? 50;
            final navSource = state.uri.queryParameters['navSource'];

            return NoTransitionPage(
              child: BlocProvider<SalesCubit>(
                create: (_) => getIt<SalesCubit>(),
                child: SalesPage(
                  selectedInvoiceId: selectedInvoiceId,
                  fromDate: fromDate,
                  toDate: toDate,
                  accountId: accountId,
                  categoryId: categoryId,
                  initialInvoicePage: page,
                  invoicePageSize: pageSize,
                  navSource: navSource,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: '/purchases',
          pageBuilder: (context, state) {
            final selectedInvoiceId = int.tryParse(
              state.uri.queryParameters['selectedInvoiceId'] ?? '',
            );
            final fromDate = DateTime.tryParse(
              state.uri.queryParameters['from'] ?? '',
            );
            final toDate = DateTime.tryParse(
              state.uri.queryParameters['to'] ?? '',
            );
            final accountId = int.tryParse(
              state.uri.queryParameters['accountId'] ?? '',
            );
            final categoryId = int.tryParse(
              state.uri.queryParameters['categoryId'] ?? '',
            );
            final page =
                int.tryParse(state.uri.queryParameters['page'] ?? '') ?? 0;
            final pageSize =
                int.tryParse(state.uri.queryParameters['pageSize'] ?? '') ?? 50;
            final navSource = state.uri.queryParameters['navSource'];

            return NoTransitionPage(
              child: PurchasesPage(
                selectedInvoiceId: selectedInvoiceId,
                fromDate: fromDate,
                toDate: toDate,
                accountId: accountId,
                categoryId: categoryId,
                initialInvoicePage: page,
                invoicePageSize: pageSize,
                navSource: navSource,
              ),
            );
          },
        ),
        GoRoute(
          path: '/invoices',
          pageBuilder: (context, state) {
            final selectedInvoiceId = int.tryParse(
              state.uri.queryParameters['selectedInvoiceId'] ?? '',
            );
            final fromDate = DateTime.tryParse(
              state.uri.queryParameters['from'] ?? '',
            );
            final toDate = DateTime.tryParse(
              state.uri.queryParameters['to'] ?? '',
            );
            final accountId = int.tryParse(
              state.uri.queryParameters['accountId'] ?? '',
            );
            final categoryId = int.tryParse(
              state.uri.queryParameters['categoryId'] ?? '',
            );
            final page =
                int.tryParse(state.uri.queryParameters['page'] ?? '') ?? 0;
            final pageSize =
                int.tryParse(state.uri.queryParameters['pageSize'] ?? '') ?? 50;
            final navSource = state.uri.queryParameters['navSource'];
            final tabParam = (state.uri.queryParameters['tab'] ?? 'sales')
                .trim()
                .toLowerCase();
            final initialTab = tabParam == 'purchases'
                ? InvoicesHubTab.purchases
                : InvoicesHubTab.sales;

            return NoTransitionPage(
              child: InvoicesHubPage(
                initialTab: initialTab,
                selectedInvoiceId: selectedInvoiceId,
                fromDate: fromDate,
                toDate: toDate,
                accountId: accountId,
                categoryId: categoryId,
                initialPage: page,
                pageSize: pageSize,
                navSource: navSource,
              ),
            );
          },
        ),
        GoRoute(
          path: '/inventory',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: InventoryPage()),
        ),
        GoRoute(
          path: '/contacts',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ContactsDirectoryPage()),
        ),
        GoRoute(
          path: '/accounts',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: AccountsPage()),
          routes: [
            GoRoute(
              path: 'settlement',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: AccountSettlementPage()),
            ),
            GoRoute(
              path: 'statement/:accountId',
              pageBuilder: (context, state) {
                final accountId =
                    int.tryParse(state.pathParameters['accountId'] ?? '') ?? 0;
                return NoTransitionPage(
                  child: AccountStatementPage(initialAccountId: accountId),
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: '/expenses',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ExpensesPage()),
        ),
        GoRoute(
          path: '/statement',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: StatementPage()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: CompanySettingsPage()),
          routes: [
            GoRoute(
              path: 'backup',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: BackupPage()),
            ),
          ],
        ),
        GoRoute(
          path: '/users',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: UserManagementPage()),
        ),
      ],
    ),
  ],
);
