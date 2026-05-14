import 'package:flutter/material.dart';

class AppPageShell extends StatelessWidget {
  const AppPageShell({required this.child, required this.isCompact, super.key});

  final Widget child;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.all(isCompact ? 8 : 14),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(isCompact ? 10 : 12),
          child: child,
        ),
      ),
    );
  }
}

class AppSectionPanel extends StatelessWidget {
  const AppSectionPanel({
    required this.child,
    this.emphasis = false,
    this.padding,
    super.key,
  });

  final Widget child;
  final bool emphasis;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: emphasis
            ? colorScheme.surfaceContainerHighest
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}
