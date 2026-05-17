import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class SalesInvoiceDetailsHeader extends StatelessWidget {
  const SalesInvoiceDetailsHeader({
    super.key,
    required this.invoiceTitle,
    required this.accountName,
    required this.paymentStatusLabel,
    required this.paymentStatusColor,
    this.createdByLine,
    this.lastModifiedByLine,
  });

  final String invoiceTitle;
  final String accountName;
  final String paymentStatusLabel;
  final Color paymentStatusColor;
  final String? createdByLine;
  final String? lastModifiedByLine;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.9),
            colorScheme.secondaryContainer.withValues(alpha: 0.72),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            color: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invoice Details'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  '$invoiceTitle • $accountName',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.88,
                    ),
                  ),
                ),
                if (createdByLine != null &&
                    createdByLine!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    createdByLine!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimaryContainer.withValues(
                        alpha: 0.82,
                      ),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (lastModifiedByLine != null &&
                    lastModifiedByLine!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    lastModifiedByLine!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimaryContainer.withValues(
                        alpha: 0.82,
                      ),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: paymentStatusColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: paymentStatusColor.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              paymentStatusLabel,
              style: TextStyle(
                fontSize: 11,
                color: paymentStatusColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
