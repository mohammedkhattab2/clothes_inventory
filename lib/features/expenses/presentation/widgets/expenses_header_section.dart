import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:clothes_inventory/core/widgets/app_brand_header.dart';
import 'package:clothes_inventory/core/widgets/app_inline_loading_indicator.dart';
import 'package:clothes_inventory/core/widgets/app_page_shell.dart';

class ExpensesHeaderSection extends StatelessWidget {
  const ExpensesHeaderSection({
    super.key,
    required this.isCompact,
    required this.loading,
    required this.printing,
    required this.exportingPdf,
    required this.exportingCsv,
    required this.lastExportPath,
    required this.onPrintReport,
    required this.onExportPdf,
    required this.onExportCsv,
    required this.onOpenExportFolder,
    required this.onRefresh,
  });

  final bool isCompact;
  final bool loading;
  final bool printing;
  final bool exportingPdf;
  final bool exportingCsv;
  final String? lastExportPath;
  final VoidCallback onPrintReport;
  final VoidCallback onExportPdf;
  final VoidCallback onExportCsv;
  final VoidCallback onOpenExportFolder;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return AppSectionPanel(
      emphasis: true,
      child: AppBrandHeader(
        pageTitle: 'Expenses'.tr(),
        description: 'Salaries, rent, and utilities expenses'.tr(),
        isDense: isCompact,
        actions: [
          FilledButton.icon(
            onPressed: loading || printing ? null : onPrintReport,
            icon: printing
                ? const AppInlineLoadingIndicator()
                : const Icon(Icons.print_outlined),
            label: Text('Print Report'.tr()),
          ),
          FilledButton.icon(
            onPressed: loading || exportingPdf ? null : onExportPdf,
            icon: exportingPdf
                ? const AppInlineLoadingIndicator()
                : const Icon(Icons.picture_as_pdf_outlined),
            label: Text('PDF'.tr()),
          ),
          FilledButton.icon(
            onPressed: loading || exportingCsv ? null : onExportCsv,
            icon: exportingCsv
                ? const AppInlineLoadingIndicator()
                : const Icon(Icons.file_download_outlined),
            label: Text('CSV'.tr()),
          ),
          if (lastExportPath != null)
            OutlinedButton.icon(
              onPressed: onOpenExportFolder,
              icon: const Icon(Icons.folder_open_outlined),
              label: Text('Open Folder'.tr()),
            ),
          FilledButton.icon(
            onPressed: loading ? null : onRefresh,
            icon: const Icon(Icons.refresh),
            label: Text('Refresh'.tr()),
          ),
        ],
      ),
    );
  }
}
