import 'package:flutter/material.dart';

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  const SecondaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.padding,
    this.borderRadius,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foregroundColor = colorScheme.onSurface;

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.tune),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius ?? BorderRadius.circular(12.0),
        ),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1.2),
        foregroundColor: foregroundColor,
      ),
      label: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w600, color: foregroundColor),
      ),
    );
  }
}
