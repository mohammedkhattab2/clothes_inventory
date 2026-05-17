import 'package:flutter/material.dart';
import 'package:delta_erp/core/config/company_settings.dart';
import 'package:delta_erp/core/config/company_settings_service.dart';
import 'package:delta_erp/services/di/service_locator.dart';

class AppBrandHeader extends StatelessWidget {
  const AppBrandHeader({
    required this.pageTitle,
    this.pageSubtitle,
    this.description,
    this.actions,
    this.isDense = false,
    this.slim = false,
    this.companyOverride,
    super.key,
  });

  final String pageTitle;
  final String? pageSubtitle;
  final String? description;
  final List<Widget>? actions;
  final bool isDense;
  final bool slim;
  final CompanySettings? companyOverride;

  @override
  Widget build(BuildContext context) {
    final override = companyOverride;
    if (override != null) {
      return _buildContent(context, override);
    }

    final settingsListenable =
        getIt<CompanySettingsService>().settingsListenable;

    return ValueListenableBuilder<CompanySettings>(
      valueListenable: settingsListenable,
      builder: (context, company, _) {
        return _buildContent(context, company);
      },
    );
  }

  Widget _buildContent(BuildContext context, CompanySettings company) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;

    final titleStyle = theme.textTheme.headlineSmall?.copyWith(
      color: colorScheme.onPrimaryContainer,
      fontWeight: FontWeight.w900,
    );
    final subtitleStyle = theme.textTheme.titleMedium?.copyWith(
      color: colorScheme.onPrimaryContainer.withValues(alpha: 0.85),
      fontWeight: FontWeight.w700,
    );

    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
      fontWeight: FontWeight.w600,
    );

    final descriptionStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onPrimaryContainer.withValues(alpha: 0.78),
    );

    final meta = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MetaChip(
          icon: Icons.call_outlined,
          label: company.phonesText,
          isDarkMode: isDarkMode,
        ),
        _MetaChip(
          icon: Icons.location_on_outlined,
          label: company.address,
          isDarkMode: isDarkMode,
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(slim ? (isDense ? 8 : 10) : (isDense ? 12 : 14)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withValues(
              alpha: isDarkMode ? 0.68 : 0.92,
            ),
            colorScheme.secondaryContainer.withValues(
              alpha: isDarkMode ? 0.6 : 0.86,
            ),
          ],
          stops: const [0.2, 1],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (slim) {
            final slimTitleStyle = theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            );
            final slimSubtitleStyle = theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            );
            final slimActions = (actions == null || actions!.isEmpty)
                ? const SizedBox.shrink()
                : Wrap(spacing: 8, runSpacing: 8, children: actions!);

            return Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(pageTitle, style: slimTitleStyle),
                      if (description != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          description!,
                          style: slimSubtitleStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (actions != null && actions!.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: slimActions,
                  ),
                ],
              ],
            );
          }

          final compact = constraints.maxWidth < 980;
          final actionsWidget = (actions == null || actions!.isEmpty)
              ? const SizedBox.shrink()
              : Wrap(spacing: 8, runSpacing: 8, children: actions!);

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(company.name, style: titleStyle),
                if (pageSubtitle != null) ...[
                  const SizedBox(height: 5),
                  Text(pageSubtitle!, style: subtitleStyle),
                ],
                const SizedBox(height: 5),
                Text(pageTitle, style: subtitleStyle),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    description!,
                    style: descriptionStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                DefaultTextStyle(
                  style: metaStyle ?? const TextStyle(),
                  child: meta,
                ),
                if (actions != null && actions!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  actionsWidget,
                ],
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(company.name, style: titleStyle),
                    if (pageSubtitle != null) ...[
                      const SizedBox(height: 5),
                      Text(pageSubtitle!, style: subtitleStyle),
                    ],
                    const SizedBox(height: 5),
                    Text(pageTitle, style: subtitleStyle),
                    if (description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        description!,
                        style: descriptionStyle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 10),
                    DefaultTextStyle(
                      style: metaStyle ?? const TextStyle(),
                      child: meta,
                    ),
                  ],
                ),
              ),
              if (actions != null && actions!.isNotEmpty) ...[
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: actionsWidget,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.isDarkMode = false,
  });

  final IconData icon;
  final String label;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.onPrimaryContainer.withValues(
          alpha: isDarkMode ? 0.14 : 0.08,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.onPrimaryContainer.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: colorScheme.onPrimaryContainer.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
