import 'package:flutter/material.dart';
import 'package:delta_erp/core/widgets/app_loading_indicator.dart';

class ProductsTableShell extends StatelessWidget {
  const ProductsTableShell({
    super.key,
    required this.loading,
    required this.error,
    required this.tableWidget,
  });

  final bool loading;
  final String? error;
  final Widget tableWidget;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final veryDense = MediaQuery.sizeOf(context).height < 700;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (error != null)
            Container(
              width: double.infinity,
              margin: EdgeInsets.only(bottom: veryDense ? 6 : 8),
              padding: EdgeInsets.symmetric(
                horizontal: veryDense ? 10 : 12,
                vertical: veryDense ? 7 : 8,
              ),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colorScheme.error.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                error!,
                style: TextStyle(
                  color: colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colorScheme.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: loading ? const AppLoadingIndicator() : tableWidget,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
