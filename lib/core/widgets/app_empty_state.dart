import 'package:flutter/material.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.title,
    this.subtitle,
    this.icon,
    this.action,
    this.compact = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final iconSize = compact ? 24.0 : 30.0;
    final horizontalPadding = compact ? 14.0 : 18.0;
    final verticalPadding = compact ? 14.0 : 20.0;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: compact ? 380 : 460),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon ?? Icons.inbox_outlined,
                size: iconSize,
                color: colorScheme.onSurfaceVariant,
              ),
              SizedBox(height: compact ? 8 : 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style:
                    (compact
                            ? theme.textTheme.labelLarge
                            : theme.textTheme.titleMedium)
                        ?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
              ),
              if (subtitle != null) ...[
                SizedBox(height: compact ? 4 : 6),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (action != null) ...[
                SizedBox(height: compact ? 10 : 12),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
