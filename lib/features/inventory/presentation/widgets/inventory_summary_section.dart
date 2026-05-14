import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class InventorySummarySection extends StatelessWidget {
  const InventorySummarySection({
    required this.totalCount,
    required this.lowCount,
    required this.outCount,
    required this.isUltraDense,
    super.key,
  });

  final int totalCount;
  final int lowCount;
  final int outCount;
  final bool isUltraDense;

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
