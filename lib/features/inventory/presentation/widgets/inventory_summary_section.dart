import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class InventorySummarySection extends StatelessWidget {
  const InventorySummarySection({
    required this.totalCount,
    required this.lowCount,
    required this.outCount,
    required this.totalCost,
    required this.totalRetailSales,
    required this.totalProfit,
    required this.isUltraDense,
    super.key,
  });

  final int totalCount;
  final int lowCount;
  final int outCount;
  final double totalCost;
  final double totalRetailSales;
  final double totalProfit;
  final bool isUltraDense;

  static final _moneyFormat = NumberFormat.currency(symbol: '', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: isUltraDense ? 4 : 6,
      children: [
        _CountChip(
          label: 'Total Products'.tr(),
          value: totalCount,
          isUltraDense: isUltraDense,
        ),
        _CountChip(
          label: 'Low Stock'.tr(),
          value: lowCount,
          isUltraDense: isUltraDense,
        ),
        _CountChip(
          label: 'Out of Stock'.tr(),
          value: outCount,
          isUltraDense: isUltraDense,
        ),
        _ValueChip(
          label: 'inventory.total_cost'.tr(),
          value: _moneyFormat.format(totalCost),
          isUltraDense: isUltraDense,
          icon: Icons.payments_outlined,
        ),
        _ValueChip(
          label: 'inventory.total_retail_sales'.tr(),
          value: _moneyFormat.format(totalRetailSales),
          isUltraDense: isUltraDense,
          icon: Icons.sell_outlined,
        ),
        _ValueChip(
          label: 'inventory.total_profit'.tr(),
          value: _moneyFormat.format(totalProfit),
          isUltraDense: isUltraDense,
          icon: Icons.trending_up_outlined,
          valueColor: totalProfit >= 0 ? null : Theme.of(context).colorScheme.error,
        ),
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.value,
    required this.isUltraDense,
  });

  final String label;
  final int value;
  final bool isUltraDense;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isUltraDense ? 8 : 10,
        vertical: isUltraDense ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: isUltraDense ? 14 : 15,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: isUltraDense ? 11 : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueChip extends StatelessWidget {
  const _ValueChip({
    required this.label,
    required this.value,
    required this.isUltraDense,
    required this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool isUltraDense;
  final IconData icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isUltraDense ? 8 : 10,
        vertical: isUltraDense ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isUltraDense ? 14 : 15,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: isUltraDense ? 11 : null,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
