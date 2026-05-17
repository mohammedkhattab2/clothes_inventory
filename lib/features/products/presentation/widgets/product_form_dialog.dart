import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:delta_erp/features/products/domain/duplicate_product_barcode_exception.dart';
import 'package:delta_erp/features/products/domain/product.dart';
import 'package:delta_erp/services/printing/product_barcode_label_printer.dart';
import 'package:printing/printing.dart';

class ProductFormDialog extends StatefulWidget {
  const ProductFormDialog({
    super.key,
    required this.onSave,
    this.product,
    this.onGenerateBarcode,
    this.onPrintBarcode,
    this.barcodeLabelPrinter,
  });

  final Product? product;
  final Future<void> Function(Product payload) onSave;
  final Future<String> Function()? onGenerateBarcode;
  final Future<void> Function({
    required String productName,
    required String barcode,
  })?
  onPrintBarcode;
  final ProductBarcodeLabelPrinter? barcodeLabelPrinter;
  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _barcode;
  late final TextEditingController _salePriceRetail;
  late final TextEditingController _salePriceHalfWholesale;
  late final TextEditingController _salePriceWholesale;
  late final TextEditingController _purchasePrice;
  late final TextEditingController _lowStock;
  late final FocusNode _barcodeFocus;
  late UnitType _unit;
  bool _generatingBarcode = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name = TextEditingController(text: product?.name ?? '');
    _barcode = TextEditingController(text: product?.barcode ?? '');
    _salePriceRetail = TextEditingController(
      text: product == null ? '' : product.salePrice.toStringAsFixed(2),
    );
    _salePriceHalfWholesale = TextEditingController(
      text: product == null
          ? ''
          : product.salePriceHalfWholesale.toStringAsFixed(2),
    );
    _salePriceWholesale = TextEditingController(
      text: product == null
          ? ''
          : product.salePriceWholesale.toStringAsFixed(2),
    );
    _purchasePrice = TextEditingController(
      text: product == null ? '' : product.purchasePrice.toStringAsFixed(2),
    );
    _lowStock = TextEditingController(
      text: product == null ? '' : product.lowStockThreshold.toStringAsFixed(0),
    );
    _barcodeFocus = FocusNode();
    _unit = product?.unitType ?? UnitType.piece;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoFillShortBarcodeIfNew();
    });
  }

  Future<void> _autoFillShortBarcodeIfNew() async {
    if (widget.product != null || widget.onGenerateBarcode == null) return;
    if (_barcode.text.trim().isNotEmpty) return;
    await _generateShortBarcode();
  }

  Future<void> _generateShortBarcode() async {
    if (widget.onGenerateBarcode == null) return;
    if (_generatingBarcode) return;
    setState(() => _generatingBarcode = true);
    try {
      final generated = await widget.onGenerateBarcode!();
      if (!mounted) return;
      setState(() {
        _barcode.text = generated;
        _barcode.selection = TextSelection.collapsed(offset: generated.length);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'Failed to generate barcode'.tr()}: $e')),
      );
    } finally {
      if (mounted) setState(() => _generatingBarcode = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _barcode.dispose();
    _salePriceRetail.dispose();
    _salePriceHalfWholesale.dispose();
    _salePriceWholesale.dispose();
    _lowStock.dispose();
    _barcodeFocus.dispose();
    super.dispose();
  }

  String _normalizeDigits(String raw) {
    const arabicIndicDigits = {
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
    };

    var normalized = raw;
    arabicIndicDigits.forEach((key, value) {
      normalized = normalized.replaceAll(key, value);
    });
    return normalized;
  }

  String _normalizeBarcodeForSave(String raw) {
    final t = _normalizeDigits(raw).trim();
    if (t.isEmpty) return '';
    if (t.length == 5 && RegExp(r'^[A-Za-z]\d{4}$').hasMatch(t)) {
      return '${t[0].toUpperCase()}${t.substring(1)}';
    }
    return t;
  }

  Future<void> _printBarcode() async {
    if (widget.onPrintBarcode == null) return;

    final name = _name.text.trim();
    final code = _normalizeBarcodeForSave(_barcode.text);
    if (name.isEmpty || code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enter product name and barcode first'.tr())),
      );
      return;
    }

    await widget.onPrintBarcode!(productName: name, barcode: code);
  }

  Future<void> _previewBarcode() async {
    final printer = widget.barcodeLabelPrinter;
    if (printer == null) return;

    final name = _name.text.trim();
    final code = _normalizeBarcodeForSave(_barcode.text);
    if (name.isEmpty || code.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enter product name and barcode first'.tr())),
      );
      return;
    }

    try {
      final bytes = await printer.buildLabelPdfBytes(
        productName: name,
        barcodeValue: code,
        copies: 1,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: SizedBox(
            width: 420,
            height: 560,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Preview'.tr(),
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: PdfPreview(
                    padding: EdgeInsets.zero,
                    build: (format) async => bytes,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'Preview failed'.tr()}: $e')),
      );
    }
  }

  double? _parseFlexibleNumber(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    const arabicIndicDigits = {
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
    };

    var normalized = trimmed;
    arabicIndicDigits.forEach((key, value) {
      normalized = normalized.replaceAll(key, value);
    });

    normalized = normalized
        .replaceAll('٬', '')
        .replaceAll('٫', '.')
        .replaceAll(',', '.');

    return double.tryParse(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final veryDense = MediaQuery.sizeOf(context).height < 720;
    final fieldGap = veryDense ? 8.0 : 12.0;
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
      title: Text(
        widget.product == null ? 'Add Product'.tr() : 'Edit Product'.tr(),
      ),
      content: StatefulBuilder(
        builder: (context, setModalState) {
          final parsedSalePrice = _parseFlexibleNumber(_salePriceRetail.text);
          final parsedHalfWholesale = _parseFlexibleNumber(
            _salePriceHalfWholesale.text,
          );
          final parsedWholesale = _parseFlexibleNumber(
            _salePriceWholesale.text,
          );
          final parsedPurchasePrice = _parseFlexibleNumber(_purchasePrice.text);
          final isBelowCost =
              parsedSalePrice != null &&
              parsedPurchasePrice != null &&
              parsedSalePrice < parsedPurchasePrice;
          final isHalfWholesaleBelowCost =
              parsedHalfWholesale != null &&
              parsedPurchasePrice != null &&
              parsedHalfWholesale < parsedPurchasePrice;
          final isWholesaleBelowCost =
              parsedWholesale != null &&
              parsedPurchasePrice != null &&
              parsedWholesale < parsedPurchasePrice;

          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: dialogWidth),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _name,
                      decoration: InputDecoration(labelText: 'Name'.tr()),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Name is required'.tr()
                          : null,
                    ),
                    SizedBox(height: fieldGap),
                    TextFormField(
                      controller: _barcode,
                      focusNode: _barcodeFocus,
                      textInputAction: TextInputAction.next,
                      maxLength: widget.product == null ? 5 : null,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[A-Za-z0-9٠-٩]'),
                        ),
                      ],
                      onEditingComplete: () {
                        FocusScope.of(context).nextFocus();
                      },
                      validator: (value) {
                        final t = _normalizeBarcodeForSave(value ?? '');
                        if (t.isEmpty) return null;
                        if (widget.product == null &&
                            !RegExp(r'^[A-Za-z]\d{4}$').hasMatch(t)) {
                          return 'products.barcode_short_invalid'.tr();
                        }
                        return null;
                      },
                      buildCounter: widget.product == null
                          ? (_, {required currentLength,
                              required isFocused,
                              required maxLength}) =>
                              null
                          : null,
                      decoration: InputDecoration(
                        labelText: 'Barcode (optional)'.tr(),
                        helperText: widget.product == null
                            ? 'products.barcode_short_helper'.tr()
                            : null,
                        suffixIcon: _generatingBarcode
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : (widget.product == null &&
                                    widget.onGenerateBarcode != null
                                ? IconButton(
                                    tooltip: 'Regenerate'.tr(),
                                    icon: const Icon(Icons.refresh_rounded),
                                    onPressed: _generateShortBarcode,
                                  )
                                : const Icon(Icons.qr_code_2_outlined)),
                      ),
                    ),
                    SizedBox(height: fieldGap),
                    DropdownButtonFormField<UnitType>(
                      initialValue: _unit,
                      decoration: InputDecoration(labelText: 'Unit Type'.tr()),
                      items: UnitType.values
                          .map(
                            (e) =>
                                DropdownMenuItem(value: e, child: Text(e.name)),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() => _unit = value);
                        }
                      },
                    ),
                    SizedBox(height: fieldGap),
                    TextFormField(
                      controller: _salePriceRetail,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9٠-٩.,٫٬]'),
                        ),
                      ],
                      onTap: () {
                        _salePriceRetail.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _salePriceRetail.text.length,
                        );
                      },
                      onChanged: (_) => setModalState(() {}),
                      validator: (value) {
                        final sale = _parseFlexibleNumber(value ?? '');
                        final purchase = _parseFlexibleNumber(
                          _purchasePrice.text,
                        );
                        if (sale != null && purchase != null) {
                          if (sale < purchase) {
                            return 'Sale price cannot be less than purchase price.'
                                .tr();
                          }
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Retail Price'.tr(),
                        hintText: '0',
                        helperText: parsedPurchasePrice == null
                            ? null
                            : '${'Minimum sale price'.tr()}: ${parsedPurchasePrice.toStringAsFixed(2)}',
                        helperStyle: TextStyle(
                          color: isBelowCost
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).textTheme.bodySmall?.color,
                          fontWeight: isBelowCost
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(height: fieldGap),
                    TextFormField(
                      controller: _salePriceHalfWholesale,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9٠-٩.,٫٬]'),
                        ),
                      ],
                      onTap: () {
                        _salePriceHalfWholesale.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _salePriceHalfWholesale.text.length,
                        );
                      },
                      onChanged: (_) => setModalState(() {}),
                      validator: (value) {
                        final sale = _parseFlexibleNumber(value ?? '');
                        final purchase = _parseFlexibleNumber(
                          _purchasePrice.text,
                        );
                        if (sale != null && purchase != null) {
                          if (sale < purchase) {
                            return 'Sale price cannot be less than purchase price.'
                                .tr();
                          }
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Half Wholesale Price'.tr(),
                        hintText: '0',
                        helperText: parsedPurchasePrice == null
                            ? null
                            : '${'Minimum sale price'.tr()}: ${parsedPurchasePrice.toStringAsFixed(2)}',
                        helperStyle: TextStyle(
                          color: isHalfWholesaleBelowCost
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).textTheme.bodySmall?.color,
                          fontWeight: isHalfWholesaleBelowCost
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(height: fieldGap),
                    TextFormField(
                      controller: _salePriceWholesale,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9٠-٩.,٫٬]'),
                        ),
                      ],
                      onTap: () {
                        _salePriceWholesale.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _salePriceWholesale.text.length,
                        );
                      },
                      onChanged: (_) => setModalState(() {}),
                      validator: (value) {
                        final sale = _parseFlexibleNumber(value ?? '');
                        final purchase = _parseFlexibleNumber(
                          _purchasePrice.text,
                        );
                        if (sale != null && purchase != null) {
                          if (sale < purchase) {
                            return 'Sale price cannot be less than purchase price.'
                                .tr();
                          }
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Wholesale Price'.tr(),
                        hintText: '0',
                        helperText: parsedPurchasePrice == null
                            ? null
                            : '${'Minimum sale price'.tr()}: ${parsedPurchasePrice.toStringAsFixed(2)}',
                        helperStyle: TextStyle(
                          color: isWholesaleBelowCost
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).textTheme.bodySmall?.color,
                          fontWeight: isWholesaleBelowCost
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(height: fieldGap),
                    TextFormField(
                      controller: _purchasePrice,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9٠-٩.,٫٬]'),
                        ),
                      ],
                      onTap: () {
                        _purchasePrice.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _purchasePrice.text.length,
                        );
                      },
                      onChanged: (_) {
                        setModalState(() {});
                        _formKey.currentState?.validate();
                      },
                      decoration: InputDecoration(
                        labelText: 'Purchase Price'.tr(),
                        hintText: '0',
                      ),
                    ),
                    SizedBox(height: fieldGap),
                    TextFormField(
                      controller: _lowStock,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9٠-٩.,٫٬]'),
                        ),
                      ],
                      onTap: () {
                        _lowStock.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _lowStock.text.length,
                        );
                      },
                      decoration: InputDecoration(
                        labelText: 'Low Stock Threshold'.tr(),
                        hintText: '0',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      actions: [
        if (widget.barcodeLabelPrinter != null)
          OutlinedButton.icon(
            onPressed: _generatingBarcode ? null : _previewBarcode,
            icon: const Icon(Icons.visibility_outlined),
            label: Text('Preview'.tr()),
          ),
        if (widget.onPrintBarcode != null)
          OutlinedButton.icon(
            onPressed: _generatingBarcode ? null : _printBarcode,
            icon: const Icon(Icons.print_outlined),
            label: Text('Print Barcode'.tr()),
          ),
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_outlined),
          label: Text('Cancel'.tr()),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _salePriceRetail,
          builder: (context, saleValue, child) {
            return ValueListenableBuilder<TextEditingValue>(
              valueListenable: _purchasePrice,
              builder: (context, purchaseValue, child) {
                final parsedSalePrice = _parseFlexibleNumber(
                  _salePriceRetail.text,
                );
                final parsedHalfWholesale = _parseFlexibleNumber(
                  _salePriceHalfWholesale.text,
                );
                final parsedWholesale = _parseFlexibleNumber(
                  _salePriceWholesale.text,
                );
                final parsedPurchasePrice = _parseFlexibleNumber(
                  _purchasePrice.text,
                );
                final isBelowCost =
                    parsedSalePrice != null &&
                    parsedPurchasePrice != null &&
                    parsedSalePrice < parsedPurchasePrice;
                final hasAnyBelowCost =
                    isBelowCost ||
                    (parsedHalfWholesale != null &&
                        parsedPurchasePrice != null &&
                        parsedHalfWholesale < parsedPurchasePrice) ||
                    (parsedWholesale != null &&
                        parsedPurchasePrice != null &&
                        parsedWholesale < parsedPurchasePrice);

                return FilledButton.icon(
                  onPressed: hasAnyBelowCost
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;

                          final bc = _normalizeBarcodeForSave(_barcode.text);
                          final payload = Product(
                            id: widget.product?.id,
                            name: _name.text.trim(),
                            barcode: bc.isEmpty ? null : bc,
                            categoryId: widget.product?.categoryId,
                            unitType: _unit,
                            salePrice: parsedSalePrice ?? 0,
                            salePriceHalfWholesale: parsedHalfWholesale ?? 0,
                            salePriceWholesale: parsedWholesale ?? 0,
                            purchasePrice: parsedPurchasePrice ?? 0,
                            lowStockThreshold:
                                _parseFlexibleNumber(_lowStock.text) ?? 0,
                          );

                          try {
                            await widget.onSave(payload);

                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          } on DuplicateProductBarcodeException {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'products.duplicate_barcode'.tr(),
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        },
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text('Save'.tr()),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
