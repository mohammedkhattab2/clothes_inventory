import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:delta_erp/core/widgets/app_empty_state.dart';
import 'package:delta_erp/features/dashboard/data/dashboard_repository.dart';

class TopProductsBarChart extends StatelessWidget {
  const TopProductsBarChart({required this.products, super.key});

  final List<TopSellingProduct> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return AppEmptyState(
        icon: Icons.bar_chart_outlined,
        title: 'No sales data for selected range.'.tr(),
        compact: true,
      );
    }

    final maxValue = products
        .map((e) => e.quantity)
        .fold<double>(0, (prev, v) => v > prev ? v : prev);
    final money = intl.NumberFormat.currency(symbol: '', decimalDigits: 2);
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = Theme.of(context).textTheme.titleMedium?.color;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBarWidth = constraints.maxWidth * 0.55;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: ListView.separated(
            primary: false,
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final p = products[index];
              final ratio = maxValue == 0 ? 0.0 : (p.quantity / maxValue);
              final barWidth = maxBarWidth * ratio.clamp(0.04, 1.0);

              return Row(
                children: [
                  SizedBox(
                    width: 150,
                    child: Text(
                      p.productName,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Tooltip(
                      message:
                          '${'Qty'.tr()}: ${p.quantity.toStringAsFixed(0)}\n${'Revenue'.tr()}: ${money.format(p.revenue)}',
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: barWidth,
                          height: 18,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 80,
                    child: Text(
                      p.quantity.toStringAsFixed(0),
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
