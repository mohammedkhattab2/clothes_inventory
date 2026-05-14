import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:clothes_inventory/core/widgets/app_empty_state.dart';
import 'package:clothes_inventory/features/dashboard/data/dashboard_repository.dart';
import 'package:clothes_inventory/features/dashboard/presentation/widgets/dashboard_chart_card.dart';

class DashboardTopSuppliersCard extends StatelessWidget {
  const DashboardTopSuppliersCard({required this.suppliers, super.key});

  final List<TopSupplier> suppliers;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final veryDense = MediaQuery.sizeOf(context).height < 700;

    final currency = intl.NumberFormat.currency(symbol: '', decimalDigits: 2);

    return DashboardChartCard(
      title: 'Top Suppliers by Purchase Volume'.tr(),
      icon: Icons.handshake_outlined,
      child: suppliers.isEmpty
          ? Padding(
              padding: EdgeInsets.symmetric(vertical: veryDense ? 6 : 10),
              child: AppEmptyState(
                icon: Icons.handshake_outlined,
                title: 'No supplier data for selected range.'.tr(),
                compact: true,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: suppliers.asMap().entries.map((entry) {
                final index = entry.key;
                final supplier = entry.value;
                return Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: veryDense ? 6 : 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              supplier.supplierName,
                              style:
                                  (veryDense
                                          ? Theme.of(
                                              context,
                                            ).textTheme.titleSmall
                                          : Theme.of(
                                              context,
                                            ).textTheme.titleMedium)
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: colorScheme.onSurface,
                                      ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            currency.format(supplier.volume),
                            style:
                                (veryDense
                                        ? Theme.of(context).textTheme.titleSmall
                                        : Theme.of(
                                            context,
                                          ).textTheme.titleMedium)
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: colorScheme.primary,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    if (index < suppliers.length - 1)
                      Divider(
                        height: 1,
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                  ],
                );
              }).toList(),
            ),
    );
  }
}
