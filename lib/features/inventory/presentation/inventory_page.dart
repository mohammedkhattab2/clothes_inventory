import 'dart:io';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:clothes_inventory/core/widgets/app_brand_header.dart';
import 'package:clothes_inventory/core/widgets/app_empty_state.dart';
import 'package:clothes_inventory/core/widgets/app_loading_indicator.dart';
import 'package:clothes_inventory/core/utils/translation_utils.dart';
import 'package:clothes_inventory/features/inventory/data/inventory_import_template_service.dart';
import 'package:clothes_inventory/features/inventory/data/inventory_products_import_service.dart';
import 'package:clothes_inventory/features/inventory/data/inventory_repository.dart';
import 'package:clothes_inventory/features/inventory/presentation/widgets/inventory_controls.dart';
import 'package:clothes_inventory/features/inventory/presentation/widgets/inventory_stock_card.dart';
import 'package:clothes_inventory/features/inventory/presentation/widgets/inventory_summary_section.dart';
import 'package:clothes_inventory/features/products/data/products_import_service.dart';
import 'package:clothes_inventory/features/products/data/product_repository.dart';
import 'package:clothes_inventory/features/products/domain/product.dart';
import 'package:clothes_inventory/services/di/service_locator.dart';
import 'package:clothes_inventory/services/printing/product_barcode_label_printer.dart';
import 'package:clothes_inventory/services/printing/thermal_printer_preferences.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _InventoryView();
  }
}

class _InventoryView extends StatefulWidget {
  const _InventoryView();

  @override
  State<_InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<_InventoryView> {
  static const int _lazyChunkSize = 150;

  late Future<List<InventoryStockRow>> _rowsFuture;
  final _productRepository = getIt<ProductRepository>();
  final _barcodeLabelPrinter = const ProductBarcodeLabelPrinter(
    paperWidthMm: 58,
    printerPrefs: ThermalPrinterPreferences(),
  );
  final _inventoryImportService = InventoryProductsImportService();
  final _inventoryTemplateService = InventoryImportTemplateService();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _sortStockDesc = true;
  bool _importingProducts = false;
  bool _savingImportTemplate = false;
  InventoryFilterOption _filter = InventoryFilterOption.all;
  bool _selectionMode = false;
  final Set<int> _selectedProductIds = <int>{};
  final ScrollController _gridScrollController = ScrollController();
  int _visibleGridCount = _lazyChunkSize;
  int _totalFilteredCount = 0;

  void _disposeControllersSafely(List<TextEditingController> controllers) {
    // Defer disposal to avoid using disposed controllers during route pop frames.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final controller in controllers) {
          controller.dispose();
        }
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _rowsFuture = getIt<InventoryRepository>().getCurrentStockRows();
    _gridScrollController.addListener(_handleGridScroll);
    _productRepository.productsRevisionListenable.addListener(
      _handleProductsRevisionChanged,
    );
  }

  void _handleProductsRevisionChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshRows();
    });
  }

  @override
  void dispose() {
    _productRepository.productsRevisionListenable.removeListener(
      _handleProductsRevisionChanged,
    );
    _gridScrollController
      ..removeListener(_handleGridScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool _isOutOfStock(InventoryStockRow row) => row.currentStock <= 0.000001;

  String _formatStock(double value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.000001) {
      return value.toStringAsFixed(0);
    }

    final withThree = value.toStringAsFixed(3);
    return withThree
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  Future<void> _refreshRows() async {
    setState(() {
      _visibleGridCount = _lazyChunkSize;
      _rowsFuture = getIt<InventoryRepository>().getCurrentStockRows();
    });
  }

  void _handleGridScroll() {
    if (!_gridScrollController.hasClients) return;
    if (_visibleGridCount >= _totalFilteredCount) return;
    final position = _gridScrollController.position;
    if (position.maxScrollExtent <= 0) return;

    if (position.pixels >= position.maxScrollExtent - 220) {
      setState(() {
        _visibleGridCount = math.min(
          _visibleGridCount + _lazyChunkSize,
          _totalFilteredCount,
        );
      });
    }
  }

  void _resetGridLazyWindow() {
    if (_visibleGridCount == _lazyChunkSize) return;
    setState(() {
      _visibleGridCount = _lazyChunkSize;
    });
  }

  void _showLatestSnackBar(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 900;
    final isDenseViewport = size.height < 820 || size.width < 1180;
    final isUltraDense = size.height < 700;
    return Padding(
      padding: EdgeInsets.all(isCompact ? 8 : 14),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(isCompact ? 10 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppBrandHeader(
                pageTitle: 'Inventory'.tr(),
                description:
                    'Stock is computed as SUM(IN) - SUM(OUT) from stock movements only.'
                        .tr(),
                actions: [
                  OutlinedButton.icon(
                    onPressed: _savingImportTemplate
                        ? null
                        : _downloadImportTemplate,
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: _savingImportTemplate
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined),
                    label: Text('Download Template'.tr()),
                  ),
                  FilledButton.icon(
                    onPressed: _importingProducts
                        ? null
                        : _importProductsToInventory,
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: _importingProducts
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.file_upload_outlined),
                    label: Text('Import'.tr()),
                  ),
                  FilledButton.icon(
                    onPressed: _showAddProductDialog,
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.add),
                    label: Text('Add Product'.tr()),
                  ),
                  OutlinedButton.icon(
                    onPressed: _toggleSelectionMode,
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: Icon(
                      _selectionMode
                          ? Icons.check_box_outlined
                          : Icons.check_box_outline_blank,
                    ),
                    label: Text(
                      _selectionMode
                          ? 'Exit selection'.tr()
                          : 'Select products'.tr(),
                    ),
                  ),
                  if (_selectionMode)
                    FilledButton.icon(
                      onPressed: _selectedProductIds.isEmpty
                          ? null
                          : _deleteSelectedInventoryProducts,
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: colorScheme.error,
                        foregroundColor: colorScheme.onError,
                      ),
                      icon: const Icon(Icons.delete_sweep_outlined),
                      label: Text(
                        '${'Delete selected'.tr()} (${_selectedProductIds.length})',
                      ),
                    ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minHeight: 34,
                      minWidth: 34,
                    ),
                    onPressed: _refreshRows,
                    icon: Icon(
                      Icons.refresh,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    tooltip: 'Refresh'.tr(),
                  ),
                ],
                isDense: isCompact,
              ),
              SizedBox(height: isDenseViewport ? 4 : 6),
              SizedBox(height: isUltraDense ? 4 : (isDenseViewport ? 8 : 10)),
              Expanded(
                child: FutureBuilder<List<InventoryStockRow>>(
                  future: _rowsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          '${'Failed to load inventory.'.tr()}: ${snapshot.error}',
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return AppLoadingIndicator(
                        label: 'Loading inventory...'.tr(),
                      );
                    }
                    final rows = [...snapshot.data!];
                    _selectedProductIds.removeWhere(
                      (id) => !rows.any((row) => row.productId == id),
                    );
                    if (rows.isEmpty) {
                      return AppEmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'No products found.'.tr(),
                      );
                    }

                    final totalCount = rows.length;
                    final outCount = rows.where(_isOutOfStock).length;
                    final lowCount = rows
                        .where((row) => row.isLow && !_isOutOfStock(row))
                        .length;

                    final filtered = rows.where((row) {
                      if (_searchQuery.isNotEmpty &&
                          !row.productName.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          )) {
                        return false;
                      }

                      switch (_filter) {
                        case InventoryFilterOption.low:
                          return row.isLow && !_isOutOfStock(row);
                        case InventoryFilterOption.out:
                          return _isOutOfStock(row);
                        case InventoryFilterOption.all:
                          return true;
                      }
                    }).toList();

                    filtered.sort((a, b) {
                      final byStock = _sortStockDesc
                          ? b.currentStock.compareTo(a.currentStock)
                          : a.currentStock.compareTo(b.currentStock);
                      if (byStock != 0) return byStock;
                      return a.productName.compareTo(b.productName);
                    });

                    _totalFilteredCount = filtered.length;
                    final visibleRows = filtered
                        .take(math.min(_visibleGridCount, _totalFilteredCount))
                        .toList(growable: false);

                    if (filtered.isEmpty) {
                      return Column(
                        children: [
                          _buildSummarySection(
                            totalCount: totalCount,
                            lowCount: lowCount,
                            outCount: outCount,
                            isUltraDense: isUltraDense,
                          ),
                          SizedBox(height: isUltraDense ? 6 : 8),
                          _buildControls(isUltraDense: isUltraDense),
                          SizedBox(height: isUltraDense ? 6 : 10),
                          Expanded(
                            child: AppEmptyState(
                              icon: Icons.search_off_outlined,
                              title: 'No products match selected stock filter.'
                                  .tr(),
                            ),
                          ),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        _buildSummarySection(
                          totalCount: totalCount,
                          lowCount: lowCount,
                          outCount: outCount,
                          isUltraDense: isUltraDense,
                        ),
                        SizedBox(height: isUltraDense ? 6 : 8),
                        _buildControls(isUltraDense: isUltraDense),
                        SizedBox(height: isUltraDense ? 4 : 6),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final crossAxisCount = constraints.maxWidth < 700
                                  ? 1
                                  : (constraints.maxWidth < 1220 ? 2 : 3);
                              final childAspectRatio = switch (crossAxisCount) {
                                1 => (isUltraDense ? 4.2 : 3.6),
                                2 => (isUltraDense ? 7.0 : 5.8),
                                _ => (isUltraDense ? 8.4 : 7.0),
                              };
                              return RefreshIndicator(
                                onRefresh: _refreshRows,
                                child: GridView.builder(
                                  controller: _gridScrollController,
                                  padding: EdgeInsets.zero,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        crossAxisSpacing: 6,
                                        mainAxisSpacing: 6,
                                        childAspectRatio: childAspectRatio,
                                      ),
                                  itemCount:
                                      visibleRows.length +
                                      (visibleRows.length < _totalFilteredCount
                                          ? 1
                                          : 0),
                                  itemBuilder: (context, index) {
                                    if (index >= visibleRows.length) {
                                      return const Center(
                                        child: SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      );
                                    }

                                    final row = visibleRows[index];
                                    final outOfStock = _isOutOfStock(row);
                                    return InventoryStockCard(
                                      row: row,
                                      outOfStock: outOfStock,
                                      isUltraDense: isUltraDense,
                                      formattedLowThreshold: _formatStock(
                                        row.lowThreshold,
                                      ),
                                      formattedCurrentStock: _formatStock(
                                        row.currentStock,
                                      ),
                                      selectionMode: _selectionMode,
                                      selected: _selectedProductIds.contains(
                                        row.productId,
                                      ),
                                      onSelectionChanged: (selected) {
                                        setState(() {
                                          if (selected) {
                                            _selectedProductIds.add(
                                              row.productId,
                                            );
                                          } else {
                                            _selectedProductIds.remove(
                                              row.productId,
                                            );
                                          }
                                        });
                                      },
                                      onEdit: () => _editInventoryProduct(row),
                                      onDelete: () =>
                                          _deleteInventoryProduct(row),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummarySection({
    required int totalCount,
    required int lowCount,
    required int outCount,
    required bool isUltraDense,
  }) {
    return InventorySummarySection(
      totalCount: totalCount,
      lowCount: lowCount,
      outCount: outCount,
      isUltraDense: isUltraDense,
    );
  }

  Widget _buildControls({required bool isUltraDense}) {
    return InventoryControls(
      searchController: _searchController,
      searchQuery: _searchQuery,
      onSearchChanged: (value) {
        setState(() => _searchQuery = value.trim());
        _resetGridLazyWindow();
      },
      onClearSearch: () {
        _searchController.clear();
        setState(() => _searchQuery = '');
        _resetGridLazyWindow();
      },
      filter: _filter,
      onFilterChanged: (value) {
        setState(() => _filter = value);
        _resetGridLazyWindow();
      },
      sortStockDesc: _sortStockDesc,
      onToggleSort: () {
        setState(() => _sortStockDesc = !_sortStockDesc);
        _resetGridLazyWindow();
      },
      isUltraDense: isUltraDense,
    );
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) {
        _selectedProductIds.clear();
      }
    });
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

  double? _parseFlexibleNumber(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    var normalized = _normalizeDigits(trimmed);

    normalized = normalized
        .replaceAll('٬', '')
        .replaceAll('٫', '.')
        .replaceAll(',', '.');

    return double.tryParse(normalized);
  }

  Future<String> _generateBarcodeFromPrefix(String prefix) {
    return _productRepository.generateNextBarcodeFromPrefix(prefix: prefix);
  }

  Future<void> _printProductBarcodeLabel({
    required String productName,
    required String barcode,
    required int quantity,
  }) async {
    final copies = quantity < 1 ? 1 : quantity;
    try {
      await _barcodeLabelPrinter.printLabel(
        productName: productName,
        barcodeValue: barcode,
        copies: copies,
      );
      if (!mounted) return;
      _showLatestSnackBar('Barcode label sent to printer'.tr());
    } catch (e) {
      if (!mounted) return;
      _showLatestSnackBar('${'Failed to print barcode'.tr()}: $e');
    }
  }

  Future<void> _showAddProductDialog() async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController();
    final barcode = TextEditingController();
    final salePriceRetail = TextEditingController();
    final salePriceHalfWholesale = TextEditingController();
    final salePriceWholesale = TextEditingController();
    final purchasePrice = TextEditingController();
    final lowStock = TextEditingController();
    final openingQty = TextEditingController();
    final barcodeFocus = FocusNode();
    var unit = UnitType.piece;
    var generatingBarcode = false;

    Future<void> tryAutoGenerateBarcode(StateSetter setDialogState) async {
      final prefix = _normalizeDigits(barcode.text).trim();
      if (!RegExp(r'^\d{4}$').hasMatch(prefix) || generatingBarcode) {
        return;
      }

      setDialogState(() => generatingBarcode = true);
      try {
        final generated = await _generateBarcodeFromPrefix(prefix);
        barcode.text = generated;
        barcode.selection = TextSelection.collapsed(offset: generated.length);
      } catch (e) {
        if (!mounted) return;
        _showLatestSnackBar('${'Failed to generate barcode'.tr()}: $e');
      } finally {
        if (mounted) {
          setDialogState(() => generatingBarcode = false);
        }
      }
    }

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final size = MediaQuery.sizeOf(dialogContext);
          final maxWidth = (size.width * 0.92).clamp(300.0, 460.0);
          final maxHeight = (size.height * 0.9).clamp(380.0, 720.0);
          var submitting = false;
          String? submitError;

          return StatefulBuilder(
            builder: (dialogContext, setDialogState) => Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxWidth,
                  maxHeight: maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Product'.tr(),
                        style: Theme.of(dialogContext).textTheme.titleLarge,
                      ),
                      if (submitError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          submitError!,
                          style: TextStyle(
                            color: Theme.of(dialogContext).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Form(
                            key: formKey,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextFormField(
                                  controller: name,
                                  decoration: InputDecoration(
                                    labelText: 'Name'.tr(),
                                  ),
                                  validator: (value) =>
                                      (value == null || value.trim().isEmpty)
                                      ? 'Name is required'.tr()
                                      : null,
                                ),
                                const SizedBox(height: 10),
                                Focus(
                                  onKeyEvent: (node, event) {
                                    if (event is KeyDownEvent &&
                                        event.logicalKey ==
                                            LogicalKeyboardKey.tab) {
                                      tryAutoGenerateBarcode(setDialogState);
                                    }
                                    return KeyEventResult.ignored;
                                  },
                                  child: TextFormField(
                                    controller: barcode,
                                    focusNode: barcodeFocus,
                                    textInputAction: TextInputAction.next,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9٠-٩]'),
                                      ),
                                    ],
                                    onEditingComplete: () {
                                      tryAutoGenerateBarcode(setDialogState);
                                      FocusScope.of(dialogContext).nextFocus();
                                    },
                                    decoration: InputDecoration(
                                      labelText: 'Barcode (optional)'.tr(),
                                      helperText:
                                          'Enter 4 digits then press Tab'.tr(),
                                      suffixIcon: generatingBarcode
                                          ? const Padding(
                                              padding: EdgeInsets.all(10),
                                              child: SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              ),
                                            )
                                          : const Icon(
                                              Icons.qr_code_2_outlined,
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<UnitType>(
                                  initialValue: unit,
                                  decoration: InputDecoration(
                                    labelText: 'Unit Type'.tr(),
                                  ),
                                  items: UnitType.values
                                      .map(
                                        (e) => DropdownMenuItem<UnitType>(
                                          value: e,
                                          child: Text(e.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setDialogState(() => unit = value);
                                    }
                                  },
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: openingQty,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9٠-٩.,٫٬]'),
                                    ),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Opening Quantity'.tr(),
                                  ),
                                  validator: (value) {
                                    final qty = _parseFlexibleNumber(
                                      value ?? '',
                                    );
                                    if (qty == null) {
                                      return 'Enter a valid quantity.'.tr();
                                    }
                                    if (qty < 0) {
                                      return 'Quantity must be zero or greater.'
                                          .tr();
                                    }
                                    if (unit == UnitType.piece &&
                                        (qty - qty.roundToDouble()).abs() >
                                            0.000001) {
                                      return 'Piece products require integer quantity.'
                                          .tr();
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: salePriceRetail,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9٠-٩.,٫٬]'),
                                    ),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Retail Price'.tr(),
                                    hintText: '0',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: salePriceHalfWholesale,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9٠-٩.,٫٬]'),
                                    ),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Half Wholesale Price'.tr(),
                                    hintText: '0',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: salePriceWholesale,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9٠-٩.,٫٬]'),
                                    ),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Wholesale Price'.tr(),
                                    hintText: '0',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: purchasePrice,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9٠-٩.,٫٬]'),
                                    ),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Purchase Price'.tr(),
                                    hintText: '0',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: lowStock,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9٠-٩.,٫٬]'),
                                    ),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Low Stock Threshold'.tr(),
                                    hintText: '0',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: submitting || generatingBarcode
                                  ? null
                                  : () async {
                                      final productName = name.text.trim();
                                      final productBarcode = _normalizeDigits(
                                        barcode.text,
                                      ).trim();
                                      if (productName.isEmpty ||
                                          productBarcode.isEmpty) {
                                        _showLatestSnackBar(
                                          'Enter product name and barcode first'
                                              .tr(),
                                        );
                                        return;
                                      }

                                      final parsedQty =
                                          _parseFlexibleNumber(
                                            openingQty.text,
                                          ) ??
                                          1;
                                      final quantity = parsedQty < 1
                                          ? 1
                                          : parsedQty.round();
                                      await _printProductBarcodeLabel(
                                        productName: productName,
                                        barcode: productBarcode,
                                        quantity: quantity,
                                      );
                                    },
                              icon: const Icon(Icons.print_outlined),
                              label: Text('Print Barcode'.tr()),
                            ),
                            TextButton(
                              onPressed: submitting
                                  ? null
                                  : () =>
                                        Navigator.of(dialogContext).pop(false),
                              child: Text('Cancel'.tr()),
                            ),
                            FilledButton(
                              onPressed: submitting
                                  ? null
                                  : () async {
                                      if (!formKey.currentState!.validate()) {
                                        return;
                                      }

                                      final qty =
                                          _parseFlexibleNumber(
                                            openingQty.text,
                                          ) ??
                                          0;
                                      final sale = _parseFlexibleNumber(
                                        salePriceRetail.text,
                                      );
                                      final half = _parseFlexibleNumber(
                                        salePriceHalfWholesale.text,
                                      );
                                      final whole = _parseFlexibleNumber(
                                        salePriceWholesale.text,
                                      );
                                      final purchase = _parseFlexibleNumber(
                                        purchasePrice.text,
                                      );
                                      final low = _parseFlexibleNumber(
                                        lowStock.text,
                                      );

                                      final product = Product(
                                        id: null,
                                        name: name.text.trim(),
                                        barcode:
                                            _normalizeDigits(
                                              barcode.text,
                                            ).trim().isEmpty
                                            ? null
                                            : _normalizeDigits(
                                                barcode.text,
                                              ).trim(),
                                        categoryId: null,
                                        unitType: unit,
                                        salePrice: sale ?? 0,
                                        salePriceHalfWholesale: half ?? 0,
                                        salePriceWholesale: whole ?? 0,
                                        purchasePrice: purchase ?? 0,
                                        lowStockThreshold: low ?? 0,
                                      );

                                      setDialogState(() {
                                        submitting = true;
                                        submitError = null;
                                      });

                                      try {
                                        await _productRepository
                                            .createProductWithInitialStock(
                                              product,
                                              initialQuantity: qty,
                                            );
                                        if (!dialogContext.mounted) return;
                                        Navigator.of(dialogContext).pop(true);
                                      } catch (e) {
                                        if (!dialogContext.mounted) return;
                                        final errorText = e.toString();
                                        setDialogState(() {
                                          submitError =
                                              errorText.contains(
                                                'UNIQUE constraint failed: products.barcode',
                                              )
                                              ? 'Barcode already exists.'.tr()
                                              : '${'Save failed'.tr()}: $e';
                                          submitting = false;
                                        });
                                      }
                                    },
                              child: Text(
                                submitting ? 'Saving...'.tr() : 'Save'.tr(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );

      if (saved == true) {
        await _refreshRows();
        if (!mounted) return;
        _showLatestSnackBar('Product saved'.tr());
      }
    } finally {
      _disposeControllersSafely(<TextEditingController>[
        name,
        barcode,
        salePriceRetail,
        salePriceHalfWholesale,
        salePriceWholesale,
        purchasePrice,
        lowStock,
        openingQty,
      ]);
    }
  }

  Future<void> _editInventoryProduct(InventoryStockRow row) async {
    final products = await _productRepository.listProductsByIds([
      row.productId,
    ]);
    if (!mounted) return;
    if (products.isEmpty) {
      _showLatestSnackBar('Product not found.'.tr());
      return;
    }

    final existing = products.first;
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: existing.name);
    final barcode = TextEditingController(text: existing.barcode ?? '');
    final salePriceRetail = TextEditingController(
      text: existing.salePrice.toStringAsFixed(2),
    );
    final salePriceHalfWholesale = TextEditingController(
      text: existing.salePriceHalfWholesale.toStringAsFixed(2),
    );
    final salePriceWholesale = TextEditingController(
      text: existing.salePriceWholesale.toStringAsFixed(2),
    );
    final purchasePrice = TextEditingController(
      text: existing.purchasePrice.toStringAsFixed(2),
    );
    final lowStock = TextEditingController(
      text: existing.lowStockThreshold.toStringAsFixed(0),
    );
    var unit = existing.unitType;

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final size = MediaQuery.sizeOf(dialogContext);
          final maxWidth = (size.width * 0.92).clamp(300.0, 460.0);
          final maxHeight = (size.height * 0.9).clamp(340.0, 700.0);
          var submitting = false;
          String? submitError;

          return StatefulBuilder(
            builder: (dialogContext, setDialogState) => Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxWidth,
                  maxHeight: maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Product'.tr(),
                        style: Theme.of(dialogContext).textTheme.titleLarge,
                      ),
                      if (submitError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          submitError!,
                          style: TextStyle(
                            color: Theme.of(dialogContext).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Form(
                            key: formKey,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextFormField(
                                  controller: name,
                                  decoration: InputDecoration(
                                    labelText: 'Name'.tr(),
                                  ),
                                  validator: (value) =>
                                      (value == null || value.trim().isEmpty)
                                      ? 'Name is required'.tr()
                                      : null,
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: barcode,
                                  decoration: InputDecoration(
                                    labelText: 'Barcode (optional)'.tr(),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<UnitType>(
                                  initialValue: unit,
                                  decoration: InputDecoration(
                                    labelText: 'Unit Type'.tr(),
                                  ),
                                  items: UnitType.values
                                      .map(
                                        (e) => DropdownMenuItem<UnitType>(
                                          value: e,
                                          child: Text(e.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setDialogState(() => unit = value);
                                    }
                                  },
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: salePriceRetail,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9٠-٩.,٫٬]'),
                                    ),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Retail Price'.tr(),
                                    hintText: '0',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: salePriceHalfWholesale,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9٠-٩.,٫٬]'),
                                    ),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Half Wholesale Price'.tr(),
                                    hintText: '0',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: salePriceWholesale,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9٠-٩.,٫٬]'),
                                    ),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Wholesale Price'.tr(),
                                    hintText: '0',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: purchasePrice,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9٠-٩.,٫٬]'),
                                    ),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Purchase Price'.tr(),
                                    hintText: '0',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: lowStock,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9٠-٩.,٫٬]'),
                                    ),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Low Stock Threshold'.tr(),
                                    hintText: '0',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TextButton(
                              onPressed: submitting
                                  ? null
                                  : () =>
                                        Navigator.of(dialogContext).pop(false),
                              child: Text('Cancel'.tr()),
                            ),
                            FilledButton(
                              onPressed: submitting
                                  ? null
                                  : () async {
                                      if (!formKey.currentState!.validate()) {
                                        return;
                                      }

                                      final sale = _parseFlexibleNumber(
                                        salePriceRetail.text,
                                      );
                                      final half = _parseFlexibleNumber(
                                        salePriceHalfWholesale.text,
                                      );
                                      final whole = _parseFlexibleNumber(
                                        salePriceWholesale.text,
                                      );
                                      final purchase = _parseFlexibleNumber(
                                        purchasePrice.text,
                                      );
                                      final low = _parseFlexibleNumber(
                                        lowStock.text,
                                      );

                                      if (sale == null ||
                                          half == null ||
                                          whole == null ||
                                          purchase == null ||
                                          low == null) {
                                        setDialogState(() {
                                          submitError =
                                              'Please enter valid numeric values.'
                                                  .tr();
                                        });
                                        return;
                                      }

                                      if (purchase > 0 &&
                                          (sale < purchase ||
                                              half < purchase ||
                                              whole < purchase)) {
                                        setDialogState(() {
                                          submitError =
                                              'Sale price cannot be less than purchase price.'
                                                  .tr();
                                        });
                                        return;
                                      }

                                      setDialogState(() {
                                        submitting = true;
                                        submitError = null;
                                      });

                                      try {
                                        await _productRepository.updateProduct(
                                          existing.copyWith(
                                            name: name.text.trim(),
                                            barcode: barcode.text.trim().isEmpty
                                                ? null
                                                : barcode.text.trim(),
                                            unitType: unit,
                                            salePrice: sale,
                                            salePriceHalfWholesale: half,
                                            salePriceWholesale: whole,
                                            purchasePrice: purchase,
                                            lowStockThreshold: low,
                                          ),
                                        );
                                        if (!dialogContext.mounted) return;
                                        Navigator.of(dialogContext).pop(true);
                                      } catch (e) {
                                        if (!dialogContext.mounted) return;
                                        final errorText = e.toString();
                                        setDialogState(() {
                                          submitError =
                                              errorText.contains(
                                                'UNIQUE constraint failed: products.barcode',
                                              )
                                              ? 'Barcode already exists.'.tr()
                                              : '${'Save failed'.tr()}: $e';
                                          submitting = false;
                                        });
                                      }
                                    },
                              child: Text(
                                submitting ? 'Saving...'.tr() : 'Save'.tr(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );

      if (saved == true && mounted) {
        _showLatestSnackBar('Product updated'.tr());
      }
    } finally {
      _disposeControllersSafely(<TextEditingController>[
        name,
        barcode,
        salePriceRetail,
        salePriceHalfWholesale,
        salePriceWholesale,
        purchasePrice,
        lowStock,
      ]);
    }
  }

  Future<void> _deleteInventoryProduct(InventoryStockRow row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Delete Product'.tr()),
          content: Text('Are you sure you want to delete this product?'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('Cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              child: Text('Delete'.tr()),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await _productRepository.deleteProduct(row.productId);
      if (!mounted) return;
      _showLatestSnackBar('Product deleted successfully'.tr());
    } catch (e) {
      if (!mounted) return;
      var message = e.toString();
      const badStatePrefix = 'Bad state: ';
      if (message.startsWith(badStatePrefix)) {
        message = message.substring(badStatePrefix.length);
      }
      _showLatestSnackBar(trIfExists(message, context: context));
    }
  }

  Future<void> _deleteSelectedInventoryProducts() async {
    if (_selectedProductIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Delete selected'.tr()),
          content: Text(
            '${'Are you sure you want to delete selected products?'.tr()} (${_selectedProductIds.length})',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('Cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              child: Text('Delete'.tr()),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    var deleted = 0;
    var failed = 0;
    final selected = _selectedProductIds.toList(growable: false);
    for (final productId in selected) {
      try {
        await _productRepository.deleteProduct(productId);
        deleted++;
      } catch (_) {
        failed++;
      }
    }

    if (!mounted) return;
    await _refreshRows();
    if (!mounted) return;

    setState(() {
      _selectedProductIds.clear();
      _selectionMode = false;
    });

    _showLatestSnackBar(
      '${'Deleted'.tr()}: $deleted • ${'Failed'.tr()}: $failed',
    );
  }

  Future<void> _downloadImportTemplate() async {
    if (_savingImportTemplate) return;
    setState(() => _savingImportTemplate = true);
    try {
      final targetPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Download Template'.tr(),
        fileName: 'inventory_import_template.xlsx',
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
      );

      if (!mounted) return;
      if (targetPath == null || targetPath.trim().isEmpty) return;

      await _inventoryTemplateService.saveArabicTemplate(
        targetPath: targetPath,
      );
      if (!mounted) return;
      _showLatestSnackBar('Template saved successfully.'.tr());
    } catch (e) {
      if (!mounted) return;
      _showLatestSnackBar('${'Template save failed'.tr()}: $e');
    } finally {
      if (mounted) {
        setState(() => _savingImportTemplate = false);
      }
    }
  }

  Future<void> _importProductsToInventory() async {
    if (_importingProducts) return;
    setState(() => _importingProducts = true);
    try {
      final fileResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'xls', 'csv'],
        withData: true,
        allowMultiple: false,
      );

      if (!mounted) return;
      if (fileResult == null || fileResult.files.isEmpty) return;

      final selectedFile = fileResult.files.single;
      final fileName = selectedFile.name.trim();
      if (fileName.isEmpty) {
        _showLatestSnackBar('Invalid import file.'.tr());
        return;
      }

      var bytes = selectedFile.bytes;
      if (bytes == null || bytes.isEmpty) {
        final filePath = selectedFile.path;
        if (filePath == null || filePath.trim().isEmpty) {
          _showLatestSnackBar('Unable to read selected file.'.tr());
          return;
        }
        bytes = await File(filePath).readAsBytes();
      }

      final parseResult = _inventoryImportService.parse(
        fileBytes: bytes,
        fileName: fileName,
      );

      if (!mounted) return;
      if (parseResult.rows.isEmpty) {
        _showLatestSnackBar('No valid rows to import.'.tr());
        return;
      }

      final reviewedRows = await _showProductsImportReviewDialog(parseResult);
      if (!mounted || reviewedRows == null || reviewedRows.isEmpty) return;

      final applyStats = await _applyImportedRows(reviewedRows);

      if (!mounted) return;
      await _refreshRows();
      if (!mounted) return;
      _showLatestSnackBar(
        '${'Import completed'.tr()}. ${'Rows created'.tr()}: ${applyStats.$1}  •  ${'Rows updated'.tr()}: ${applyStats.$2}',
      );
    } catch (e) {
      if (!mounted) return;
      _showLatestSnackBar(
        '${'Import failed'.tr()}: ${_localizedImportExceptionMessage(e)}',
      );
    } finally {
      if (mounted) {
        setState(() => _importingProducts = false);
      }
    }
  }

  String _localizedImportExceptionMessage(Object error) {
    var message = error.toString();
    const badStatePrefix = 'Bad state: ';
    const formatPrefix = 'FormatException: ';
    if (message.startsWith(badStatePrefix)) {
      message = message.substring(badStatePrefix.length);
    }
    if (message.startsWith(formatPrefix)) {
      message = message.substring(formatPrefix.length);
    }

    if (message.startsWith('Unsupported file type:')) {
      return 'Unsupported file type.'.tr();
    }

    switch (message.trim()) {
      case 'The selected file is empty.':
      case 'The selected file does not contain headers.':
      case 'Missing required columns. Expected Quantity and Name. Barcode is optional.':
        return message.trim().tr();
      default:
        return message;
    }
  }

  Future<(int, int)> _applyImportedRows(
    List<InventoryProductsImportRow> rows,
  ) async {
    final products = await _productRepository.listProducts();
    final byBarcode = <String, Product>{
      for (final p in products)
        if ((p.barcode ?? '').trim().isNotEmpty) (p.barcode ?? '').trim(): p,
    };
    final byName = <String, Product>{
      for (final p in products) p.name.trim().toLowerCase(): p,
    };

    var created = 0;
    var updated = 0;

    for (final row in rows) {
      final barcode = (row.product.barcode ?? '').trim();
      final nameKey = row.product.name.trim().toLowerCase();
      final existing = barcode.isNotEmpty
          ? byBarcode[barcode] ?? byName[nameKey]
          : byName[nameKey];

      if (existing == null || existing.id == null) {
        final createdProduct = await _productRepository
            .createProductWithInitialStock(
              Product(
                id: null,
                name: row.product.name,
                barcode: row.product.barcode,
                categoryId: null,
                unitType: row.product.unitType,
                salePrice: row.product.salePrice,
                salePriceHalfWholesale: row.product.salePriceHalfWholesale,
                salePriceWholesale: row.product.salePriceWholesale,
                purchasePrice: row.product.purchasePrice,
                lowStockThreshold: row.product.lowStockThreshold,
              ),
              initialQuantity: row.openingQuantity,
            );
        created++;

        final createdBarcode = (createdProduct.barcode ?? '').trim();
        if (createdBarcode.isNotEmpty) {
          byBarcode[createdBarcode] = createdProduct;
        }
        byName[createdProduct.name.trim().toLowerCase()] = createdProduct;
        continue;
      }

      final updatedProduct = existing.copyWith(
        name: row.product.name,
        barcode: row.product.barcode,
        unitType: row.product.unitType,
        salePrice: row.product.salePrice,
        salePriceHalfWholesale: row.product.salePriceHalfWholesale,
        salePriceWholesale: row.product.salePriceWholesale,
        purchasePrice: row.product.purchasePrice,
        lowStockThreshold: row.product.lowStockThreshold,
      );

      await _productRepository.updateProduct(updatedProduct);
      if (row.openingQuantity > 0) {
        await _productRepository.addOpeningStockMovement(
          productId: existing.id!,
          unitType: row.product.unitType,
          quantity: row.openingQuantity,
        );
      }
      updated++;

      final updatedBarcode = (updatedProduct.barcode ?? '').trim();
      if (updatedBarcode.isNotEmpty) {
        byBarcode[updatedBarcode] = updatedProduct;
      }
      byName[updatedProduct.name.trim().toLowerCase()] = updatedProduct;
    }

    return (created, updated);
  }

  Future<List<InventoryProductsImportRow>?> _showProductsImportReviewDialog(
    InventoryProductsImportParseResult result,
  ) async {
    final width = (MediaQuery.sizeOf(context).width * 0.94).clamp(
      460.0,
      1020.0,
    );
    final drafts = List<InventoryProductsImportRow>.from(result.rows);

    return showDialog<List<InventoryProductsImportRow>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Dialog(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width, maxHeight: 700),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Review product rows before saving.'.tr(),
                        style: Theme.of(dialogContext).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Edit imported products before they are added to products list.'
                            .tr(),
                        style: Theme.of(dialogContext).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: width - 64),
                            child: SingleChildScrollView(
                              child: DataTable(
                                columnSpacing: 14,
                                horizontalMargin: 10,
                                columns: [
                                  DataColumn(label: Text('Name'.tr())),
                                  DataColumn(
                                    label: Text('Barcode (optional)'.tr()),
                                  ),
                                  DataColumn(label: Text('Unit Type'.tr())),
                                  DataColumn(
                                    numeric: true,
                                    label: Text('Retail Price'.tr()),
                                  ),
                                  DataColumn(
                                    numeric: true,
                                    label: Text('Purchase Price'.tr()),
                                  ),
                                  DataColumn(
                                    numeric: true,
                                    label: Text('Opening Quantity'.tr()),
                                  ),
                                  DataColumn(label: Text('Actions'.tr())),
                                ],
                                rows: [
                                  for (var i = 0; i < drafts.length; i++)
                                    DataRow(
                                      cells: [
                                        DataCell(Text(drafts[i].product.name)),
                                        DataCell(
                                          Text(
                                            (drafts[i].product.barcode ?? '')
                                                    .trim()
                                                    .isEmpty
                                                ? '-'
                                                : drafts[i].product.barcode!
                                                      .trim(),
                                          ),
                                        ),
                                        DataCell(
                                          Text(drafts[i].product.unitType.name),
                                        ),
                                        DataCell(
                                          Text(
                                            drafts[i].product.salePrice
                                                .toStringAsFixed(2),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            drafts[i].product.purchasePrice
                                                .toStringAsFixed(2),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            drafts[i].openingQuantity
                                                .toStringAsFixed(2),
                                          ),
                                        ),
                                        DataCell(
                                          OutlinedButton.icon(
                                            onPressed: () async {
                                              final edited =
                                                  await _editImportedInventoryRow(
                                                    dialogContext,
                                                    drafts[i],
                                                  );
                                              if (edited == null ||
                                                  !dialogContext.mounted) {
                                                return;
                                              }
                                              setDialogState(
                                                () => drafts[i] = edited,
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                            ),
                                            label: Text('Edit Product'.tr()),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(null),
                            child: Text('Cancel Import'.tr()),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () => Navigator.of(dialogContext).pop(
                              List<InventoryProductsImportRow>.unmodifiable(
                                drafts,
                              ),
                            ),
                            child: Text('Apply Import'.tr()),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<InventoryProductsImportRow?> _editImportedInventoryRow(
    BuildContext context,
    InventoryProductsImportRow row,
  ) async {
    final edited = await _showInventoryImportEditDialog(context, row);
    if (edited == null) return null;

    return InventoryProductsImportRow(
      product: ProductsImportRow(
        name: edited.product.name,
        barcode: edited.product.barcode,
        unitType: edited.product.unitType,
        salePrice: edited.product.salePrice,
        salePriceHalfWholesale: edited.product.salePriceHalfWholesale,
        salePriceWholesale: edited.product.salePriceWholesale,
        purchasePrice: edited.product.purchasePrice,
        lowStockThreshold: edited.product.lowStockThreshold,
      ),
      openingQuantity: edited.openingQuantity,
    );
  }

  Future<_InventoryImportDraft?> _showInventoryImportEditDialog(
    BuildContext context,
    InventoryProductsImportRow row,
  ) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: row.product.name);
    final barcode = TextEditingController(text: row.product.barcode ?? '');
    final salePriceRetail = TextEditingController(
      text: row.product.salePrice.toStringAsFixed(2),
    );
    final salePriceHalfWholesale = TextEditingController(
      text: row.product.salePriceHalfWholesale.toStringAsFixed(2),
    );
    final salePriceWholesale = TextEditingController(
      text: row.product.salePriceWholesale.toStringAsFixed(2),
    );
    final purchasePrice = TextEditingController(
      text: row.product.purchasePrice.toStringAsFixed(2),
    );
    final lowStock = TextEditingController(
      text: row.product.lowStockThreshold.toStringAsFixed(0),
    );
    final openingQty = TextEditingController(
      text: row.openingQuantity.toStringAsFixed(
        (row.openingQuantity - row.openingQuantity.roundToDouble()).abs() <
                0.000001
            ? 0
            : 2,
      ),
    );
    var unit = row.product.unitType;

    try {
      return await showDialog<_InventoryImportDraft>(
        context: context,
        builder: (dialogContext) {
          final size = MediaQuery.sizeOf(dialogContext);
          final maxWidth = (size.width * 0.92).clamp(300.0, 460.0);
          final maxHeight = (size.height * 0.9).clamp(380.0, 720.0);
          String? submitError;

          return StatefulBuilder(
            builder: (dialogContext, setDialogState) => Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxWidth,
                  maxHeight: maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Product'.tr(),
                        style: Theme.of(dialogContext).textTheme.titleLarge,
                      ),
                      if (submitError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          submitError!,
                          style: TextStyle(
                            color: Theme.of(dialogContext).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Form(
                            key: formKey,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextFormField(
                                  controller: name,
                                  decoration: InputDecoration(
                                    labelText: 'Name'.tr(),
                                  ),
                                  validator: (value) =>
                                      (value == null || value.trim().isEmpty)
                                      ? 'Name is required'.tr()
                                      : null,
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: barcode,
                                  decoration: InputDecoration(
                                    labelText: 'Barcode (optional)'.tr(),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<UnitType>(
                                  initialValue: unit,
                                  decoration: InputDecoration(
                                    labelText: 'Unit Type'.tr(),
                                  ),
                                  items: UnitType.values
                                      .map(
                                        (e) => DropdownMenuItem<UnitType>(
                                          value: e,
                                          child: Text(e.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setDialogState(() => unit = value);
                                    }
                                  },
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: openingQty,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9٠-٩.,٫٬]'),
                                    ),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Opening Quantity'.tr(),
                                  ),
                                  validator: (value) {
                                    final qty = _parseFlexibleNumber(
                                      value ?? '',
                                    );
                                    if (qty == null) {
                                      return 'Enter a valid quantity.'.tr();
                                    }
                                    if (qty < 0) {
                                      return 'Quantity must be zero or greater.'
                                          .tr();
                                    }
                                    if (unit == UnitType.piece &&
                                        (qty - qty.roundToDouble()).abs() >
                                            0.000001) {
                                      return 'Piece products require integer quantity.'
                                          .tr();
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: salePriceRetail,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9٠-٩.,٫٬]'),
                                    ),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Retail Price'.tr(),
                                    hintText: '0',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: salePriceHalfWholesale,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9٠-٩.,٫٬]'),
                                    ),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Half Wholesale Price'.tr(),
                                    hintText: '0',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: salePriceWholesale,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9٠-٩.,٫٬]'),
                                    ),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Wholesale Price'.tr(),
                                    hintText: '0',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: purchasePrice,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9٠-٩.,٫٬]'),
                                    ),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Purchase Price'.tr(),
                                    hintText: '0',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: lowStock,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9٠-٩.,٫٬]'),
                                    ),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Low Stock Threshold'.tr(),
                                    hintText: '0',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                              child: Text('Cancel'.tr()),
                            ),
                            FilledButton(
                              onPressed: () {
                                if (!formKey.currentState!.validate()) {
                                  return;
                                }

                                final qty = _parseFlexibleNumber(
                                  openingQty.text,
                                );
                                final sale = _parseFlexibleNumber(
                                  salePriceRetail.text,
                                );
                                final half = _parseFlexibleNumber(
                                  salePriceHalfWholesale.text,
                                );
                                final whole = _parseFlexibleNumber(
                                  salePriceWholesale.text,
                                );
                                final purchase = _parseFlexibleNumber(
                                  purchasePrice.text,
                                );
                                final low = _parseFlexibleNumber(lowStock.text);

                                if (qty == null ||
                                    sale == null ||
                                    half == null ||
                                    whole == null ||
                                    purchase == null ||
                                    low == null) {
                                  setDialogState(() {
                                    submitError =
                                        'Please enter valid numeric values.'
                                            .tr();
                                  });
                                  return;
                                }

                                if (purchase > 0 &&
                                    (sale < purchase ||
                                        half < purchase ||
                                        whole < purchase)) {
                                  setDialogState(() {
                                    submitError =
                                        'Sale price cannot be less than purchase price.'
                                            .tr();
                                  });
                                  return;
                                }

                                final payload = Product(
                                  id: null,
                                  name: name.text.trim(),
                                  barcode: barcode.text.trim().isEmpty
                                      ? null
                                      : barcode.text.trim(),
                                  categoryId: null,
                                  unitType: unit,
                                  salePrice: sale,
                                  salePriceHalfWholesale: half,
                                  salePriceWholesale: whole,
                                  purchasePrice: purchase,
                                  lowStockThreshold: low,
                                );

                                Navigator.of(dialogContext).pop(
                                  _InventoryImportDraft(
                                    product: payload,
                                    openingQuantity: qty,
                                  ),
                                );
                              },
                              child: Text('Save'.tr()),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    } finally {
      _disposeControllersSafely(<TextEditingController>[
        name,
        barcode,
        salePriceRetail,
        salePriceHalfWholesale,
        salePriceWholesale,
        purchasePrice,
        lowStock,
        openingQty,
      ]);
    }
  }
}

class _InventoryImportDraft {
  const _InventoryImportDraft({
    required this.product,
    required this.openingQuantity,
  });

  final Product product;
  final double openingQuantity;
}
