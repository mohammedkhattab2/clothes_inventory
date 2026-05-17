import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

IconData _hubStatusIcon(String status) {
  switch (status.trim().toLowerCase()) {
    case 'completed':
      return Icons.verified_outlined;
    case 'partial':
      return Icons.balance_outlined;
    case 'pending':
      return Icons.pending_actions_outlined;
    case 'cancelled':
      return Icons.cancel_outlined;
    default:
      return Icons.receipt_long_outlined;
  }
}

IconData _hubPaymentIcon(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return Icons.payments_outlined;
  }
  switch (raw.trim().toLowerCase()) {
    case 'cash':
      return Icons.payments_outlined;
    case 'vodafone_cash':
      return Icons.phone_android_outlined;
    case 'visa':
      return Icons.credit_card_outlined;
    case 'cash_and_wallet':
    case 'cash_wallet':
      return Icons.paid_outlined;
    default:
      return Icons.account_balance_wallet_outlined;
  }
}

/// Premium, static list tile for sales/purchase invoice rows (no implicit animations).
class InvoiceHubListCard extends StatelessWidget {
  const InvoiceHubListCard({
    super.key,
    required this.invoiceNumberDisplay,
    required this.accountName,
    required this.totalAmount,
    required this.statusRaw,
    required this.statusLabel,
    required this.statusColor,
    required this.paymentMethodRaw,
    required this.paymentLabel,
    required this.createdAt,
    required this.highlighted,
    required this.onTap,
    this.createdByLine,
    this.lastModifiedByLine,
  });

  /// Full displayed invoice reference (e.g. formatted number or label).
  final String invoiceNumberDisplay;
  final String accountName;
  final double totalAmount;
  final String statusRaw;
  final String statusLabel;
  final Color statusColor;
  final String? paymentMethodRaw;
  final String paymentLabel;
  final DateTime createdAt;
  final bool highlighted;
  final VoidCallback onTap;
  final String? createdByLine;
  final String? lastModifiedByLine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final locale = context.locale.toString();

    final dateStr = DateFormat.yMMMMd(locale).format(createdAt);
    final timeStr = DateFormat.Hm(locale).format(createdAt);

    final accent = statusColor;
    final barColor = Color.lerp(accent, scheme.surface, 0.45) ?? accent;

    final baseGradient = LinearGradient(
      begin: AlignmentDirectional.topStart,
      end: AlignmentDirectional.bottomEnd,
      colors: highlighted
          ? [
              scheme.primaryContainer.withValues(alpha: 0.55),
              scheme.tertiaryContainer.withValues(alpha: 0.35),
              scheme.surfaceContainerLow.withValues(alpha: 0.92),
            ]
          : [
              scheme.surfaceContainerHighest.withValues(alpha: 0.55),
              scheme.primaryContainer.withValues(alpha: 0.18),
              scheme.surfaceContainerLow.withValues(alpha: 0.95),
            ],
      stops: const [0.0, 0.45, 1.0],
    );

    final borderColor = highlighted
        ? scheme.primary.withValues(alpha: 0.85)
        : scheme.outlineVariant.withValues(alpha: 0.88);
    final borderWidth = highlighted ? 1.5 : 1.0;

    final radius = BorderRadius.circular(13);

    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(
                  alpha: highlighted ? 0.08 : 0.04,
                ),
                blurRadius: highlighted ? 10 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          barColor,
                          accent.withValues(alpha: 0.75),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(gradient: baseGradient),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          9,
                          9,
                          highlighted ? 8 : 9,
                          9,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'invoices.hub.invoice_number_label'.tr(),
                                        style: textTheme.labelSmall?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        invoiceNumberDisplay,
                                        style: textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          height: 1.12,
                                          letterSpacing: -0.15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (highlighted)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 2,
                                        ),
                                        child: Icon(
                                          Icons.push_pin_rounded,
                                          size: 17,
                                          color: scheme.primary,
                                        ),
                                      ),
                                    Text(
                                      totalAmount.toStringAsFixed(2),
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'Total'.tr(),
                                      style: textTheme.labelSmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            Row(
                              children: [
                                Icon(
                                  Icons.business_outlined,
                                  size: 15,
                                  color: scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    accountName,
                                    style: textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (createdByLine != null &&
                                createdByLine!.trim().isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    size: 14,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      createdByLine!,
                                      style: textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (lastModifiedByLine != null &&
                                lastModifiedByLine!.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.edit_note_outlined,
                                    size: 14,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      lastModifiedByLine!,
                                      style: textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 14,
                                  color: scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    dateStr,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.schedule_outlined,
                                  size: 14,
                                  color: scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  timeStr,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _HubChip(
                                  icon: _hubStatusIcon(statusRaw),
                                  label: statusLabel,
                                  foreground: statusColor,
                                  background: statusColor.withValues(
                                    alpha: 0.12,
                                  ),
                                  border: statusColor.withValues(alpha: 0.35),
                                ),
                                _HubChip(
                                  icon: _hubPaymentIcon(paymentMethodRaw),
                                  label:
                                      '${'Payment method'.tr()}: $paymentLabel',
                                  foreground: scheme.onTertiaryContainer,
                                  background: scheme.tertiaryContainer
                                      .withValues(alpha: 0.92),
                                  border: scheme.outline.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HubChip extends StatelessWidget {
  const _HubChip({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
    required this.border,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;
  final Color border;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
        color: background,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 5),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
