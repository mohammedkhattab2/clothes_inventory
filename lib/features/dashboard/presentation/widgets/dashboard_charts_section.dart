import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:delta_erp/features/dashboard/data/dashboard_repository.dart';
import 'package:delta_erp/features/dashboard/presentation/widgets/dashboard_chart_card.dart';
import 'package:delta_erp/features/dashboard/presentation/widgets/sales_purchases_line_chart.dart';
import 'package:delta_erp/features/dashboard/presentation/widgets/top_products_bar_chart.dart';

class DashboardChartsSection extends StatelessWidget {
  const DashboardChartsSection({
    required this.snapshot,
    required this.isDenseViewport,
    required this.topChartKey,
    required this.trendChartKey,
    super.key,
  });

  final DashboardSnapshot snapshot;
  final bool isDenseViewport;
  final GlobalKey topChartKey;
  final GlobalKey trendChartKey;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final veryDense = MediaQuery.sizeOf(context).height < 700;

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackedCharts = constraints.maxWidth < 1000;
        final chartHeight = veryDense
            ? 220.0
            : (isDenseViewport ? 250.0 : 290.0);
        final sectionGap = veryDense ? 8.0 : (isDenseViewport ? 10.0 : 12.0);

        Widget buildChartCard({
          required String title,
          required IconData icon,
          required Widget child,
          required GlobalKey chartKey,
        }) {
          return DashboardChartCard(
            title: title,
            icon: icon,
            child: RepaintBoundary(
              key: chartKey,
              child: Container(
                height: chartHeight,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                padding: EdgeInsets.all(veryDense ? 10 : 12),
                child: child,
              ),
            ),
          );
        }

        Widget content;
        if (stackedCharts) {
          content = Column(
            children: [
              buildChartCard(
                title: 'Top-selling products'.tr(),
                icon: Icons.leaderboard_outlined,
                chartKey: topChartKey,
                child: TopProductsBarChart(products: snapshot.topProducts),
              ),
              SizedBox(height: sectionGap),
              buildChartCard(
                title: 'Sales vs Purchases Trend'.tr(),
                icon: Icons.show_chart_rounded,
                chartKey: trendChartKey,
                child: SalesPurchasesLineChart(points: snapshot.trend),
              ),
            ],
          );
        } else {
          content = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: buildChartCard(
                  title: 'Top-selling products'.tr(),
                  icon: Icons.leaderboard_outlined,
                  chartKey: topChartKey,
                  child: TopProductsBarChart(products: snapshot.topProducts),
                ),
              ),
              SizedBox(width: sectionGap),
              Expanded(
                child: buildChartCard(
                  title: 'Sales vs Purchases Trend'.tr(),
                  icon: Icons.show_chart_rounded,
                  chartKey: trendChartKey,
                  child: SalesPurchasesLineChart(points: snapshot.trend),
                ),
              ),
            ],
          );
        }

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(isDenseViewport ? 12 : 14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bar_chart_rounded,
                    size: veryDense ? 20 : 22,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Performance Charts'.tr(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              SizedBox(height: sectionGap),
              content,
            ],
          ),
        );
      },
    );
  }
}
