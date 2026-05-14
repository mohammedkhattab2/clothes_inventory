import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:clothes_inventory/core/widgets/app_inline_loading_indicator.dart';
import 'package:clothes_inventory/features/accounts/data/accounts_repository.dart';

class PurchasesSupplierDialog {
  const PurchasesSupplierDialog._();

  static Future<void> show(
    BuildContext context, {
    required List<AccountLookup> suppliers,
    required Future<int> Function({
      required String name,
      String? phone,
      String? address,
    })
    onCreateSupplier,
    required Future<void> Function() onReloadSuppliers,
    required void Function(int supplierId) onSupplierSelected,
  }) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _PurchasesSupplierDialogContent(
          parentContext: context,
          suppliers: suppliers,
          onCreateSupplier: onCreateSupplier,
          onReloadSuppliers: onReloadSuppliers,
          onSupplierSelected: onSupplierSelected,
        );
      },
    );
  }
}

class _PurchasesSupplierDialogContent extends StatefulWidget {
  const _PurchasesSupplierDialogContent({
    required this.parentContext,
    required this.suppliers,
    required this.onCreateSupplier,
    required this.onReloadSuppliers,
    required this.onSupplierSelected,
  });

  final BuildContext parentContext;
  final List<AccountLookup> suppliers;
  final Future<int> Function({
    required String name,
    String? phone,
    String? address,
  })
  onCreateSupplier;
  final Future<void> Function() onReloadSuppliers;
  final void Function(int supplierId) onSupplierSelected;

  @override
  State<_PurchasesSupplierDialogContent> createState() =>
      _PurchasesSupplierDialogContentState();
}

class _PurchasesSupplierDialogContentState
    extends State<_PurchasesSupplierDialogContent> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final veryDense = MediaQuery.sizeOf(context).height < 720;
    final dialogWidth = (MediaQuery.sizeOf(context).width * 0.9).clamp(
      280.0,
      420.0,
    );

    return AlertDialog(
      backgroundColor: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      actionsOverflowDirection: VerticalDirection.down,
      title: Text('Create Supplier'.tr()),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Supplier name'.tr()),
              ),
              SizedBox(height: veryDense ? 6 : 8),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: 'Supplier phone'.tr()),
              ),
              SizedBox(height: veryDense ? 6 : 8),
              TextField(
                controller: _addressController,
                decoration: InputDecoration(labelText: 'Supplier address'.tr()),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_outlined),
          label: Text('Cancel'.tr()),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _handleSave,
          icon: _saving
              ? const AppInlineLoadingIndicator()
              : const Icon(Icons.check_circle_outline),
          label: Text('Save'.tr()),
          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
      ],
    );
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();
    if (name.isEmpty) return;

    AccountLookup? existing;
    final normalized = name.toLowerCase();
    for (final supplier in widget.suppliers) {
      if (supplier.name.trim().toLowerCase() == normalized) {
        existing = supplier;
        break;
      }
    }

    if (existing != null) {
      widget.onSupplierSelected(existing.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
      if (widget.parentContext.mounted) {
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(
            content: Text('Supplier already exists and was selected.'.tr()),
          ),
        );
      }
      return;
    }

    setState(() => _saving = true);
    try {
      final createdId = await widget.onCreateSupplier(
        name: name,
        phone: phone.isEmpty ? null : phone,
        address: address.isEmpty ? null : address,
      );
      await widget.onReloadSuppliers();
      widget.onSupplierSelected(createdId);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
