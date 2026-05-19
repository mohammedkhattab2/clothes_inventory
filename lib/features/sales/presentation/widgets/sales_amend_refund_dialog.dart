import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:delta_erp/core/utils/number_utils.dart';
import 'package:delta_erp/features/sales/domain/sale_models.dart';

/// Confirms refund amount when completing an invoice amendment with overpayment.
class SalesAmendRefundDialog extends StatefulWidget {
  const SalesAmendRefundDialog({
    required this.preview,
    required this.parseFlexibleNumber,
    super.key,
  });

  final AmendRefundPreview preview;
  final double? Function(String raw) parseFlexibleNumber;

  static Future<AmendRefundConfirmation?> show(
    BuildContext context, {
    required AmendRefundPreview preview,
    required double? Function(String raw) parseFlexibleNumber,
  }) {
    return showDialog<AmendRefundConfirmation>(
      context: context,
      builder: (_) => SalesAmendRefundDialog(
        preview: preview,
        parseFlexibleNumber: parseFlexibleNumber,
      ),
    );
  }

  @override
  State<SalesAmendRefundDialog> createState() => _SalesAmendRefundDialogState();
}

class _SalesAmendRefundDialogState extends State<SalesAmendRefundDialog> {
  late final TextEditingController _refundAmountController;
  late final TextEditingController _refundCashController;
  late final TextEditingController _refundWalletController;
  String? _error;

  @override
  void initState() {
    super.initState();
    final max = widget.preview.maxRefundable;
    final isSplit = widget.preview.paymentMethod == PaymentMethod.cashAndWallet;
    _refundAmountController = TextEditingController(
      text: isSplit ? '' : max.toStringAsFixed(2),
    );
    if (isSplit) {
      final snap = widget.preview;
      final paidTotal = snap.paidCash + snap.paidWallet;
      final cashShare = paidTotal > 0.000001
          ? roundCurrency(max * snap.paidCash / paidTotal)
          : roundCurrency(max / 2);
      _refundCashController = TextEditingController(
        text: cashShare.toStringAsFixed(2),
      );
      _refundWalletController = TextEditingController(
        text: roundCurrency(max - cashShare).toStringAsFixed(2),
      );
    } else {
      _refundCashController = TextEditingController();
      _refundWalletController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _refundAmountController.dispose();
    _refundCashController.dispose();
    _refundWalletController.dispose();
    super.dispose();
  }

  void _apply() {
    final max = widget.preview.maxRefundable;
    final isSplit = widget.preview.paymentMethod == PaymentMethod.cashAndWallet;
    if (isSplit) {
      final cash = widget.parseFlexibleNumber(_refundCashController.text) ?? 0;
      final wallet =
          widget.parseFlexibleNumber(_refundWalletController.text) ?? 0;
      final total = roundCurrency(cash + wallet);
      if (total <= 0.000001) {
        setState(() => _error = 'sale.amend_refund_required'.tr());
        return;
      }
      if (total > max + 0.000001) {
        setState(() => _error = 'Refund split exceeds allowed refund amount.');
        return;
      }
      Navigator.of(context).pop(
        AmendRefundConfirmation(
          refundCashOverride: cash,
          refundWalletOverride: wallet,
        ),
      );
      return;
    }

    final amount =
        widget.parseFlexibleNumber(_refundAmountController.text) ?? 0;
    if (amount <= 0.000001) {
      setState(() => _error = 'sale.amend_refund_required'.tr());
      return;
    }
    if (amount > max + 0.000001) {
      setState(
        () => _error = 'Refund amount exceeds allowed refund amount.'.tr(),
      );
      return;
    }
    Navigator.of(context).pop(
      AmendRefundConfirmation(refundAmountOverride: amount),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;
    final isSplit = preview.paymentMethod == PaymentMethod.cashAndWallet;
    final currency = NumberFormat.currency(symbol: '', decimalDigits: 2);

    return AlertDialog(
      title: Text('sale.amend_refund_title'.tr()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'sale.amend_refund_hint'.tr(
                namedArgs: {
                  'return': currency.format(preview.returnAmountTotal),
                  'max': currency.format(preview.maxRefundable),
                },
              ),
            ),
            const SizedBox(height: 12),
            if (isSplit) ...[
              TextField(
                controller: _refundCashController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9٠-٩.,٫٬]'),
                  ),
                ],
                decoration: InputDecoration(
                  labelText: 'Paid cash amount'.tr(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _refundWalletController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9٠-٩.,٫٬]'),
                  ),
                ],
                decoration: InputDecoration(
                  labelText: 'Vodafone Cash'.tr(),
                ),
              ),
            ] else
              TextField(
                controller: _refundAmountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9٠-٩.,٫٬]'),
                  ),
                ],
                decoration: InputDecoration(
                  labelText: 'Refund amount'.tr(),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'.tr()),
        ),
        FilledButton(
          onPressed: _apply,
          child: Text('sale.complete_amendment'.tr()),
        ),
      ],
    );
  }
}
