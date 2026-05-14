import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:clothes_inventory/features/settings/presentation/widgets/settings_luxury_components.dart';

class SettingsOverviewSnapshot {
  const SettingsOverviewSnapshot({
    required this.licenseActive,
    required this.ocrReady,
    required this.profileName,
  });

  final bool licenseActive;
  final bool ocrReady;
  final String profileName;
}

class SettingsOverviewTab extends StatelessWidget {
  const SettingsOverviewTab({
    required this.overviewFuture,
    required this.saving,
    required this.onSave,
    required this.onReset,
    required this.onTestPrint,
    required this.onOpenBackup,
    required this.headerPreview,
    required this.invoicePreview,
    super.key,
  });

  final Future<SettingsOverviewSnapshot> overviewFuture;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onReset;
  final VoidCallback onTestPrint;
  final VoidCallback onOpenBackup;
  final Widget headerPreview;
  final Widget invoicePreview;

  @override
  Widget build(BuildContext context) {
    final tone = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsLuxurySectionCard(
            title: 'Control Center'.tr(),
            subtitle: 'Quick health and workflow actions'.tr(),
            icon: Icons.auto_awesome_outlined,
            child: FutureBuilder<SettingsOverviewSnapshot>(
              future: overviewFuture,
              builder: (context, snapshot) {
                final state = snapshot.data;
                final isLicenseActive = state?.licenseActive ?? false;
                final isOcrReady = state?.ocrReady ?? false;
                final profileName = state?.profileName ?? '-';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SettingsStatusPill(
                          label: 'License'.tr(),
                          value: isLicenseActive
                              ? 'Active'.tr()
                              : 'Inactive'.tr(),
                          color: isLicenseActive
                              ? Colors.green.shade700
                              : tone.error,
                        ),
                        SettingsStatusPill(
                          label: 'OCR'.tr(),
                          value: isOcrReady
                              ? 'OCR Ready'.tr()
                              : 'OCR Not Ready'.tr(),
                          color: isOcrReady
                              ? Colors.green.shade700
                              : tone.error,
                        ),
                        SettingsStatusPill(
                          label: 'Company'.tr(),
                          value: profileName,
                          color: tone.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: saving ? null : onSave,
                          icon: saving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            saving ? 'Saving...'.tr() : 'Save Settings'.tr(),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: saving ? null : onReset,
                          icon: const Icon(Icons.refresh_outlined),
                          label: Text('Reset'.tr()),
                        ),
                        OutlinedButton.icon(
                          onPressed: saving ? null : onTestPrint,
                          icon: const Icon(Icons.print_outlined),
                          label: Text('Test Print'.tr()),
                        ),
                        OutlinedButton.icon(
                          onPressed: onOpenBackup,
                          icon: const Icon(Icons.backup_outlined),
                          label: Text('backup.open_page'.tr()),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SettingsLuxurySectionCard(
            title: 'Live Preview'.tr(),
            subtitle: 'A real-time view for header and invoice output'.tr(),
            icon: Icons.visibility_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                headerPreview,
                const SizedBox(height: 12),
                invoicePreview,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
