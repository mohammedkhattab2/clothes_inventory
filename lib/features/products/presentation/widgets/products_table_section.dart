import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:delta_erp/core/widgets/app_data_table.dart';
import 'package:delta_erp/core/widgets/app_empty_state.dart';
import 'package:delta_erp/features/products/domain/product.dart';

class ProductsTableSection extends StatefulWidget {
  const ProductsTableSection({
    super.key,
    required this.visibleItems,
    required this.canManageProducts,
    required this.isAllStockFilter,
    required this.sortKeyIndex,
    required this.sortAscending,
    required this.leftSortKeyIndex,
    required this.leftSortAscending,
    required this.rightSortKeyIndex,
    required this.rightSortAscending,
    required this.leftColumnSearchController,
    required this.rightColumnSearchController,
    required this.leftColumnQuery,
    required this.rightColumnQuery,
    required this.onLeftColumnQueryChanged,
    required this.onRightColumnQueryChanged,
    required this.onMainSortRequested,
    required this.onLeftSortChanged,
    required this.onRightSortChanged,
    required this.onEditProduct,
    required this.onDeleteProduct,
    required this.selectionMode,
    required this.selectedProductIds,
    required this.onSelectionChanged,
    required this.onSelectAllChanged,
  });

  static const int lazyChunkSize = 150;

  final List<Product> visibleItems;
  final bool canManageProducts;
  final bool isAllStockFilter;
  final int sortKeyIndex;
  final bool sortAscending;
  final int leftSortKeyIndex;
  final bool leftSortAscending;
  final int rightSortKeyIndex;
  final bool rightSortAscending;
  final TextEditingController leftColumnSearchController;
  final TextEditingController rightColumnSearchController;
  final String leftColumnQuery;
  final String rightColumnQuery;
  final ValueChanged<String> onLeftColumnQueryChanged;
  final ValueChanged<String> onRightColumnQueryChanged;
  final ValueChanged<int> onMainSortRequested;
  final ValueChanged<int> onLeftSortChanged;
  final ValueChanged<int> onRightSortChanged;
  final ValueChanged<Product> onEditProduct;
  final ValueChanged<Product> onDeleteProduct;
  final bool selectionMode;
  final Set<int> selectedProductIds;
  final void Function(int productId, bool selected) onSelectionChanged;
  final void Function(List<int> productIds, bool selected) onSelectAllChanged;

  @override
  State<ProductsTableSection> createState() => _ProductsTableSectionState();
}

class _ProductsTableSectionState extends State<ProductsTableSection> {
  final ScrollController _mainScrollController = ScrollController();
  final ScrollController _leftScrollController = ScrollController();
  final ScrollController _rightScrollController = ScrollController();

  int _mainVisibleCount = ProductsTableSection.lazyChunkSize;
  int _leftVisibleCount = ProductsTableSection.lazyChunkSize;
  int _rightVisibleCount = ProductsTableSection.lazyChunkSize;

  int _mainTotalCount = 0;
  int _leftTotalCount = 0;
  int _rightTotalCount = 0;

  @override
  void initState() {
    super.initState();
    _mainScrollController.addListener(_onMainScroll);
    _leftScrollController.addListener(_onLeftScroll);
    _rightScrollController.addListener(_onRightScroll);
  }

  @override
  void didUpdateWidget(covariant ProductsTableSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final filtersChanged =
        oldWidget.leftColumnQuery != widget.leftColumnQuery ||
        oldWidget.rightColumnQuery != widget.rightColumnQuery ||
        oldWidget.sortKeyIndex != widget.sortKeyIndex ||
        oldWidget.sortAscending != widget.sortAscending ||
        oldWidget.leftSortKeyIndex != widget.leftSortKeyIndex ||
        oldWidget.leftSortAscending != widget.leftSortAscending ||
        oldWidget.rightSortKeyIndex != widget.rightSortKeyIndex ||
        oldWidget.rightSortAscending != widget.rightSortAscending ||
        oldWidget.visibleItems.length != widget.visibleItems.length;

    if (filtersChanged) {
      _resetVisibleCounts();
    }
  }

  @override
  void dispose() {
    _mainScrollController
      ..removeListener(_onMainScroll)
      ..dispose();
    _leftScrollController
      ..removeListener(_onLeftScroll)
      ..dispose();
    _rightScrollController
      ..removeListener(_onRightScroll)
      ..dispose();
    super.dispose();
  }

  void _resetVisibleCounts() {
    if (!mounted) return;
    setState(() {
      _mainVisibleCount = ProductsTableSection.lazyChunkSize;
      _leftVisibleCount = ProductsTableSection.lazyChunkSize;
      _rightVisibleCount = ProductsTableSection.lazyChunkSize;
    });
  }

  void _onMainScroll() {
    _maybeLoadMore(
      _mainScrollController,
      currentCount: _mainVisibleCount,
      totalCount: _mainTotalCount,
      onLoadMore: () {
        setState(() {
          _mainVisibleCount = math.min(
            _mainVisibleCount + ProductsTableSection.lazyChunkSize,
            _mainTotalCount,
          );
        });
      },
    );
  }

  void _onLeftScroll() {
    _maybeLoadMore(
      _leftScrollController,
      currentCount: _leftVisibleCount,
      totalCount: _leftTotalCount,
      onLoadMore: () {
        setState(() {
          _leftVisibleCount = math.min(
            _leftVisibleCount + ProductsTableSection.lazyChunkSize,
            _leftTotalCount,
          );
        });
      },
    );
  }

  void _onRightScroll() {
    _maybeLoadMore(
      _rightScrollController,
      currentCount: _rightVisibleCount,
      totalCount: _rightTotalCount,
      onLoadMore: () {
        setState(() {
          _rightVisibleCount = math.min(
            _rightVisibleCount + ProductsTableSection.lazyChunkSize,
            _rightTotalCount,
          );
        });
      },
    );
  }

  void _maybeLoadMore(
    ScrollController controller, {
    required int currentCount,
    required int totalCount,
    required VoidCallback onLoadMore,
  }) {
    if (!controller.hasClients || currentCount >= totalCount) return;
    final position = controller.position;
    if (position.maxScrollExtent <= 0) return;

    if (position.pixels >= position.maxScrollExtent - 220) {
      onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isUltraDense = size.height < 760;
    final rowMinHeight = isUltraDense ? 36.0 : 42.0;
    final headingHeight = isUltraDense ? 40.0 : 46.0;
    final splitGap = isUltraDense ? 8.0 : 10.0;

    final sortedItems = _sortProducts(
      widget.visibleItems,
      widget.sortKeyIndex,
      widget.sortAscending,
    );

    if (widget.visibleItems.isEmpty) {
      return Card(
        child: AppEmptyState(
          icon: widget.isAllStockFilter
              ? Icons.inventory_2_outlined
              : Icons.search_off_outlined,
          title: widget.isAllStockFilter
              ? 'No products found.'.tr()
              : 'No products match selected stock filter.'.tr(),
        ),
      );
    }

    final canSplitColumns = size.width >= 1180 && sortedItems.length > 1;
    if (!canSplitColumns) {
      _mainTotalCount = sortedItems.length;
      final displayedCount = math.min(_mainVisibleCount, _mainTotalCount);
      final displayedItems = sortedItems.take(displayedCount).toList();

      return NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis == Axis.vertical &&
              notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 220) {
            _onMainScroll();
          }
          return false;
        },
        child: _buildProductsDataTable(
          context,
          displayedItems,
          allSelectableProducts: sortedItems,
          isUltraDense: isUltraDense,
          rowMinHeight: rowMinHeight,
          headingHeight: headingHeight,
          sortKeyIndex: widget.sortKeyIndex,
          sortAscending: widget.sortAscending,
          onSortRequested: widget.onMainSortRequested,
          enableVerticalScroll: true,
          verticalScrollController: _mainScrollController,
        ),
      );
    }

    final leftRawItems = <Product>[];
    final rightRawItems = <Product>[];
    for (var i = 0; i < sortedItems.length; i++) {
      if (i.isEven) {
        leftRawItems.add(sortedItems[i]);
      } else {
        rightRawItems.add(sortedItems[i]);
      }
    }

    final leftItems = _sortProducts(
      _filterColumnItems(leftRawItems, widget.leftColumnQuery),
      widget.leftSortKeyIndex,
      widget.leftSortAscending,
    );
    final rightItems = _sortProducts(
      _filterColumnItems(rightRawItems, widget.rightColumnQuery),
      widget.rightSortKeyIndex,
      widget.rightSortAscending,
    );

    _leftTotalCount = leftItems.length;
    _rightTotalCount = rightItems.length;

    final leftDisplayedItems = leftItems
        .take(math.min(_leftVisibleCount, _leftTotalCount))
        .toList(growable: false);
    final rightDisplayedItems = rightItems
        .take(math.min(_rightVisibleCount, _rightTotalCount))
        .toList(growable: false);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildSplitColumnPane(
            context,
            allColumnItems: leftRawItems,
            allSelectableColumnItems: leftItems,
            visibleColumnItems: leftDisplayedItems,
            searchController: widget.leftColumnSearchController,
            query: widget.leftColumnQuery,
            sortKeyIndex: widget.leftSortKeyIndex,
            sortAscending: widget.leftSortAscending,
            isUltraDense: isUltraDense,
            rowMinHeight: rowMinHeight,
            headingHeight: headingHeight,
            onQueryChanged: widget.onLeftColumnQueryChanged,
            onSortChanged: widget.onLeftSortChanged,
            scrollController: _leftScrollController,
          ),
        ),
        SizedBox(width: splitGap),
        Expanded(
          child: _buildSplitColumnPane(
            context,
            allColumnItems: rightRawItems,
            allSelectableColumnItems: rightItems,
            visibleColumnItems: rightDisplayedItems,
            searchController: widget.rightColumnSearchController,
            query: widget.rightColumnQuery,
            sortKeyIndex: widget.rightSortKeyIndex,
            sortAscending: widget.rightSortAscending,
            isUltraDense: isUltraDense,
            rowMinHeight: rowMinHeight,
            headingHeight: headingHeight,
            onQueryChanged: widget.onRightColumnQueryChanged,
            onSortChanged: widget.onRightSortChanged,
            scrollController: _rightScrollController,
          ),
        ),
      ],
    );
  }

  Widget _buildSplitColumnPane(
    BuildContext context, {
    required List<Product> allColumnItems,
    required List<Product> allSelectableColumnItems,
    required List<Product> visibleColumnItems,
    required TextEditingController searchController,
    required String query,
    required int sortKeyIndex,
    required bool sortAscending,
    required bool isUltraDense,
    required double rowMinHeight,
    required double headingHeight,
    required ValueChanged<String> onQueryChanged,
    required ValueChanged<int> onSortChanged,
    required ScrollController scrollController,
  }) {
    final lowCount = allColumnItems.where(_isLowStock).length;
    final outCount = allColumnItems.where(_isOutOfStock).length;

    Widget emptyState({required bool noProducts}) {
      return AppEmptyState(
        icon: noProducts
            ? Icons.view_column_outlined
            : Icons.search_off_outlined,
        title: noProducts
            ? 'No products found.'.tr()
            : 'No products match selected stock filter.'.tr(),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _ProductsColumnHeaderDelegate(
              height: 124,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '${'Products'.tr()} (${allColumnItems.length})',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              _summaryChip(
                                context,
                                label: 'Low Stock'.tr(),
                                value: lowCount.toString(),
                                compact: true,
                              ),
                              _summaryChip(
                                context,
                                label: 'Out of Stock'.tr(),
                                value: outCount.toString(),
                                compact: true,
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<int>(
                          tooltip: 'Toggle sort direction'.tr(),
                          initialValue: sortKeyIndex,
                          onSelected: onSortChanged,
                          itemBuilder: (menuContext) => [
                            PopupMenuItem<int>(
                              value: 0,
                              child: Text('Name'.tr()),
                            ),
                            PopupMenuItem<int>(
                              value: 1,
                              child: Text('Current Stock'.tr()),
                            ),
                            PopupMenuItem<int>(
                              value: 2,
                              child: Text('Sale Price'.tr()),
                            ),
                          ],
                          child: Icon(
                            sortAscending
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: searchController,
                      onChanged: onQueryChanged,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Search by name'.tr(),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: query.trim().isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  searchController.clear();
                                  onQueryChanged('');
                                },
                                icon: const Icon(Icons.close),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (allColumnItems.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: emptyState(noProducts: true),
            )
          else if (allSelectableColumnItems.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: emptyState(noProducts: false),
            )
          else
            SliverToBoxAdapter(
              child: _buildProductsDataTable(
                context,
                visibleColumnItems,
                allSelectableProducts: allSelectableColumnItems,
                isUltraDense: isUltraDense,
                rowMinHeight: rowMinHeight,
                headingHeight: headingHeight,
                sortKeyIndex: sortKeyIndex,
                sortAscending: sortAscending,
                onSortRequested: onSortChanged,
                enableVerticalScroll: false,
              ),
            ),
          if (visibleColumnItems.length < allSelectableColumnItems.length)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductsDataTable(
    BuildContext context,
    List<Product> products, {
    List<Product>? allSelectableProducts,
    required bool isUltraDense,
    required double rowMinHeight,
    required double headingHeight,
    required int sortKeyIndex,
    required bool sortAscending,
    required ValueChanged<int> onSortRequested,
    required bool enableVerticalScroll,
    ScrollController? verticalScrollController,
  }) {
    if (products.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectableSource = allSelectableProducts ?? products;
    final selectableIds = selectableSource
        .map((p) => p.id)
        .whereType<int>()
        .toList(growable: false);
    final selectedCountInTable = selectableIds
        .where((id) => widget.selectedProductIds.contains(id))
        .length;
    final allSelectedInTable =
        selectableIds.isNotEmpty &&
        selectedCountInTable == selectableIds.length;
    final someSelectedInTable = selectedCountInTable > 0 && !allSelectedInTable;

    return AppDataTable(
      useCard: false,
      sortColumnIndex: _sortColumnIndexFor(sortKeyIndex),
      sortAscending: sortAscending,
      dataRowMinHeight: rowMinHeight,
      dataRowMaxHeight: rowMinHeight,
      headingRowHeight: headingHeight,
      horizontalMargin: isUltraDense ? 10 : 12,
      columnSpacing: isUltraDense ? 14 : 18,
      enableVerticalScroll: enableVerticalScroll,
      verticalScrollController: verticalScrollController,
      columns: [
        if (widget.selectionMode)
          DataColumn(
            label: Center(
              child: Checkbox(
                value: allSelectedInTable
                    ? true
                    : (someSelectedInTable ? null : false),
                tristate: true,
                onChanged: selectableIds.isEmpty
                    ? null
                    : (value) {
                        final shouldSelect = value != false;
                        widget.onSelectAllChanged(selectableIds, shouldSelect);
                      },
              ),
            ),
          ),
        DataColumn(
          label: Center(child: Text('Name'.tr())),
          onSort: (columnIndex, ascending) => onSortRequested(0),
        ),
        DataColumn(label: Center(child: Text('Barcode'.tr()))),
        DataColumn(label: Center(child: Text('Unit'.tr()))),
        DataColumn(
          label: Center(child: Text('Current Stock'.tr())),
          numeric: true,
          onSort: (columnIndex, ascending) => onSortRequested(1),
        ),
        DataColumn(
          label: Center(child: Text('Sale Price'.tr())),
          numeric: true,
          onSort: (columnIndex, ascending) => onSortRequested(2),
        ),
        DataColumn(label: Center(child: Text('Actions'.tr()))),
      ],
      rows: products.asMap().entries.map((entry) {
        final index = entry.key;
        final product = entry.value;
        final isLowStock = _isLowStock(product);
        final isOutOfStock = _isOutOfStock(product);

        return DataRow(
          color: WidgetStateProperty.resolveWith((states) {
            final scheme = Theme.of(context).colorScheme;
            if (states.contains(WidgetState.hovered)) {
              return scheme.primary.withValues(alpha: 0.08);
            }
            return index.isEven
                ? scheme.surfaceContainerLowest.withValues(alpha: 0.35)
                : null;
          }),
          cells: [
            if (widget.selectionMode)
              DataCell(
                Center(
                  child: Checkbox(
                    value:
                        product.id != null &&
                        widget.selectedProductIds.contains(product.id),
                    onChanged: product.id == null
                        ? null
                        : (value) {
                            widget.onSelectionChanged(
                              product.id!,
                              value ?? false,
                            );
                          },
                  ),
                ),
              ),
            DataCell(
              Center(
                child: Text(
                  product.name,
                  textAlign: TextAlign.center,
                  style: (isLowStock || isOutOfStock)
                      ? TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        )
                      : null,
                ),
              ),
            ),
            DataCell(
              Center(
                child: Text(
                  product.barcode ?? '-',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            DataCell(
              Center(
                child: Text(product.unitType.name, textAlign: TextAlign.center),
              ),
            ),
            DataCell(
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: isUltraDense ? 4 : 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _formatStock(product),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isOutOfStock)
                      _stockStatusBadge(
                        context,
                        'Out of Stock'.tr(),
                        isUltraDense: isUltraDense,
                        out: true,
                      )
                    else if (isLowStock)
                      _stockStatusBadge(
                        context,
                        'Low Stock'.tr(),
                        isUltraDense: isUltraDense,
                        out: false,
                      ),
                  ],
                ),
              ),
            ),
            DataCell(
              Center(
                child: Text(
                  product.salePrice.toStringAsFixed(2),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            DataCell(
              Center(
                child: widget.canManageProducts
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(
                              minWidth: 30,
                              minHeight: 30,
                            ),
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => widget.onEditProduct(product),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(
                              minWidth: 30,
                              minHeight: 30,
                            ),
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => widget.onDeleteProduct(product),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  bool _isLowStock(Product product) {
    return product.lowStockThreshold > 0 &&
        product.currentStock <= product.lowStockThreshold;
  }

  bool _isOutOfStock(Product product) {
    return product.currentStock <= 0;
  }

  int _stockPriority(Product product) {
    if (_isOutOfStock(product)) return 0;
    if (_isLowStock(product)) return 1;
    return 2;
  }

  List<Product> _sortProducts(
    List<Product> input,
    int sortKeyIndex,
    bool ascending,
  ) {
    final items = [...input];
    items.sort((a, b) {
      int cmp;
      switch (sortKeyIndex) {
        case 0:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case 1:
          cmp = a.currentStock.compareTo(b.currentStock);
          break;
        case 2:
          cmp = a.salePrice.compareTo(b.salePrice);
          break;
        default:
          cmp = a.currentStock.compareTo(b.currentStock);
          break;
      }

      if (cmp == 0) {
        cmp = _stockPriority(a).compareTo(_stockPriority(b));
      }

      return ascending ? cmp : -cmp;
    });
    return items;
  }

  List<Product> _filterColumnItems(List<Product> input, String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return input;
    return input.where((product) {
      final barcode = (product.barcode ?? '').toLowerCase();
      return product.name.toLowerCase().contains(normalized) ||
          barcode.contains(normalized) ||
          product.unitType.name.toLowerCase().contains(normalized);
    }).toList();
  }

  int _sortColumnIndexFor(int sortKeyIndex) {
    final offset = widget.selectionMode ? 1 : 0;
    switch (sortKeyIndex) {
      case 0:
        return 0 + offset;
      case 1:
        return 3 + offset;
      case 2:
        return 4 + offset;
      default:
        return 3 + offset;
    }
  }

  String _formatStock(Product product) {
    if (product.unitType == UnitType.piece) {
      final rounded = product.currentStock.roundToDouble();
      if ((product.currentStock - rounded).abs() < 0.000001) {
        return product.currentStock.toStringAsFixed(0);
      }
    }
    return product.currentStock.toStringAsFixed(0);
  }

  Widget _stockStatusBadge(
    BuildContext context,
    String label, {
    required bool isUltraDense,
    required bool out,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = out
        ? colorScheme.errorContainer
        : colorScheme.tertiaryContainer.withValues(alpha: 0.6);
    final border = out
        ? colorScheme.error.withValues(alpha: 0.35)
        : colorScheme.tertiary.withValues(alpha: 0.45);
    final fg = out
        ? colorScheme.onErrorContainer
        : colorScheme.onTertiaryContainer;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isUltraDense ? 5 : 6,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: isUltraDense ? 10 : 11,
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _summaryChip(
    BuildContext context, {
    required String label,
    required String value,
    Color? color,
    Color? valueColor,
    bool compact = false,
  }) {
    final bg = color ?? Theme.of(context).colorScheme.surfaceContainerHigh;
    final fg = valueColor ?? Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(compact ? 10 : 999),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _ProductsColumnHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _ProductsColumnHeaderDelegate({
    required this.child,
    required this.height,
  });

  final Widget child;
  final double height;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _ProductsColumnHeaderDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}
