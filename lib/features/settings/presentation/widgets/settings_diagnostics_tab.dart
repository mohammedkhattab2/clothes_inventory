import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:delta_erp/features/settings/presentation/widgets/settings_luxury_components.dart';

class SettingsSystemDiagnosticsData {
  const SettingsSystemDiagnosticsData({
    required this.appDataPath,
    required this.databasePath,
    required this.logsPath,
    required this.tempPath,
    required this.healthOk,
    required this.healthMessage,
    required this.ocrReady,
    required this.ocrVersion,
    required this.lastOcrErrorCode,
    required this.lastOcrErrorType,
    required this.lastOcrErrorSeverity,
    required this.generalError,
  });

  factory SettingsSystemDiagnosticsData.fallback() {
    return const SettingsSystemDiagnosticsData(
      appDataPath: 'n/a',
      databasePath: 'n/a',
      logsPath: 'n/a',
      tempPath: 'n/a',
      healthOk: false,
      healthMessage: 'Not available',
      ocrReady: false,
      ocrVersion: 'Not available',
      lastOcrErrorCode: null,
      lastOcrErrorType: null,
      lastOcrErrorSeverity: null,
      generalError: null,
    );
  }

  final String appDataPath;
  final String databasePath;
  final String logsPath;
  final String tempPath;
  final bool healthOk;
  final String healthMessage;
  final bool ocrReady;
  final String ocrVersion;
  final String? lastOcrErrorCode;
  final String? lastOcrErrorType;
  final String? lastOcrErrorSeverity;
  final String? generalError;
}

class SettingsDiagnosticsTab extends StatelessWidget {
  const SettingsDiagnosticsTab({
    required this.diagnosticsFuture,
    required this.onRefresh,
    required this.onCopyDiagnostics,
    required this.onOpenAppDataFolder,
    required this.onResetApplicationData,
    required this.resettingAppData,
    required this.resetBlocked,
    required this.resetBlockedMessage,
    super.key,
  });

  final Future<SettingsSystemDiagnosticsData> diagnosticsFuture;
  final VoidCallback onRefresh;
  final Future<void> Function(SettingsSystemDiagnosticsData data)
  onCopyDiagnostics;
  final Future<void> Function(SettingsSystemDiagnosticsData data)
  onOpenAppDataFolder;
  final Future<void> Function() onResetApplicationData;
  final bool resettingAppData;
  final bool resetBlocked;
  final String? resetBlockedMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      child: Column(
        children: [
          SettingsLuxurySectionCard(
            title: 'System Diagnostics'.tr(),
            subtitle: 'Runtime health checks and environment details'.tr(),
            icon: Icons.health_and_safety_outlined,
            child: FutureBuilder<SettingsSystemDiagnosticsData>(
              future: diagnosticsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Card(
                    child: ListTile(
                      leading: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      title: Text('System Diagnostics'.tr()),
                      subtitle: Text('Loading runtime diagnostics...'.tr()),
                    ),
                  );
                }

                final data =
                    snapshot.data ?? SettingsSystemDiagnosticsData.fallback();
                final healthTone = data.healthOk
                    ? Colors.green.shade700
                    : colorScheme.error;
                final ocrTone = data.ocrReady
                    ? Colors.green.shade700
                    : colorScheme.error;

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.outlineVariant),
                    color: colorScheme.surface,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.health_and_safety_outlined,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'System Diagnostics'.tr(),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Refresh'.tr(),
                            onPressed: onRefresh,
                            icon: const Icon(Icons.refresh_outlined),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _MetricRow(
                        label: 'AppData Directory'.tr(),
                        value: data.appDataPath,
                      ),
                      _MetricRow(
                        label: 'Database Path'.tr(),
                        value: data.databasePath,
                      ),
                      _MetricRow(label: 'Logs Path'.tr(), value: data.logsPath),
                      _MetricRow(
                        label: 'Temp Directory'.tr(),
                        value: data.tempPath,
                      ),
                      _MetricRow(
                        label: 'Health Status'.tr(),
                        value: data.healthOk
                            ? 'Healthy'.tr()
                            : 'Error: ${data.healthMessage}'.tr(),
                        valueColor: healthTone,
                      ),
                      _MetricRow(
                        label: 'OCR Status'.tr(),
                        value: data.ocrReady
                            ? 'OCR Ready'.tr()
                            : 'OCR Not Ready'.tr(),
                        valueColor: ocrTone,
                      ),
                      _MetricRow(
                        label: 'Tesseract Version'.tr(),
                        value: data.ocrVersion,
                      ),
                      if (data.lastOcrErrorCode != null ||
                          data.lastOcrErrorType != null ||
                          data.lastOcrErrorSeverity != null)
                        _MetricRow(
                          label: 'Last OCR Error'.tr(),
                          value:
                              'code: ${data.lastOcrErrorCode ?? 'n/a'} | type: ${data.lastOcrErrorType ?? 'n/a'} | severity: ${data.lastOcrErrorSeverity ?? 'n/a'}',
                          valueColor: colorScheme.error,
                        ),
                      if (data.generalError != null &&
                          data.generalError!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 2),
                          child: Text(
                            'Diagnostics warning: ${data.generalError}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => onCopyDiagnostics(data),
                            icon: const Icon(Icons.copy_outlined),
                            label: Text('Copy Diagnostics'.tr()),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => onOpenAppDataFolder(data),
                            icon: const Icon(Icons.folder_open_outlined),
                            label: Text('Open AppData Folder'.tr()),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SettingsLuxurySectionCard(
            title: 'System'.tr(),
            subtitle: 'Danger zone'.tr(),
            icon: Icons.warning_amber_rounded,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.error.withValues(alpha: 0.35),
                ),
                color: colorScheme.errorContainer.withValues(alpha: 0.25),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This action permanently deletes all application data.'
                        .tr(),
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (resetBlockedMessage != null &&
                      resetBlockedMessage!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      resetBlockedMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: (resettingAppData || resetBlocked)
                        ? null
                        : onResetApplicationData,
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                    ),
                    icon: resettingAppData
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.delete_forever_outlined),
                    label: Text('Reset Application Data'.tr()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
        color: colorScheme.surfaceContainerLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          SelectableText(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: valueColor,
              fontWeight: valueColor != null ? FontWeight.w600 : null,
            ),
          ),
        ],
      ),
    );
  }
}
