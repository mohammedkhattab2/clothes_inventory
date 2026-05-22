import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:delta_erp/core/utils/number_utils.dart';
import 'package:delta_erp/features/sales/domain/sale_models.dart';

class SalesAmendPaymentDialog extends StatefulWidget {
  const SalesAmendPaymentDialog({
    required this.preview,
    required this.parseFlexibleNumber,
    super.key,
  });

  final AmendRefundPreview preview;
  final double? Function(String raw) parseFlexibleNumber;

  static Future<AmendCollectConfirmation?> show(
    BuildContext context, {
    required AmendRefundPreview preview,
    required double? Function(String raw) parseFlexibleNumber,
  }) {
    return showDialog<AmendCollectConfirmation>(
      context: context,
      builder: (_) => SalesAmendPaymentDialog(
        preview: preview,
        parseFlexibleNumber: parseFlexibleNumber,
      ),
    );
  }

  @override
  State<SalesAmendPaymentDialog> createState() =>
      _SalesAmendPaymentDialogState();
}

class _SalesAmendPaymentDialogState extends State<SalesAmendPaymentDialog> {
  late PositiveAmendmentHandling _handling;
  late PaymentMethod _paymentMethod;
  late final TextEditingController _amountController;
  late final TextEditingController _cashController;
  late final TextEditingController _walletController;
  String? _error;

  @override
  void initState() {
    super.initState();
    final delta = widget.preview.positiveDelta;
    _handling = PositiveAmendmentHandling.defer;
    _paymentMethod = PaymentMethod.cash;
    _amountController = TextEditingController(text: delta.toStringAsFixed(2));
    _cashController = TextEditingController(text: delta.toStringAsFixed(2));
    _walletController = TextEditingController(text: '0.00');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _cashController.dispose();
    _walletController.dispose();
    super.dispose();
  }

  String _methodLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Cash'.tr();
      case PaymentMethod.vodafoneCash:
        return 'Vodafone Cash'.tr();
      case PaymentMethod.visa:
        return 'Visa'.tr();
      case PaymentMethod.cashAndWallet:
        return 'sale.amend_collect_split_label'.tr();
    }
  }

  List<TextInputFormatter> get _numFormatters => [
    FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩.,٫٬]')),
  ];

  void _apply() {
    if (_handling == PositiveAmendmentHandling.defer) {
      Navigator.of(context).pop(const AmendCollectConfirmation.defer());
      return;
    }

    final delta = widget.preview.positiveDelta;
    final amount = widget.parseFlexibleNumber(_amountController.text) ?? 0;
    if (amount <= 0.000001) {
      setState(() => _error = 'sale.amend_collect_amount_required'.tr());
      return;
    }
    if (amount - delta > 0.000001) {
      setState(() => _error = 'sale.amend_collect_amount_exceeds'.tr());
      return;
    }

    if (_paymentMethod == PaymentMethod.cashAndWallet) {
      final cash = widget.parseFlexibleNumber(_cashController.text) ?? 0;
      final wallet = widget.parseFlexibleNumber(_walletController.text) ?? 0;
      if (cash < 0 || wallet < 0) {
        setState(() => _error = 'sale.amend_collect_split_negative'.tr());
        return;
      }
      final splitTotal = roundCurrency(cash + wallet);
      if ((splitTotal - roundCurrency(amount)).abs() > 0.000001) {
        setState(() => _error = 'sale.amend_collect_split_mismatch'.tr());
        return;
      }

      Navigator.of(context).pop(
        AmendCollectConfirmation.collectNow(
          paymentMethod: _paymentMethod,
          collectAmount: roundCurrency(amount),
          collectWalletAmount: roundCurrency(wallet),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      AmendCollectConfirmation.collectNow(
        paymentMethod: _paymentMethod,
        collectAmount: roundCurrency(amount),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;
    final currency = NumberFormat.currency(symbol: '', decimalDigits: 2);
    final colorScheme = Theme.of(context).colorScheme;
    final isSplit = _paymentMethod == PaymentMethod.cashAndWallet;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'sale.amend_collect_title'.tr(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${'sale.amend_collect_old_total'.tr()}: ${currency.format(preview.oldTotalAmount)}\n'
                        '${'sale.amend_collect_new_total'.tr()}: ${currency.format(preview.newTotalAmount)}\n'
                        '${'sale.amend_collect_increase'.tr()}: ${currency.format(preview.positiveDelta)}\n'
                        '${'sale.amend_collect_outstanding_after'.tr()}: ${currency.format(preview.outstandingAfterAmend)}',
                      ),
                      const SizedBox(height: 12),
                      RadioGroup<PositiveAmendmentHandling>(
                        groupValue: _handling,
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _handling = value;
                            _error = null;
                          });
                        },
                        child: Column(
                          children: [
                            RadioListTile<PositiveAmendmentHandling>(
                              value: PositiveAmendmentHandling.defer,
                              title: Text('sale.amend_collect_defer'.tr()),
                              contentPadding: EdgeInsets.zero,
                            ),
                            RadioListTile<PositiveAmendmentHandling>(
                              value: PositiveAmendmentHandling.collectNow,
                              title: Text('sale.amend_collect_now'.tr()),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                      if (_handling ==
                          PositiveAmendmentHandling.collectNow) ...[
                        const SizedBox(height: 8),
                        DropdownButtonFormField<PaymentMethod>(
                          initialValue: _paymentMethod,
                          isExpanded: true,
                          items: PaymentMethod.values
                              .map(
                                (m) => DropdownMenuItem<PaymentMethod>(
                                  value: m,
                                  child: Text(
                                    _methodLabel(m),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _paymentMethod = value;
                              _error = null;
                            });
                          },
                          decoration: InputDecoration(
                            labelText: 'Payment method'.tr(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: _numFormatters,
                          decoration: InputDecoration(
                            labelText: 'sale.amend_collect_amount'.tr(),
                            hintText: currency.format(preview.positiveDelta),
                          ),
                        ),
                        if (isSplit) ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: _cashController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: _numFormatters,
                            decoration: InputDecoration(
                              labelText: 'Cash amount'.tr(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _walletController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: _numFormatters,
                            decoration: InputDecoration(
                              labelText: 'Vodafone Cash amount'.tr(),
                            ),
                          ),
                        ],
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.error),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel'.tr()),
                  ),
                  FilledButton(
                    onPressed: _apply,
                    child: Text('sale.complete_amendment'.tr()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
