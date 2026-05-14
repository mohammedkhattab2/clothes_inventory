import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:clothes_inventory/features/settings/presentation/widgets/settings_luxury_components.dart';

class SettingsCompanyTab extends StatelessWidget {
  const SettingsCompanyTab({
    required this.formKey,
    required this.nameController,
    required this.addressController,
    required this.phonesController,
    required this.saving,
    required this.loadingLogo,
    required this.logoPreview,
    required this.onPickLogo,
    required this.onRemoveLogo,
    required this.onValidatePhones,
    required this.onSave,
    required this.onReset,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController addressController;
  final TextEditingController phonesController;
  final bool saving;
  final bool loadingLogo;
  final Widget logoPreview;
  final VoidCallback onPickLogo;
  final VoidCallback onRemoveLogo;
  final List<String> Function(String) onValidatePhones;
  final VoidCallback onSave;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsLuxurySectionCard(
              title: 'Business Identity'.tr(),
              subtitle: 'Your company profile shown on invoices and exports'
                  .tr(),
              icon: Icons.business_center_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Company Name'.tr(),
                      prefixIcon: const Icon(Icons.business_outlined),
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Company name is required.'.tr();
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: addressController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Address'.tr(),
                      prefixIcon: const Icon(Icons.location_on_outlined),
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Address is required.'.tr();
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: phonesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Phone Numbers'.tr(),
                      prefixIcon: const Icon(Icons.call_outlined),
                      helperText: 'Enter one phone per line.'.tr(),
                      alignLabelWithHint: true,
                    ),
                    validator: (value) {
                      final numbers = onValidatePhones(value ?? '');
                      if (numbers.isEmpty) {
                        return 'At least one phone number is required.'.tr();
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SettingsLuxurySectionCard(
              title: 'Company Logo'.tr(),
              subtitle: 'Upload a clear logo for printed and digital outputs'
                  .tr(),
              icon: Icons.image_outlined,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  logoPreview,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FilledButton.icon(
                        onPressed: saving || loadingLogo ? null : onPickLogo,
                        icon: const Icon(Icons.upload_outlined),
                        label: Text('Upload Logo'.tr()),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: saving || loadingLogo ? null : onRemoveLogo,
                        icon: const Icon(Icons.delete_outline),
                        label: Text('Remove Logo'.tr()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: saving ? null : onReset,
                    icon: const Icon(Icons.refresh_outlined),
                    label: Text('Reset'.tr()),
                  ),
                  FilledButton.icon(
                    onPressed: saving ? null : onSave,
                    icon: saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      saving ? 'Saving...'.tr() : 'Save Settings'.tr(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
