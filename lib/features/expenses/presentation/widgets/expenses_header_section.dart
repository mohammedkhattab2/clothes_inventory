import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:delta_erp/core/widgets/app_inline_loading_indicator.dart';
import 'package:delta_erp/core/widgets/app_page_shell.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    return AppSectionPanel(
      emphasis: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Expenses'.tr(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Salaries, rent, and utilities expenses'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
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
        ],
      ),
    );
  }
}
