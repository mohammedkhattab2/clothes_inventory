import 'package:flutter/material.dart';

class ProductsSummaryChip extends StatelessWidget {
  const ProductsSummaryChip({
    super.key,
    required this.label,
    required this.value,
    this.color,
    this.valueColor,
    this.compact = false,
  });

  final String label;
  final String value;
  final Color? color;
  final Color? valueColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? Theme.of(context).colorScheme.surfaceContainerHigh;
    final fg = valueColor ?? Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(compact ? 10 : 999),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
