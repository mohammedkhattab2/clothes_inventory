import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:delta_erp/core/widgets/app_inline_loading_indicator.dart';
import 'package:delta_erp/features/products/presentation/widgets/products_summary_chip.dart';

class ProductsFiltersActionsSection extends StatelessWidget {
  const ProductsFiltersActionsSection({
    super.key,
    required this.isVeryDenseViewport,
    required this.canManageProducts,
    required this.stockFilterIndex,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.exportingPdf,
    required this.exportingCsv,
    required this.importingProducts,
    required this.savingImportTemplate,
    required this.lastExportPath,
    required this.onStockFilterChanged,
    required this.onRefresh,
    required this.onExportPdf,
    required this.onExportCsv,
    required this.onImportProducts,
    required this.onDownloadImportTemplate,
    required this.onOpenFolder,
  });

  final bool isVeryDenseViewport;
  final bool canManageProducts;
  final int stockFilterIndex;
  final int lowStockCount;
  final int outOfStockCount;
  final bool exportingPdf;
  final bool exportingCsv;
  final bool importingProducts;
  final bool savingImportTemplate;
  final String? lastExportPath;
  final ValueChanged<int> onStockFilterChanged;
  final VoidCallback onRefresh;
  final Future<void> Function() onExportPdf;
  final Future<void> Function() onExportCsv;
  final Future<void> Function() onImportProducts;
  final Future<void> Function() onDownloadImportTemplate;
  final Future<void> Function() onOpenFolder;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sectionGap = isVeryDenseViewport ? 6.0 : 8.0;
    final runGap = isVeryDenseViewport ? 6.0 : 8.0;

    ChipThemeData chipTheme(bool selected) {
      return ChipTheme.of(context).copyWith(
        selectedColor: colorScheme.primaryContainer,
        backgroundColor: colorScheme.surfaceContainerHigh,
        side: BorderSide(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.55)
              : colorScheme.outlineVariant,
        ),
        labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          color: selected
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurface,
        ),
      );
    }

    return Wrap(
      spacing: sectionGap,
      runSpacing: runGap,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ChipTheme(
          data: chipTheme(stockFilterIndex == 0),
          child: ChoiceChip(
            visualDensity: VisualDensity.compact,
            selected: stockFilterIndex == 0,
            label: Text('All'.tr()),
            onSelected: (_) => onStockFilterChanged(0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
          ),
        ),
        ChipTheme(
          data: chipTheme(stockFilterIndex == 1),
          child: ChoiceChip(
            visualDensity: VisualDensity.compact,
            selected: stockFilterIndex == 1,
            label: Text('Low Stock Only'.tr()),
            onSelected: (_) => onStockFilterChanged(1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
          ),
        ),
        ChipTheme(
          data: chipTheme(stockFilterIndex == 2),
          child: ChoiceChip(
            visualDensity: VisualDensity.compact,
            selected: stockFilterIndex == 2,
            label: Text('Out of Stock Only'.tr()),
            onSelected: (_) => onStockFilterChanged(2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
          ),
        ),
        ProductsSummaryChip(
          label: 'Low Stock'.tr(),
          value: lowStockCount.toString(),
          compact: true,
        ),
        ProductsSummaryChip(
          label: 'Out of Stock'.tr(),
          value: outOfStockCount.toString(),
          compact: true,
        ),
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          label: Text('Refresh'.tr()),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            foregroundColor: colorScheme.onSurface,
            side: BorderSide(color: colorScheme.outlineVariant),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isVeryDenseViewport ? 10.0 : 12.0,
              vertical: isVeryDenseViewport ? 7.0 : 8.0,
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: exportingPdf
              ? null
              : () async {
                  await onExportPdf();
                },
          icon: exportingPdf
              ? const AppInlineLoadingIndicator()
              : const Icon(Icons.picture_as_pdf_outlined),
          label: Text('PDF'.tr()),
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isVeryDenseViewport ? 10.0 : 12.0,
              vertical: isVeryDenseViewport ? 7.0 : 8.0,
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: !canManageProducts || savingImportTemplate
              ? null
              : () async {
                  await onDownloadImportTemplate();
                },
          icon: savingImportTemplate
              ? const AppInlineLoadingIndicator()
              : const Icon(Icons.file_download_outlined),
          label: Text('Download Product Template'.tr()),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            foregroundColor: colorScheme.onSurface,
            side: BorderSide(color: colorScheme.outlineVariant),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isVeryDenseViewport ? 10.0 : 12.0,
              vertical: isVeryDenseViewport ? 7.0 : 8.0,
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: !canManageProducts || importingProducts
              ? null
              : () async {
                  await onImportProducts();
                },
          icon: importingProducts
              ? const AppInlineLoadingIndicator()
              : const Icon(Icons.upload_file_outlined),
          label: Text('Import'.tr()),
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            backgroundColor: colorScheme.tertiary,
            foregroundColor: colorScheme.onTertiary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isVeryDenseViewport ? 10.0 : 12.0,
              vertical: isVeryDenseViewport ? 7.0 : 8.0,
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: exportingCsv
              ? null
              : () async {
                  await onExportCsv();
                },
          icon: exportingCsv
              ? const AppInlineLoadingIndicator()
              : const Icon(Icons.table_view_outlined),
          label: Text('CSV'.tr()),
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            backgroundColor: colorScheme.secondary,
            foregroundColor: colorScheme.onSecondary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isVeryDenseViewport ? 10.0 : 12.0,
              vertical: isVeryDenseViewport ? 7.0 : 8.0,
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: lastExportPath == null
              ? null
              : () async {
                  await onOpenFolder();
                },
          icon: const Icon(Icons.folder_open_outlined),
          label: Text('Open Folder'.tr()),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            foregroundColor: colorScheme.onSurface,
            side: BorderSide(color: colorScheme.outlineVariant),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isVeryDenseViewport ? 10.0 : 12.0,
              vertical: isVeryDenseViewport ? 7.0 : 8.0,
            ),
          ),
        ),
      ],
    );
  }
}
