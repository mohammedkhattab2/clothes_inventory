import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:clothes_inventory/features/settings/presentation/widgets/settings_luxury_components.dart';

class SettingsCompanyTab extends StatelessWidget {
  const SettingsCompanyTab({
    required this.formKey,
    required this.nameController,
    required this.addressController,
    required this.phonesController,
    required this.invoiceFooterNoteController,
    required this.saving,
    required this.loadingLogo,
    required this.loadingFooterImage,
    required this.logoPreview,
    required this.onPickLogo,
    required this.onRemoveLogo,
    required this.onValidatePhones,
    required this.onSave,
    required this.onReset,
    this.currentThermalPrinterName,
    this.selectingPrinter = false,
    this.onSelectThermalPrinter,
    this.onClearThermalPrinter,
    required this.onPickFooterImage,
    required this.onRemoveFooterImage,
    required this.footerImagePreview,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController addressController;
  final TextEditingController phonesController;
  final TextEditingController invoiceFooterNoteController;
  final bool saving;
  final bool loadingLogo;
  final bool loadingFooterImage;
  final Widget logoPreview;
  final VoidCallback onPickLogo;
  final VoidCallback onRemoveLogo;
  final VoidCallback onPickFooterImage;
  final VoidCallback onRemoveFooterImage;
  final Widget footerImagePreview;
  final List<String> Function(String) onValidatePhones;
  final VoidCallback onSave;
  final VoidCallback onReset;
  final String? currentThermalPrinterName;
  final bool selectingPrinter;
  final VoidCallback? onSelectThermalPrinter;
  final VoidCallback? onClearThermalPrinter;

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
              title: 'Invoice footer'.tr(),
              subtitle:
                  'Optional text and image shown at the bottom of printed invoices'
                      .tr(),
              icon: Icons.vertical_align_bottom_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: invoiceFooterNoteController,
                    minLines: 2,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: 'Footer note'.tr(),
                      helperText:
                          'Terms, thank-you message, or any text for customers.'
                              .tr(),
                      alignLabelWithHint: true,
                      prefixIcon: const Icon(Icons.notes_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Footer image'.tr(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      footerImagePreview,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FilledButton.icon(
                            onPressed: saving ||
                                    loadingLogo ||
                                    loadingFooterImage
                                ? null
                                : onPickFooterImage,
                            icon: const Icon(Icons.image_outlined),
                            label: Text('Upload footer image'.tr()),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: saving ||
                                    loadingLogo ||
                                    loadingFooterImage
                                ? null
                                : onRemoveFooterImage,
                            icon: const Icon(Icons.delete_outline),
                            label: Text('Remove footer image'.tr()),
                          ),
                        ],
                      ),
                    ],
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
                        onPressed: saving || loadingLogo || loadingFooterImage
                            ? null
                            : onPickLogo,
                        icon: const Icon(Icons.upload_outlined),
                        label: Text('Upload Logo'.tr()),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: saving || loadingLogo || loadingFooterImage
                            ? null
                            : onRemoveLogo,
                        icon: const Icon(Icons.delete_outline),
                        label: Text('Remove Logo'.tr()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SettingsLuxurySectionCard(
              title: 'الطابعة الحرارية',
              subtitle:
                  'حدد طابعة USB أو Bluetooth مربوطة بويندوز لطباعة الفواتير مباشرةً',
              icon: Icons.print_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (currentThermalPrinterName != null) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: Colors.green,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            currentThermalPrinterName!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ] else ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_outlined,
                          color: Colors.orange,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'لم يتم تحديد طابعة بعد',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: selectingPrinter
                            ? null
                            : onSelectThermalPrinter,
                        icon: selectingPrinter
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.search_outlined),
                        label: Text(
                          selectingPrinter
                              ? 'جاري البحث...'
                              : (currentThermalPrinterName != null
                                    ? 'تغيير الطابعة'
                                    : 'اختيار الطابعة'),
                        ),
                      ),
                      if (currentThermalPrinterName != null)
                        OutlinedButton.icon(
                          onPressed: onClearThermalPrinter,
                          icon: const Icon(Icons.link_off_outlined),
                          label: const Text('إلغاء التحديد'),
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
