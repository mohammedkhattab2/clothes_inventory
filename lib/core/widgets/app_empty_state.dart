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
    final maxWidth = compact ? 380.0 : 460.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight;
        final tightHeight = maxH.isFinite && maxH > 0 && maxH < 140;
        final iconSize =
            compact ? (tightHeight ? 20.0 : 24.0) : (tightHeight ? 24.0 : 30.0);
        final horizontalPadding = compact ? 14.0 : 18.0;
        final verticalPadding = tightHeight
            ? 8.0
            : (compact ? 14.0 : 20.0);
        final gapAfterIcon = tightHeight
            ? 4.0
            : (compact ? 8.0 : 10.0);

        final card = Container(
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
              SizedBox(height: gapAfterIcon),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: tightHeight ? 2 : null,
                overflow: tightHeight ? TextOverflow.ellipsis : null,
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
                  maxLines: tightHeight ? 2 : null,
                  overflow: tightHeight ? TextOverflow.ellipsis : null,
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
        );

        if (maxH.isFinite && maxH > 0) {
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxH),
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: card,
                ),
              ),
            ),
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: card,
          ),
        );
      },
    );
  }
}
