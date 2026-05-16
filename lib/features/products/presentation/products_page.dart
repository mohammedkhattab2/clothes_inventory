import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:clothes_inventory/features/products/data/product_repository.dart';
import 'package:clothes_inventory/features/products/data/products_csv_service.dart';
import 'package:clothes_inventory/features/products/data/products_import_service.dart';
import 'package:clothes_inventory/features/products/data/products_import_template_service.dart';
import 'package:clothes_inventory/features/products/data/products_pdf_service.dart';
import 'package:clothes_inventory/features/products/domain/product.dart';
import 'package:clothes_inventory/features/products/presentation/products_cubit.dart';
import 'package:clothes_inventory/features/products/presentation/widgets/product_form_dialog.dart';
import 'package:clothes_inventory/features/products/presentation/widgets/products_page_layout.dart';
import 'package:clothes_inventory/features/products/presentation/widgets/products_table_section.dart';
import 'package:clothes_inventory/services/di/service_locator.dart';
import 'package:clothes_inventory/services/printing/product_barcode_label_printer.dart';
import 'package:clothes_inventory/services/printing/thermal_printer_preferences.dart';
import 'package:clothes_inventory/services/platform/folder_opener_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

enum _StockFilter { all, low, out }

enum _ProductSortKey { name, stock, salePrice }

class _ProductsPageState extends State<ProductsPage> {
  static const _prefsQueryKey = 'products.query';
  static const _prefsBarcodeKey = 'products.barcode';
  static const _prefsStockFilterKey = 'products.stockFilter';
  static const _prefsSortKey = 'products.sortKey';
  static const _prefsSortAscKey = 'products.sortAscending';

  Timer? _debounce;
  late final ProductsCubit _productsCubit;
  late final ProductRepository _productRepository;
  late final ProductBarcodeLabelPrinter _barcodeLabelPrinter;
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _leftColumnSearchController = TextEditingController();
  final _rightColumnSearchController = TextEditingController();
  _StockFilter _stockFilter = _StockFilter.all;
  _ProductSortKey _sortKey = _ProductSortKey.stock;
  bool _sortAscending = true;
  _ProductSortKey _leftSortKey = _ProductSortKey.stock;
  _ProductSortKey _rightSortKey = _ProductSortKey.stock;
  bool _leftSortAscending = true;
  bool _rightSortAscending = true;
  String _leftColumnQuery = '';
  String _rightColumnQuery = '';
  bool _exportingPdf = false;
  bool _exportingCsv = false;
  bool _importingProducts = false;
  bool _savingImportTemplate = false;
  String? _lastExportPath;
  bool _selectionMode = false;
  final Set<int> _selectedProductIds = <int>{};

  @override
  void initState() {
    super.initState();
    _productsCubit = getIt<ProductsCubit>();
    _productRepository = getIt<ProductRepository>();
    _barcodeLabelPrinter = const ProductBarcodeLabelPrinter(
      paperWidthMm: 58,
      printerPrefs: ThermalPrinterPreferences(),
    );
    _restoreProductsPageState();
    _productRepository.productsRevisionListenable.addListener(
      _onProductsRepositoryRevision,
    );
  }

  void _onProductsRepositoryRevision() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _productsCubit.load(withLoading: false);
    });
  }

  @override
  void dispose() {
    _productRepository.productsRevisionListenable.removeListener(
      _onProductsRepositoryRevision,
    );
    _debounce?.cancel();
    _nameController.dispose();
    _barcodeController.dispose();
    _leftColumnSearchController.dispose();
    _rightColumnSearchController.dispose();
    _productsCubit.close();
    super.dispose();
  }

  Future<void> _restoreProductsPageState() async {
    final prefs = await SharedPreferences.getInstance();
    final query = prefs.getString(_prefsQueryKey) ?? '';
    final barcode = prefs.getString(_prefsBarcodeKey) ?? '';
    final filterIndex = prefs.getInt(_prefsStockFilterKey);
    final sortKeyIndex = prefs.getInt(_prefsSortKey);
    final sortAsc = prefs.getBool(_prefsSortAscKey);

    if (!mounted) return;

    setState(() {
      _nameController.text = query;
      _barcodeController.text = barcode;
      if (filterIndex != null &&
          filterIndex >= 0 &&
          filterIndex < _StockFilter.values.length) {
        _stockFilter = _StockFilter.values[filterIndex];
      }
      if (sortKeyIndex != null &&
          sortKeyIndex >= 0 &&
          sortKeyIndex < _ProductSortKey.values.length) {
        _sortKey = _ProductSortKey.values[sortKeyIndex];
      }
      if (sortAsc != null) {
        _sortAscending = sortAsc;
      }
    });

    await _productsCubit.setFilters(query: query, barcode: barcode);
  }

  Future<void> _persistProductsPageState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsQueryKey, _nameController.text);
    await prefs.setString(_prefsBarcodeKey, _barcodeController.text);
    await prefs.setInt(_prefsStockFilterKey, _stockFilter.index);
    await prefs.setInt(_prefsSortKey, _sortKey.index);
    await prefs.setBool(_prefsSortAscKey, _sortAscending);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 900;
    final isDenseViewport = size.height < 820 || size.width < 1180;
    final isVeryDenseViewport = size.height < 700 || size.width < 1024;
    return BlocProvider.value(
      value: _productsCubit,
      child: BlocBuilder<ProductsCubit, ProductsState>(
        builder: (context, state) {
          final lowStockCount = state.items.where(_isLowStock).length;
          final outOfStockCount = state.items.where(_isOutOfStock).length;
          final visibleItems = _visibleItems(state.items);
          _selectedProductIds.removeWhere(
            (id) => !state.items.any((p) => p.id == id),
          );
          return ProductsPageLayout(
            isCompact: isCompact,
            isDenseViewport: isDenseViewport,
            isVeryDenseViewport: isVeryDenseViewport,
            nameController: _nameController,
            barcodeController: _barcodeController,
            totalProductsCount: state.items.length,
            lowStockCount: lowStockCount,
            outOfStockCount: outOfStockCount,
            stockFilterIndex: _stockFilter.index,
            exportingPdf: _exportingPdf,
            exportingCsv: _exportingCsv,
            importingProducts: _importingProducts,
            savingImportTemplate: _savingImportTemplate,
            lastExportPath: _lastExportPath,
            selectionMode: _selectionMode,
            selectedCount: _selectedProductIds.length,
            tableWidget: ProductsTableSection(
              visibleItems: visibleItems,
              isAllStockFilter: _stockFilter == _StockFilter.all,
              sortKeyIndex: _sortKey.index,
              sortAscending: _sortAscending,
              leftSortKeyIndex: _leftSortKey.index,
              leftSortAscending: _leftSortAscending,
              rightSortKeyIndex: _rightSortKey.index,
              rightSortAscending: _rightSortAscending,
              leftColumnSearchController: _leftColumnSearchController,
              rightColumnSearchController: _rightColumnSearchController,
              leftColumnQuery: _leftColumnQuery,
              rightColumnQuery: _rightColumnQuery,
              onLeftColumnQueryChanged: (value) {
                setState(() => _leftColumnQuery = value);
              },
              onRightColumnQueryChanged: (value) {
                setState(() => _rightColumnQuery = value);
              },
              onMainSortRequested: (sortKeyIndex) {
                _setSort(_ProductSortKey.values[sortKeyIndex]);
              },
              onLeftSortChanged: (sortKeyIndex) {
                _setColumnSort(
                  isLeft: true,
                  key: _ProductSortKey.values[sortKeyIndex],
                );
              },
              onRightSortChanged: (sortKeyIndex) {
                _setColumnSort(
                  isLeft: false,
                  key: _ProductSortKey.values[sortKeyIndex],
                );
              },
              onEditProduct: (product) => _showProductDialog(context, product),
              onDeleteProduct: (product) {
                _productsCubit.delete(product.id!);
              },
              selectionMode: _selectionMode,
              selectedProductIds: _selectedProductIds,
              onSelectionChanged: (productId, selected) {
                setState(() {
                  if (selected) {
                    _selectedProductIds.add(productId);
                  } else {
                    _selectedProductIds.remove(productId);
                  }
                });
              },
              onSelectAllChanged: (productIds, selected) {
                setState(() {
                  if (selected) {
                    _selectedProductIds.addAll(productIds);
                  } else {
                    _selectedProductIds.removeAll(productIds);
                  }
                });
              },
            ),
            error: state.error,
            loading: state.loading,
            onAddProduct: () => _showProductDialog(context),
            onNameChanged: _onNameChanged,
            onBarcodeChanged: _onBarcodeChanged,
            onClearSearch: () async {
              _nameController.clear();
              _barcodeController.clear();
              await _productsCubit.clearSearch();
              _persistProductsPageState();
            },
            onStockFilterChanged: (index) {
              setState(() => _stockFilter = _StockFilter.values[index]);
              _persistProductsPageState();
            },
            onRefresh: () => _productsCubit.load(),
            onExportPdf: () => _exportProductsPdf(context, visibleItems),
            onExportCsv: () => _exportProductsCsv(context, visibleItems),
            onImportProducts: () => _importProductsFromFile(context),
            onDownloadImportTemplate: () => _downloadImportTemplate(context),
            onOpenFolder: () => _openExportFolder(context),
            onToggleSelectionMode: () {
              setState(() {
                _selectionMode = !_selectionMode;
                if (!_selectionMode) {
                  _selectedProductIds.clear();
                }
              });
            },
            onDeleteSelected: () => _deleteSelectedProducts(context),
          );
        },
      ),
    );
  }

  bool _isLowStock(Product product) {
    return product.lowStockThreshold > 0 &&
        product.currentStock <= product.lowStockThreshold;
  }

  bool _isOutOfStock(Product product) {
    return product.currentStock <= 0;
  }

  List<Product> _visibleItems(List<Product> sourceItems) {
    return switch (_stockFilter) {
      _StockFilter.low => sourceItems.where(_isLowStock).toList(),
      _StockFilter.out => sourceItems.where(_isOutOfStock).toList(),
      _StockFilter.all => sourceItems,
    };
  }

  void _setColumnSort({required bool isLeft, required _ProductSortKey key}) {
    setState(() {
      if (isLeft) {
        if (_leftSortKey == key) {
          _leftSortAscending = !_leftSortAscending;
        } else {
          _leftSortKey = key;
          _leftSortAscending = true;
        }
      } else {
        if (_rightSortKey == key) {
          _rightSortAscending = !_rightSortAscending;
        } else {
          _rightSortKey = key;
          _rightSortAscending = true;
        }
      }
    });
  }

  void _setSort(_ProductSortKey key) {
    setState(() {
      if (_sortKey == key) {
        _sortAscending = !_sortAscending;
      } else {
        _sortKey = key;
        _sortAscending = true;
      }
    });
    _persistProductsPageState();
  }

  Future<void> _exportProductsCsv(
    BuildContext context,
    List<Product> items,
  ) async {
    setState(() => _exportingCsv = true);
    try {
      final path = await getIt<ProductsCsvService>().exportToCsv(items: items);
      if (!context.mounted) return;
      setState(() => _lastExportPath = path);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Products CSV exported'.tr())));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Products export failed'.tr())));
    } finally {
      if (mounted) {
        setState(() => _exportingCsv = false);
      }
    }
  }

  Future<void> _exportProductsPdf(
    BuildContext context,
    List<Product> items,
  ) async {
    setState(() => _exportingPdf = true);
    try {
      final path = await getIt<ProductsPdfService>().exportToPdf(items: items);
      if (!context.mounted) return;
      setState(() => _lastExportPath = path);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Products PDF exported'.tr())));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Products PDF export failed'.tr())),
      );
    } finally {
      if (mounted) {
        setState(() => _exportingPdf = false);
      }
    }
  }

  Future<void> _openExportFolder(BuildContext context) async {
    final path = _lastExportPath;
    if (path == null) return;
    final opened = await getIt<FolderOpenerService>().openContainingFolder(
      path,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open export folder.'.tr())),
      );
    }
  }

  Future<void> _importProductsFromFile(BuildContext context) async {
    if (_importingProducts) return;

    setState(() => _importingProducts = true);
    try {
      final fileResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'xls', 'csv'],
        withData: true,
        allowMultiple: false,
      );

      if (!mounted || !context.mounted) return;
      if (fileResult == null || fileResult.files.isEmpty) {
        return;
      }

      final selectedFile = fileResult.files.single;
      final fileName = selectedFile.name.trim();
      if (fileName.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Invalid import file.'.tr())));
        return;
      }

      var bytes = selectedFile.bytes;
      if (bytes == null || bytes.isEmpty) {
        final filePath = selectedFile.path;
        if (filePath == null || filePath.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to read selected file.'.tr())),
          );
          return;
        }
        bytes = await File(filePath).readAsBytes();
      }

      final parseResult = getIt<ProductsImportService>().parse(
        fileBytes: bytes,
        fileName: fileName,
      );

      if (!mounted || !context.mounted) return;

      if (parseResult.rows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No valid rows to import.'.tr())),
        );
        if (parseResult.issues.isNotEmpty || parseResult.warnings.isNotEmpty) {
          await _showProductsImportSummaryDialog(context, parseResult);
        }
        return;
      }

      final shouldApply = await _showProductsImportPreviewDialog(
        context,
        parseResult,
      );
      if (!mounted || !context.mounted || !shouldApply) return;

      final applyResult = await getIt<ProductRepository>()
          .upsertImportedProducts(rows: parseResult.rows);
      await _productsCubit.load(withLoading: false);

      if (!mounted || !context.mounted) return;

      final summary =
          '${'Rows created'.tr()}: ${applyResult.createdCount}  •  ${'Rows updated'.tr()}: ${applyResult.updatedCount}  •  ${'Rows skipped'.tr()}: ${parseResult.skippedRows}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'Import completed'.tr()}. $summary')),
      );

      if (parseResult.issues.isNotEmpty || parseResult.warnings.isNotEmpty) {
        await _showProductsImportSummaryDialog(context, parseResult);
      }
    } catch (e) {
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${'Import failed'.tr()}: ${_localizedProductsImportExceptionMessage(e)}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _importingProducts = false);
      }
    }
  }

  Future<void> _downloadImportTemplate(BuildContext context) async {
    if (_savingImportTemplate) return;

    setState(() => _savingImportTemplate = true);
    try {
      final targetPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Download Product Template'.tr(),
        fileName: 'product_import_template_ar.xlsx',
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
      );

      if (!mounted || !context.mounted) return;
      if (targetPath == null || targetPath.trim().isEmpty) {
        return;
      }

      await getIt<ProductsImportTemplateService>().saveArabicTemplate(
        targetPath: targetPath,
      );

      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Products import template saved successfully.'.tr()),
        ),
      );
    } catch (e) {
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'Products import template save failed'.tr()}: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingImportTemplate = false);
      }
    }
  }

  Future<bool> _showProductsImportPreviewDialog(
    BuildContext context,
    ProductsImportParseResult result,
  ) async {
    final width = (MediaQuery.sizeOf(context).width * 0.9).clamp(420.0, 860.0);
    final previewLines = result.rows
        .map(
          (row) =>
              '${row.name}  •  ${'Barcode'.tr()}: ${row.barcode ?? '-'}  •  ${'Unit Type'.tr()}: ${row.unitType.name}  •  ${'Retail Price'.tr()}: ${row.salePrice.toStringAsFixed(2)}  •  ${'Purchase Price'.tr()}: ${row.purchasePrice.toStringAsFixed(2)}',
        )
        .toList(growable: false);

    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width, maxHeight: 620),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Import Preview'.tr(),
                    style: Theme.of(dialogContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Review product rows before saving.'.tr(),
                    style: Theme.of(dialogContext).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(
                          '${'Rows valid'.tr()}: ${result.rows.length}',
                        ),
                      ),
                      Chip(
                        label: Text(
                          '${'Rows with issues'.tr()}: ${result.issues.length}',
                        ),
                      ),
                      Chip(
                        label: Text(
                          '${'Rows with warnings'.tr()}: ${result.warnings.length}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: previewLines.length,
                      itemBuilder: (previewContext, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('• ${previewLines[index]}'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: Text('Cancel Import'.tr()),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
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

    return approved ?? false;
  }

  Future<void> _showProductsImportSummaryDialog(
    BuildContext context,
    ProductsImportParseResult result,
  ) async {
    final width = (MediaQuery.sizeOf(context).width * 0.9).clamp(360.0, 760.0);
    final issueLines = [
      for (final issue in result.issues)
        '• ${'Row'.tr()} ${issue.rowNumber}: ${_localizedProductsImportIssueMessage(issue.message)}',
    ];
    final warningLines = [
      for (final warning in result.warnings)
        '• ${'Row'.tr()} ${warning.rowNumber}: ${_localizedProductsImportIssueMessage(warning.message)}',
    ];

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width, maxHeight: 560),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Import Summary'.tr(),
                    style: Theme.of(dialogContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Text('${'Rows read'.tr()}: ${result.totalRows}'),
                  Text('${'Rows valid'.tr()}: ${result.rows.length}'),
                  Text('${'Rows skipped'.tr()}: ${result.skippedRows}'),
                  if (warningLines.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      '${'Warnings'.tr()} (${warningLines.length})',
                      style: Theme.of(dialogContext).textTheme.titleSmall,
                    ),
                  ],
                  if (issueLines.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      '${'Errors'.tr()} (${issueLines.length})',
                      style: Theme.of(dialogContext).textTheme.titleSmall,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: [
                        ...warningLines.map((line) => Text(line)),
                        if (warningLines.isNotEmpty && issueLines.isNotEmpty)
                          const SizedBox(height: 8),
                        ...issueLines.map((line) => Text(line)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text('Close'.tr()),
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
  }

  String _localizedProductsImportIssueMessage(String raw) {
    switch (raw) {
      case 'Name is required for each imported row.':
      case 'Duplicate barcode in file. Last row was used for this barcode.':
      case 'Invalid unit type. Use piece/weight or قطعة/وزن.':
      case 'Invalid retail price.':
      case 'Invalid half wholesale price.':
      case 'Invalid wholesale price.':
      case 'Invalid purchase price.':
      case 'Invalid low stock threshold.':
      case 'Numeric values must be zero or positive.':
      case 'Sale price cannot be less than purchase price.':
        return raw.tr();
      default:
        return raw;
    }
  }

  String _localizedProductsImportExceptionMessage(Object error) {
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
      case 'Missing required columns. Expected Name column.':
        return message.trim().tr();
      default:
        return message;
    }
  }

  void _onNameChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _productsCubit.searchByName(query);
      _persistProductsPageState();
    });
  }

  void _onBarcodeChanged(String barcode) {
    _productsCubit.searchByBarcode(barcode);
    _persistProductsPageState();
  }

  Future<void> _showProductDialog(
    BuildContext context, [
    Product? product,
  ]) async {
    await showDialog<void>(
      context: context,
      builder: (_) => ProductFormDialog(
        product: product,
        onGenerateBarcode: () => _productRepository.generateNextShortBarcode(),
        onPrintBarcode: _printProductBarcodeLabel,
        barcodeLabelPrinter: _barcodeLabelPrinter,
        onSave: (payload) async {
          if (product == null) {
            await _productsCubit.create(payload);
          } else {
            await _productsCubit.update(payload);
          }
        },
      ),
    );
  }

  Future<void> _printProductBarcodeLabel({
    required String productName,
    required String barcode,
  }) async {
    try {
      await _barcodeLabelPrinter.printLabel(
        productName: productName,
        barcodeValue: barcode,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Barcode label sent to printer'.tr())),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'Failed to print barcode'.tr()}: $e')),
      );
    }
  }

  Future<void> _deleteSelectedProducts(BuildContext context) async {
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
              child: Text('Delete'.tr()),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    final result = await _productsCubit.deleteMany(
      _selectedProductIds.toList(growable: false),
    );

    if (!context.mounted) return;

    setState(() {
      for (final id in result.failed.keys) {
        _selectedProductIds.remove(id);
      }
      if (result.deletedCount > 0) {
        _selectedProductIds.clear();
      }
      _selectionMode = false;
    });

    if (result.failedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'Deleted'.tr()}: ${result.deletedCount}')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${'Deleted'.tr()}: ${result.deletedCount} • ${'Failed'.tr()}: ${result.failedCount}',
        ),
      ),
    );
  }
}
