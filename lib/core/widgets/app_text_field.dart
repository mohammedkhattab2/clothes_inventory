import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? hint;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final EdgeInsetsGeometry? contentPadding;
  final BorderRadius? focusedBorderRadius;

  const AppTextField({
    required this.label,
    this.controller,
    this.hint,
    this.keyboardType,
    this.onChanged,
    this.enabled = true,
    this.contentPadding,
    this.focusedBorderRadius,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final fillColor = colorScheme.surfaceContainerHighest;
    final labelColor = colorScheme.onSurfaceVariant;
    final hintColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.75);
    final borderColor = colorScheme.outlineVariant;
    final focusedBorderColor = colorScheme.primary;

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      enabled: enabled,
      cursorColor: focusedBorderColor,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: fillColor,
        contentPadding:
            contentPadding ??
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(color: borderColor, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(color: borderColor, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: focusedBorderRadius ?? BorderRadius.circular(10.0),
          borderSide: BorderSide(color: focusedBorderColor, width: 2.0),
        ),
        labelStyle: TextStyle(color: labelColor, fontWeight: FontWeight.w600),
        hintStyle: TextStyle(color: hintColor),
      ),
    );
  }
}
