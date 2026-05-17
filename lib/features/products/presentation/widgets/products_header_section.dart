import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:delta_erp/core/widgets/app_brand_header.dart';
import 'package:delta_erp/core/widgets/app_page_shell.dart';
import 'package:delta_erp/core/widgets/primary_button.dart';

class ProductsHeaderSection extends StatelessWidget {
  const ProductsHeaderSection({
    super.key,
    required this.isCompact,
    required this.isDenseViewport,
    required this.isVeryDenseViewport,
    required this.onAddProduct,
  });

  final bool isCompact;
  final bool isDenseViewport;
  final bool isVeryDenseViewport;
  final VoidCallback onAddProduct;

  @override
  Widget build(BuildContext context) {
    return AppSectionPanel(
      emphasis: true,
      padding: EdgeInsets.symmetric(
        horizontal: isVeryDenseViewport ? 8 : (isDenseViewport ? 10 : 12),
        vertical: isVeryDenseViewport ? 6 : (isDenseViewport ? 8 : 10),
      ),
      child: AppBrandHeader(
        pageTitle: 'Products'.tr(),
        actions: [
          PrimaryButton(
            label: 'Add Product'.tr(),
            icon: Icons.add,
            onPressed: onAddProduct,
          ),
        ],
        isDense: isDenseViewport,
        slim: isVeryDenseViewport,
      ),
    );
  }
}
