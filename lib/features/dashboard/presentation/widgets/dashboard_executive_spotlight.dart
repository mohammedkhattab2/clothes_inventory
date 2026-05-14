import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:clothes_inventory/features/dashboard/data/dashboard_repository.dart';

class DashboardExecutiveSpotlight extends StatelessWidget {
  const DashboardExecutiveSpotlight({
    required this.snapshot,
    required this.dense,
    super.key,
  });

  final DashboardSnapshot snapshot;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final veryDense = MediaQuery.sizeOf(context).height < 700;

    final currency = intl.NumberFormat.currency(symbol: '', decimalDigits: 2);
    final trendColor = snapshot.netProfit >= 0
        ? colorScheme.primary
        : colorScheme.error;
    final trendLabel = snapshot.netProfit >= 0
        ? 'Positive'.tr()
        : 'Negative'.tr();

    final performanceBoxDecoration = BoxDecoration(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: colorScheme.outlineVariant),
    );

    final performanceTextStyle = Theme.of(context).textTheme.titleMedium
        ?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w700);

    final trendLabelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: trendColor,
      fontWeight: FontWeight.w700,
    );
    final sectionGap = veryDense ? 8.0 : (dense ? 10.0 : 12.0);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(veryDense ? 12 : (dense ? 14 : 16)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.82),
            colorScheme.surfaceContainerHigh,
          ],
          stops: const [0.2, 1],
        ),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;
          final performanceBox = Container(
            padding: EdgeInsets.symmetric(
              horizontal: veryDense ? 10 : (dense ? 12 : 14),
              vertical: veryDense ? 8 : (dense ? 9 : 10),
            ),
            decoration: performanceBoxDecoration,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.trending_up_rounded,
                  color: trendColor,
                  size: veryDense ? 18 : 20,
                ),
                SizedBox(width: veryDense ? 7 : 9),
                Text(
                  '${'Net Profit'.tr()}: ${currency.format(snapshot.netProfit)}',
                  style: performanceTextStyle,
                ),
                SizedBox(width: veryDense ? 8 : 10),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: veryDense ? 8 : 10,
                    vertical: veryDense ? 4 : 5,
                  ),
                  decoration: BoxDecoration(
                    color: trendColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: trendColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(trendLabel, style: trendLabelStyle),
                ),
              ],
            ),
          );

          final summaryGrid = Wrap(
            spacing: sectionGap,
            runSpacing: sectionGap,
            children: [
              _MiniStat(
                title: 'Revenue'.tr(),
                value: currency.format(snapshot.totalSales),
                color: colorScheme.primary, // Use primary color for revenue
              ),
              _MiniStat(
                title: 'Expenses'.tr(),
                value: currency.format(snapshot.expenses),
                color: colorScheme.error,
              ),
              _MiniStat(
                title: 'Gross Profit'.tr(),
                value: currency.format(snapshot.grossProfit),
                color: colorScheme.tertiary,
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dashboard Analytics'.tr(),
                  style:
                      (veryDense
                              ? Theme.of(context).textTheme.headlineSmall
                              : Theme.of(context).textTheme.headlineMedium)
                          ?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                ),
                SizedBox(height: veryDense ? 6 : 8),
                Text(
                  'Generated'.tr(),
                  style:
                      (veryDense
                              ? Theme.of(context).textTheme.titleSmall
                              : Theme.of(context).textTheme.titleMedium)
                          ?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                ),
                SizedBox(height: sectionGap),
                performanceBox,
                SizedBox(height: sectionGap),
                summaryGrid,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dashboard Analytics'.tr(),
                      style:
                          (veryDense
                                  ? Theme.of(context).textTheme.headlineSmall
                                  : Theme.of(context).textTheme.headlineMedium)
                              ?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    SizedBox(height: veryDense ? 6 : 8),
                    Text(
                      'Generated'.tr(),
                      style:
                          (veryDense
                                  ? Theme.of(context).textTheme.titleSmall
                                  : Theme.of(context).textTheme.titleMedium)
                              ?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    SizedBox(height: sectionGap),
                    performanceBox,
                  ],
                ),
              ),
              SizedBox(width: sectionGap),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: dense ? 460 : 520),
                child: summaryGrid,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final veryDense = MediaQuery.sizeOf(context).height < 700;

    return Container(
      constraints: BoxConstraints(minWidth: veryDense ? 120 : 140),
      padding: EdgeInsets.symmetric(
        horizontal: veryDense ? 10 : 12,
        vertical: veryDense ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style:
                (veryDense
                        ? Theme.of(context).textTheme.titleSmall
                        : Theme.of(context).textTheme.titleMedium)
                    ?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
          ),
          SizedBox(height: veryDense ? 4 : 5),
          Text(
            value,
            style:
                (veryDense
                        ? Theme.of(context).textTheme.titleMedium
                        : Theme.of(context).textTheme.headlineSmall)
                    ?.copyWith(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
