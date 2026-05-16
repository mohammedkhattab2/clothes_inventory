import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:clothes_inventory/core/widgets/app_brand_header.dart';
import 'package:clothes_inventory/core/widgets/app_page_shell.dart';

class SalesHeaderSection extends StatelessWidget {
  const SalesHeaderSection({
    super.key,
    required this.isShortViewport,
    required this.isVeryDenseViewport,
    this.actions,
    this.readOnlyMode = false,
    this.readOnlyMessage,
  });

  final bool isShortViewport;
  final bool isVeryDenseViewport;
  final List<Widget>? actions;
  final bool readOnlyMode;
  final String? readOnlyMessage;

  @override
  Widget build(BuildContext context) {
    return AppSectionPanel(
      emphasis: true,
      padding: EdgeInsets.symmetric(
        horizontal: isVeryDenseViewport ? 8 : (isShortViewport ? 10 : 12),
        vertical: isVeryDenseViewport ? 6 : (isShortViewport ? 8 : 10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppBrandHeader(
            pageTitle: 'Sales'.tr(),
            description: null,
            isDense: isShortViewport,
            slim: isVeryDenseViewport,
            actions: actions,
          ),
          if (readOnlyMode)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Colors.orange.shade100,
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Text(
                  readOnlyMessage ?? 'license.read_only_banner'.tr(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
