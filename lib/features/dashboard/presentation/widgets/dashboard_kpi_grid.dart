import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import 'package:delta_erp/features/dashboard/data/dashboard_repository.dart';
import 'package:delta_erp/features/dashboard/presentation/dashboard_cubit.dart';

class DashboardKpiGrid extends StatelessWidget {
  const DashboardKpiGrid({
    required this.snapshot,
    required this.cubit,
    this.ownerView = true,
    super.key,
  });

  final DashboardSnapshot snapshot;
  final DashboardCubit cubit;
  final bool ownerView;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dense = MediaQuery.sizeOf(context).height < 820;

    final currency = intl.NumberFormat.currency(symbol: '', decimalDigits: 2);

    String formulaCaption(String kind) {
      switch (kind) {
        case 'revenue':
          return '${'Formula'.tr()}:\n'
              '${'Revenue'.tr()} = Σ(${"Sales".tr()} ${"Invoice".tr()} ${"Total".tr()})\n'
              '= ${currency.format(snapshot.totalSales)}';
        case 'expenses':
          return '${'Formula'.tr()}:\n'
              '${'Expenses'.tr()} = ${'Operating expenses'.tr()}\n'
              '= ${currency.format(snapshot.expenses)}';
        case 'gross':
          return '${'Formula'.tr()}:\n'
              '${'Gross Profit'.tr()} = ${'Revenue'.tr()} - ${'COGS'.tr()}\n'
              '= ${currency.format(snapshot.totalSales)} - ${currency.format(snapshot.cogs)}\n'
              '= ${currency.format(snapshot.grossProfit)}';
        case 'net':
          return '${'Formula'.tr()}:\n'
              '${'Net Profit'.tr()} = ${'Gross Profit'.tr()} - ${'Expenses'.tr()}\n'
              '= ${currency.format(snapshot.grossProfit)} - ${currency.format(snapshot.expenses)}\n'
              '= ${currency.format(snapshot.netProfit)}';
        case 'customer_debt':
          return '${'Formula'.tr()}:\n'
              '${'Customer Debt'.tr()} = Σ(${"Sales Invoice".tr()} ${"Outstanding".tr()})\n'
              '= ${currency.format(snapshot.outstandingCustomerDebt)}';
        case 'supplier_debt':
          return '${'Formula'.tr()}:\n'
              '${'Supplier Debt'.tr()} = Σ(${"Purchase Invoice".tr()} ${"Outstanding".tr()})\n'
              '= ${currency.format(snapshot.outstandingSupplierDebt)}';
        default:
          return '';
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final spacing = dense ? 8.0 : 10.0;

        final coreCards = [
          _KpiCard(
            title: 'Revenue'.tr(),
            subtitle: 'Sales'.tr(),
            value: currency.format(snapshot.totalSales),
            formulaCaption: formulaCaption('revenue'),
            color: colorScheme.primary,
            icon: Icons.trending_up_rounded,
            onTap: () => context.go(cubit.drillDownRouteFor('revenue')),
          ),
          _KpiCard(
            title: 'Expenses'.tr(),
            subtitle: 'Operating expenses'.tr(),
            value: currency.format(snapshot.expenses),
            formulaCaption: formulaCaption('expenses'),
            color: colorScheme.error,
            icon: Icons.shopping_basket_outlined,
            onTap: () => context.go(cubit.drillDownRouteFor('expenses')),
          ),
        ];

        final ownerCards = [
          _KpiCard(
            title: 'Gross Profit'.tr(),
            subtitle: 'Profitability'.tr(),
            value: currency.format(snapshot.grossProfit),
            formulaCaption: formulaCaption('gross'),
            color: colorScheme.tertiary,
            icon: Icons.show_chart_rounded,
            onTap: () => context.go(cubit.drillDownRouteFor('gross')),
          ),
          _KpiCard(
            title: 'Net Profit'.tr(),
            subtitle: 'Bottom Line'.tr(),
            value: currency.format(snapshot.netProfit),
            formulaCaption: formulaCaption('net'),
            color: colorScheme.inversePrimary,
            icon: Icons.insights_outlined,
            onTap: () => context.go(cubit.drillDownRouteFor('net')),
          ),
          _KpiCard(
            title: 'Customer Debt'.tr(),
            subtitle: 'Receivables'.tr(),
            value: currency.format(snapshot.outstandingCustomerDebt),
            formulaCaption: formulaCaption('customer_debt'),
            color: colorScheme.tertiary,
            icon: Icons.people_alt_outlined,
            onTap: () => context.go(cubit.drillDownRouteFor('customer_debt')),
          ),
          _KpiCard(
            title: 'Supplier Debt'.tr(),
            subtitle: 'Payables'.tr(),
            value: currency.format(snapshot.outstandingSupplierDebt),
            formulaCaption: formulaCaption('supplier_debt'),
            color: colorScheme.secondary,
            icon: Icons.warehouse_outlined,
            onTap: () => context.go(cubit.drillDownRouteFor('supplier_debt')),
          ),
        ];

        final cards = ownerView
            ? [...coreCards, ...ownerCards]
            : [...coreCards];

        Widget buildGridRow(List<Widget> rowCards) {
          return Row(
            children: [
              for (var i = 0; i < rowCards.length; i++) ...[
                Expanded(child: rowCards[i]),
                if (i < rowCards.length - 1) SizedBox(width: spacing),
              ],
            ],
          );
        }

        final isLarge = maxWidth >= 1120;
        final isMedium = maxWidth >= 760;

        Widget content;
        if (!ownerView) {
          content = buildGridRow(cards);
        } else if (isLarge) {
          content = Column(
            children: [
              buildGridRow(cards.sublist(0, 3)),
              SizedBox(height: spacing),
              buildGridRow(cards.sublist(3, 6)),
            ],
          );
        } else if (isMedium) {
          content = Column(
            children: [
              buildGridRow(cards.sublist(0, 2)),
              SizedBox(height: spacing),
              buildGridRow(cards.sublist(2, 4)),
              SizedBox(height: spacing),
              buildGridRow(cards.sublist(4, 6)),
            ],
          );
        } else {
          content = Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                SizedBox(width: double.infinity, child: cards[i]),
                if (i < cards.length - 1) SizedBox(height: spacing),
              ],
            ],
          );
        }

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(dense ? 12 : 14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.grid_view_rounded,
                    size: dense ? 18 : 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Dashboard Summary'.tr(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              if (!ownerView) ...[
                SizedBox(height: dense ? 8 : 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    'Only revenue and expenses are shown for shift settlement.'
                        .tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              SizedBox(height: dense ? 10 : 12),
              content,
            ],
          ),
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.formulaCaption,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String value;
  final String formulaCaption;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dense = MediaQuery.sizeOf(context).height < 820;

    return Tooltip(
      message: formulaCaption,
      waitDuration: const Duration(milliseconds: 250),
      showDuration: const Duration(seconds: 8),
      preferBelow: false,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(dense ? 12 : 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 16,
                    color: color.withValues(alpha: 0.9),
                  ),
                ],
              ),
              SizedBox(height: dense ? 5 : 6),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
