import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:delta_erp/core/widgets/app_page_shell.dart';

class ExpensesPaginationSection extends StatelessWidget {
  const ExpensesPaginationSection({
    super.key,
    required this.safePage,
    required this.totalPages,
    required this.showingFrom,
    required this.showingTo,
    required this.totalCount,
    required this.onPreviousPage,
    required this.onNextPage,
  });

  final int safePage;
  final int totalPages;
  final int showingFrom;
  final int showingTo;
  final int totalCount;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;

  @override
  Widget build(BuildContext context) {
    return AppSectionPanel(
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: safePage <= 0 ? null : onPreviousPage,
            icon: const Icon(Icons.chevron_left),
            label: Text('Previous'.tr()),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: safePage >= totalPages - 1 ? null : onNextPage,
            icon: const Icon(Icons.chevron_right),
            label: Text('Next'.tr()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${'Showing'.tr()} $showingFrom-$showingTo ${'of'.tr()} $totalCount | ${'Page'.tr()} ${safePage + 1}/$totalPages',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
