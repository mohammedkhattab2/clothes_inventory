import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:clothes_inventory/core/widgets/app_text_field.dart';
import 'package:clothes_inventory/core/widgets/secondary_button.dart';

class ProductsSearchSection extends StatelessWidget {
  const ProductsSearchSection({
    super.key,
    required this.isVeryDenseViewport,
    required this.nameController,
    required this.barcodeController,
    required this.onNameChanged,
    required this.onBarcodeChanged,
    required this.onClearSearch,
  });

  final bool isVeryDenseViewport;
  final TextEditingController nameController;
  final TextEditingController barcodeController;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onBarcodeChanged;
  final Future<void> Function() onClearSearch;

  @override
  Widget build(BuildContext context) {
    final sectionGap = isVeryDenseViewport ? 8.0 : 12.0;
    final fieldPadding = EdgeInsets.symmetric(
      horizontal: 16,
      vertical: isVeryDenseViewport ? 12 : 16,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        if (compact) {
          return Column(
            children: [
              AppTextField(
                label: 'Search by name'.tr(),
                controller: nameController,
                onChanged: onNameChanged,
                contentPadding: fieldPadding,
              ),
              SizedBox(height: sectionGap),
              AppTextField(
                label: 'Barcode (exact)'.tr(),
                controller: barcodeController,
                onChanged: onBarcodeChanged,
                contentPadding: fieldPadding,
              ),
              SizedBox(height: sectionGap),
              Align(
                alignment: Alignment.centerLeft,
                child: SecondaryButton(
                  label: 'Clear'.tr(),
                  icon: Icons.clear,
                  onPressed: () async {
                    await onClearSearch();
                  },
                  padding: EdgeInsets.symmetric(
                    horizontal: isVeryDenseViewport ? 14 : 20,
                    vertical: isVeryDenseViewport ? 10 : 14,
                  ),
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: AppTextField(
                label: 'Search by name'.tr(),
                controller: nameController,
                onChanged: onNameChanged,
                contentPadding: fieldPadding,
              ),
            ),
            SizedBox(width: sectionGap),
            Expanded(
              child: AppTextField(
                label: 'Barcode (exact)'.tr(),
                controller: barcodeController,
                onChanged: onBarcodeChanged,
                contentPadding: fieldPadding,
              ),
            ),
            SizedBox(width: sectionGap),
            SecondaryButton(
              label: 'Clear'.tr(),
              icon: Icons.clear,
              onPressed: () async {
                await onClearSearch();
              },
              padding: EdgeInsets.symmetric(
                horizontal: isVeryDenseViewport ? 14 : 20,
                vertical: isVeryDenseViewport ? 10 : 14,
              ),
              borderRadius: BorderRadius.circular(10.0),
            ),
          ],
        );
      },
    );
  }
}
