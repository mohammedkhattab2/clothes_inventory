import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:clothes_inventory/features/license/domain/license_models.dart';
import 'package:clothes_inventory/features/settings/presentation/widgets/settings_luxury_components.dart';

enum LicenseHistoryFilter { all, success, failed }

class SettingsLicenseTab extends StatelessWidget {
  const SettingsLicenseTab({
    required this.licenseStatusFuture,
    required this.machineCodeFuture,
    required this.machineHashFuture,
    required this.activationLogsFuture,
    required this.activationHistoryFilter,
    required this.onFilterChanged,
    required this.activationStatusLabel,
    required this.onCopyToClipboard,
    required this.onOpenRenewDialog,
    required this.onCopyTxt,
    required this.onCopyCsv,
    required this.onExportTxt,
    required this.onExportCsv,
    super.key,
  });

  final Future<LicenseValidationResult> licenseStatusFuture;
  final Future<String> machineCodeFuture;
  final Future<String> machineHashFuture;
  final Future<List<LicenseActivationLogEntry>> activationLogsFuture;
  final LicenseHistoryFilter activationHistoryFilter;
  final ValueChanged<LicenseHistoryFilter> onFilterChanged;
  final String Function(bool success) activationStatusLabel;
  final Future<void> Function(String value) onCopyToClipboard;
  final VoidCallback onOpenRenewDialog;
  final Future<void> Function(List<LicenseActivationLogEntry> logs) onCopyTxt;
  final Future<void> Function(List<LicenseActivationLogEntry> logs) onCopyCsv;
  final Future<void> Function(List<LicenseActivationLogEntry> logs) onExportTxt;
  final Future<void> Function(List<LicenseActivationLogEntry> logs) onExportCsv;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SettingsLuxurySectionCard(
        title: 'License and Activation'.tr(),
        subtitle: 'Manage activation, machine identity, and audit history'.tr(),
        icon: Icons.verified_user_outlined,
        child: _buildLicenseStatusCard(context),
      ),
    );
  }

  Widget _buildLicenseStatusCard(BuildContext context) {
    return FutureBuilder<LicenseValidationResult>(
      future: licenseStatusFuture,
      builder: (context, licenseSnapshot) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        if (licenseSnapshot.connectionState == ConnectionState.waiting) {
          return ListTile(
            leading: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            title: Text('license.checking_status'.tr()),
          );
        }

        final result = licenseSnapshot.data;
        final payload = result?.payload;
        final isActive = result?.isValid == true;
        final isReadOnly = result?.isReadOnly == true;
        final isTrial = result?.isTrial == true;
        final tone = isActive
            ? (isReadOnly ? Colors.orange.shade700 : Colors.green.shade700)
            : theme.colorScheme.error;

        final headline = !isActive
            ? 'license.inactive'.tr()
            : (isTrial
                  ? 'license.trial_active'.tr()
                  : (isReadOnly
                        ? 'license.active_read_only'.tr()
                        : 'license.active'.tr()));

        final subtitle = !isActive
            ? _statusMessage(result)
            : (isTrial
                  ? 'license.trial_days_left'.tr(
                      namedArgs: {'days': '${result?.trialDaysLeft ?? 0}'},
                    )
                  : '${'license.customer'.tr()}: ${payload?.customerName ?? '-'} | ${'license.expires'.tr()}: ${payload?.expiresAt.toLocal().toString().split(' ').first ?? '-'}');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tone.withValues(alpha: 0.35)),
                color: tone.withValues(alpha: 0.08),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MiniCaption(
                    text: 'license.details'.tr(),
                    icon: Icons.workspace_premium_outlined,
                    color: tone,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    headline,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: tone,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle),
                  if (!isTrial &&
                      payload?.licenseId != null &&
                      payload!.licenseId.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${'license.license_id'.tr()}: ${payload.licenseId}',
                      ),
                    ),
                  if (!isTrial && payload != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${'license.issued_at'.tr()}: ${payload.issuedAt.toLocal().toString().split(' ').first}',
                      ),
                    ),
                  if (isTrial && result?.trialEndsAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'license.trial_ends_at'.tr(
                          namedArgs: {
                            'date': result!.trialEndsAt!
                                .toLocal()
                                .toString()
                                .split(' ')
                                .first,
                          },
                        ),
                      ),
                    ),
                  if (isReadOnly && result?.graceDaysLeft != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${'license.grace_days_left'.tr()}: ${result!.graceDaysLeft}',
                      style: theme.textTheme.bodySmall?.copyWith(color: tone),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<(String, String)>(
              future: _machineIdentity(),
              builder: (context, snapshot) {
                final machineCode = snapshot.data?.$1 ?? '-';
                final machineHash = snapshot.data?.$2 ?? '-';

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.outlineVariant),
                    color: colorScheme.surfaceContainerLow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MiniCaption(
                        text: 'Machine Identity'.tr(),
                        icon: Icons.memory_outlined,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 10),
                      _SelectableInfoBlock(
                        label: 'license.machine_code'.tr(),
                        value: machineCode,
                      ),
                      const SizedBox(height: 8),
                      _SelectableInfoBlock(
                        label: 'license.machine_hash'.tr(),
                        value: machineHash,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: machineCode == '-'
                                ? null
                                : () => onCopyToClipboard(machineCode),
                            icon: const Icon(Icons.copy_outlined),
                            label: Text('license.copy_code'.tr()),
                          ),
                          OutlinedButton.icon(
                            onPressed: machineHash == '-'
                                ? null
                                : () => onCopyToClipboard(machineHash),
                            icon: const Icon(Icons.copy_all_outlined),
                            label: Text('license.copy_hash'.tr()),
                          ),
                          FilledButton.icon(
                            onPressed: onOpenRenewDialog,
                            icon: const Icon(Icons.vpn_key_outlined),
                            label: Text('license.renew'.tr()),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildActivationHistoryCard(context),
          ],
        );
      },
    );
  }

  String _statusMessage(LicenseValidationResult? result) {
    final code = result?.code;
    switch (code) {
      case 'trial_locked':
        return 'license.trial_locked'.tr();
      case 'trial_tampered':
        return 'license.trial_tampered'.tr();
      case 'trial_expired':
        return 'license.trial_expired'.tr();
      case 'trial_error':
        return 'license.trial_error'.tr();
      case 'clock_rollback':
        return 'license.clock_rollback'.tr();
      case 'machine_mismatch':
        return 'license.machine_mismatch'.tr();
      case 'signature_invalid':
      case 'invalid_format':
        return 'license.invalid'.tr();
      case 'license_expired':
        return 'license.expired'.tr();
      case 'no_license':
        return 'license.no_active'.tr();
      default:
        final fallback = result?.message;
        if (fallback == null || fallback.trim().isEmpty) {
          return 'license.no_active'.tr();
        }
        return fallback;
    }
  }

  Widget _buildActivationHistoryCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return FutureBuilder<List<LicenseActivationLogEntry>>(
      future: activationLogsFuture,
      builder: (context, snapshot) {
        final logs = snapshot.data ?? const <LicenseActivationLogEntry>[];
        final filteredLogs = _filterActivationLogs(logs);
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
              _MiniCaption(
                text: 'license.activation_history'.tr(),
                icon: Icons.history,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text('license.filter_all'.tr()),
                    selected:
                        activationHistoryFilter == LicenseHistoryFilter.all,
                    onSelected: (_) =>
                        onFilterChanged(LicenseHistoryFilter.all),
                  ),
                  ChoiceChip(
                    label: Text('license.filter_success'.tr()),
                    selected:
                        activationHistoryFilter == LicenseHistoryFilter.success,
                    onSelected: (_) =>
                        onFilterChanged(LicenseHistoryFilter.success),
                  ),
                  ChoiceChip(
                    label: Text('license.filter_failed'.tr()),
                    selected:
                        activationHistoryFilter == LicenseHistoryFilter.failed,
                    onSelected: (_) =>
                        onFilterChanged(LicenseHistoryFilter.failed),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (filteredLogs.isEmpty)
                Text('license.no_activation_history'.tr())
              else
                ...filteredLogs.map((log) {
                  final tone = log.success
                      ? Colors.green.shade700
                      : theme.colorScheme.error;
                  final when = log.at
                      .toLocal()
                      .toString()
                      .replaceFirst('T', ' ')
                      .split('.')
                      .first;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: tone.withValues(alpha: 0.28)),
                      color: tone.withValues(alpha: 0.08),
                    ),
                    child: Text(
                      '$when | ${activationStatusLabel(log.success)} | ${log.code}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tone,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: filteredLogs.isEmpty
                        ? null
                        : () => onCopyTxt(filteredLogs),
                    icon: const Icon(Icons.content_copy_outlined),
                    label: Text('license.copy_txt'.tr()),
                  ),
                  OutlinedButton.icon(
                    onPressed: filteredLogs.isEmpty
                        ? null
                        : () => onCopyCsv(filteredLogs),
                    icon: const Icon(Icons.copy_all_outlined),
                    label: Text('license.copy_csv'.tr()),
                  ),
                  OutlinedButton.icon(
                    onPressed: filteredLogs.isEmpty
                        ? null
                        : () => onExportTxt(filteredLogs),
                    icon: const Icon(Icons.description_outlined),
                    label: Text('license.export_txt'.tr()),
                  ),
                  OutlinedButton.icon(
                    onPressed: filteredLogs.isEmpty
                        ? null
                        : () => onExportCsv(filteredLogs),
                    icon: const Icon(Icons.table_chart_outlined),
                    label: Text('license.export_csv'.tr()),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  List<LicenseActivationLogEntry> _filterActivationLogs(
    List<LicenseActivationLogEntry> logs,
  ) {
    switch (activationHistoryFilter) {
      case LicenseHistoryFilter.all:
        return logs;
      case LicenseHistoryFilter.success:
        return logs.where((log) => log.success).toList(growable: false);
      case LicenseHistoryFilter.failed:
        return logs.where((log) => !log.success).toList(growable: false);
    }
  }

  Future<(String, String)> _machineIdentity() async {
    final code = await machineCodeFuture;
    final hash = await machineHashFuture;
    return (code, hash);
  }
}

class _MiniCaption extends StatelessWidget {
  const _MiniCaption({
    required this.text,
    required this.icon,
    required this.color,
  });

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _SelectableInfoBlock extends StatelessWidget {
  const _SelectableInfoBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
        color: colorScheme.surface,
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
          const SizedBox(height: 4),
          SelectableText(value),
        ],
      ),
    );
  }
}
