import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:clothes_inventory/features/sales/presentation/widgets/sales_cancel_dialog_actions.dart';
import 'package:clothes_inventory/features/sales/presentation/widgets/sales_cancel_dialog_header.dart';

class SalesCancelSaleDialog extends StatefulWidget {
  const SalesCancelSaleDialog({
    required this.parseFlexibleInt,
    required this.onCancelSale,
    required this.animateDialogEntrance,
    this.initialSaleId,
    super.key,
  });

  final int? initialSaleId;
  final int? Function(String value) parseFlexibleInt;
  final Future<bool> Function(int saleId) onCancelSale;
  final Widget Function(Widget child) animateDialogEntrance;

  static Future<void> show(
    BuildContext context, {
    int? initialSaleId,
    required int? Function(String value) parseFlexibleInt,
    required Future<bool> Function(int saleId) onCancelSale,
    required Widget Function(Widget child) animateDialogEntrance,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => SalesCancelSaleDialog(
        initialSaleId: initialSaleId,
        parseFlexibleInt: parseFlexibleInt,
        onCancelSale: onCancelSale,
        animateDialogEntrance: animateDialogEntrance,
      ),
    );
  }

  @override
  State<SalesCancelSaleDialog> createState() => _SalesCancelSaleDialogState();
}

class _SalesCancelSaleDialogState extends State<SalesCancelSaleDialog> {
  late final TextEditingController _saleIdController;

  @override
  void initState() {
    super.initState();
    _saleIdController = TextEditingController(
      text: widget.initialSaleId?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _saleIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final veryDense = MediaQuery.sizeOf(context).height < 720;

    return widget.animateDialogEntrance(
      Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: (MediaQuery.sizeOf(context).width * 0.94).clamp(
              320.0,
              560.0,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(veryDense ? 12 : 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SalesCancelDialogHeader(),
                SizedBox(height: veryDense ? 10 : 12),
                TextField(
                  controller: _saleIdController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩]')),
                  ],
                  onTap: () {
                    _saleIdController.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: _saleIdController.text.length,
                    );
                  },
                  decoration: InputDecoration(labelText: 'Sale ID'.tr()),
                ),
                SizedBox(height: veryDense ? 6 : 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colorScheme.error.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    'This action cannot be undone.'.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ),
                SizedBox(height: veryDense ? 10 : 12),
                SalesCancelDialogActions(
                  onNo: () => Navigator.of(context).pop(),
                  onConfirmCancel: () async {
                    final saleId = widget.parseFlexibleInt(
                      _saleIdController.text,
                    );
                    if (saleId == null) return;
                    final success = await widget.onCancelSale(saleId);
                    if (success && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
