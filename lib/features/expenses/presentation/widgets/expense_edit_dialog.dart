import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:delta_erp/core/utils/translation_utils.dart';
import 'package:delta_erp/core/widgets/app_error_banner.dart';
import 'package:delta_erp/core/widgets/app_inline_loading_indicator.dart';
import 'package:delta_erp/features/accounts/data/accounts_repository.dart';
import 'package:delta_erp/features/expenses/data/expenses_repository.dart';

class ExpenseEditData {
  const ExpenseEditData({
    required this.accountId,
    required this.amount,
    required this.paymentMethod,
    required this.notes,
  });

  final int accountId;
  final double amount;
  final String paymentMethod;
  final String notes;
}

class ExpenseEditDialog extends StatefulWidget {
  const ExpenseEditDialog({
    super.key,
    required this.row,
    required this.expenseAccounts,
    required this.onSave,
  });

  final ExpenseRecord row;
  final List<AccountLookup> expenseAccounts;
  final Future<void> Function(ExpenseEditData value) onSave;

  @override
  State<ExpenseEditDialog> createState() => _ExpenseEditDialogState();
}

class _ExpenseEditDialogState extends State<ExpenseEditDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  late int _accountId;
  late String _paymentMethod;
  String? _dialogError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.row.amount.abs().toStringAsFixed(2),
    );
    _notesController = TextEditingController(text: widget.row.notes ?? '');
    _accountId = widget.row.accountId;
    _paymentMethod = widget.row.paymentMethod;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final parsed = double.tryParse(
      _amountController.text.trim().replaceAll(',', '.'),
    );
    if (parsed == null || parsed <= 0) {
      setState(() => _dialogError = 'Enter a valid amount.'.tr());
      return;
    }

    setState(() {
      _dialogError = null;
      _saving = true;
    });

    try {
      await widget.onSave(
        ExpenseEditData(
          accountId: _accountId,
          amount: parsed,
          paymentMethod: _paymentMethod,
          notes: _notesController.text,
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _dialogError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final veryDense = MediaQuery.sizeOf(context).height < 720;
    final fieldGap = veryDense ? 8.0 : 10.0;

    return AlertDialog(
      backgroundColor: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      title: Text('Edit Expense'.tr()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _accountId,
              decoration: InputDecoration(labelText: 'Expense Category'.tr()),
              items: widget.expenseAccounts
                  .map(
                    (a) => DropdownMenuItem<int>(
                      value: a.id,
                      child: Text(trIfExists(a.name, context: context)),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _accountId = value);
                      }
                    },
            ),
            SizedBox(height: fieldGap),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: 'Amount'.tr()),
            ),
            SizedBox(height: fieldGap),
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: InputDecoration(labelText: 'Payment method'.tr()),
              items: [
                DropdownMenuItem(value: 'cash', child: Text('Cash'.tr())),
                DropdownMenuItem(
                  value: 'vodafone_cash',
                  child: Text('Vodafone Cash'.tr()),
                ),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _paymentMethod = value);
                      }
                    },
            ),
            SizedBox(height: fieldGap),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(labelText: 'Notes (optional)'.tr()),
            ),
            if (_dialogError != null) ...[
              SizedBox(height: fieldGap),
              AppErrorBanner(message: _dialogError!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.close_outlined),
          label: Text('Cancel'.tr()),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _submit,
          icon: _saving
              ? const AppInlineLoadingIndicator()
              : const Icon(Icons.check_circle_outline),
          label: Text('Save'.tr()),
          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
      ],
    );
  }
}
