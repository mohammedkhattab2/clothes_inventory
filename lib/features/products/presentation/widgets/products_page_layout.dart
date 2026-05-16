import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:clothes_inventory/core/widgets/app_page_shell.dart';
import 'package:clothes_inventory/core/widgets/primary_button.dart';
import 'package:clothes_inventory/features/products/presentation/widgets/products_filters_actions_section.dart';
import 'package:clothes_inventory/features/products/presentation/widgets/products_last_export_label.dart';
import 'package:clothes_inventory/features/products/presentation/widgets/products_search_section.dart';
import 'package:clothes_inventory/features/products/presentation/widgets/products_summary_section.dart';
import 'package:clothes_inventory/features/products/presentation/widgets/products_table_shell.dart';

class ProductsPageLayout extends StatelessWidget {
  const ProductsPageLayout({
    super.key,
    required this.isCompact,
    required this.isDenseViewport,
    required this.isVeryDenseViewport,
    required this.nameController,
    required this.barcodeController,
    required this.totalProductsCount,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.stockFilterIndex,
    required this.exportingPdf,
    required this.exportingCsv,
    required this.importingProducts,
    required this.savingImportTemplate,
    required this.lastExportPath,
    required this.selectionMode,
    required this.selectedCount,
    required this.tableWidget,
    required this.error,
    required this.loading,
    required this.onAddProduct,
    required this.onNameChanged,
    required this.onBarcodeChanged,
    required this.onClearSearch,
    required this.onStockFilterChanged,
    required this.onRefresh,
    required this.onExportPdf,
    required this.onExportCsv,
    required this.onImportProducts,
    required this.onDownloadImportTemplate,
    required this.onOpenFolder,
    required this.onToggleSelectionMode,
    required this.onDeleteSelected,
  });

  final bool isCompact;
  final bool isDenseViewport;
  final bool isVeryDenseViewport;
  final TextEditingController nameController;
  final TextEditingController barcodeController;
  final int totalProductsCount;
  final int lowStockCount;
  final int outOfStockCount;
  final int stockFilterIndex;
  final bool exportingPdf;
  final bool exportingCsv;
  final bool importingProducts;
  final bool savingImportTemplate;
  final String? lastExportPath;
  final bool selectionMode;
  final int selectedCount;
  final Widget tableWidget;
  final String? error;
  final bool loading;
  final VoidCallback onAddProduct;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onBarcodeChanged;
  final Future<void> Function() onClearSearch;
  final ValueChanged<int> onStockFilterChanged;
  final VoidCallback onRefresh;
  final Future<void> Function() onExportPdf;
  final Future<void> Function() onExportCsv;
  final Future<void> Function() onImportProducts;
  final Future<void> Function() onDownloadImportTemplate;
  final Future<void> Function() onOpenFolder;
  final VoidCallback onToggleSelectionMode;
  final Future<void> Function() onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    final sectionGap = isVeryDenseViewport
        ? 6.0
        : (isDenseViewport ? 8.0 : 10.0);

    return AppPageShell(
      isCompact: isCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Products'.tr(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              PrimaryButton(
                label: 'Add Product'.tr(),
                icon: Icons.add,
                onPressed: onAddProduct,
              ),
            ],
          ),
          SizedBox(height: sectionGap),
          AppSectionPanel(
            child: ProductsSearchSection(
              isVeryDenseViewport: isVeryDenseViewport,
              nameController: nameController,
              barcodeController: barcodeController,
              onNameChanged: onNameChanged,
              onBarcodeChanged: onBarcodeChanged,
              onClearSearch: onClearSearch,
            ),
          ),
          SizedBox(height: sectionGap),
          AppSectionPanel(
            child: ProductsFiltersActionsSection(
              isVeryDenseViewport: isVeryDenseViewport,
              stockFilterIndex: stockFilterIndex,
              lowStockCount: lowStockCount,
              outOfStockCount: outOfStockCount,
              exportingPdf: exportingPdf,
              exportingCsv: exportingCsv,
              importingProducts: importingProducts,
              savingImportTemplate: savingImportTemplate,
              lastExportPath: lastExportPath,
              onStockFilterChanged: onStockFilterChanged,
              onRefresh: onRefresh,
              onExportPdf: onExportPdf,
              onExportCsv: onExportCsv,
              onImportProducts: onImportProducts,
              onDownloadImportTemplate: onDownloadImportTemplate,
              onOpenFolder: onOpenFolder,
            ),
          ),
          SizedBox(height: sectionGap),
          ProductsLastExportLabel(lastExportPath: lastExportPath),
          AppSectionPanel(
            child: ProductsSummarySection(
              isVeryDenseViewport: isVeryDenseViewport,
              totalProductsCount: totalProductsCount,
              lowStockCount: lowStockCount,
              outOfStockCount: outOfStockCount,
              selectionMode: selectionMode,
              selectedCount: selectedCount,
              onToggleSelectionMode: onToggleSelectionMode,
              onDeleteSelected: onDeleteSelected,
            ),
          ),
          SizedBox(height: sectionGap),
          ProductsTableShell(
            loading: loading,
            error: error,
            tableWidget: tableWidget,
          ),
        ],
      ),
    );
  }
}
