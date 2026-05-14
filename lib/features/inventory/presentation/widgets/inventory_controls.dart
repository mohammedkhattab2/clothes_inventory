import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

enum InventoryFilterOption { all, low, out }

class InventoryControls extends StatelessWidget {
  const InventoryControls({
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.filter,
    required this.onFilterChanged,
    required this.sortStockDesc,
    required this.onToggleSort,
    required this.isUltraDense,
    super.key,
  });

  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final InventoryFilterOption filter;
  final ValueChanged<InventoryFilterOption> onFilterChanged;
  final bool sortStockDesc;
  final VoidCallback onToggleSort;
  final bool isUltraDense;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        TextField(
          controller: searchController,
          decoration: InputDecoration(
            labelText: 'Search by name'.tr(),
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: isUltraDense ? 8 : 10,
            ),
            filled: true,
            fillColor: colorScheme.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            suffixIcon: searchQuery.isEmpty
                ? null
                : IconButton(
                    onPressed: onClearSearch,
                    icon: const Icon(Icons.close),
                  ),
          ),
          onChanged: onSearchChanged,
        ),
        SizedBox(height: isUltraDense ? 4 : 6),
        Wrap(
          spacing: 6,
          runSpacing: isUltraDense ? 4 : 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterChip(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              labelStyle: Theme.of(context).textTheme.labelSmall,
              label: Text('All'.tr()),
              selected: filter == InventoryFilterOption.all,
              onSelected: (_) => onFilterChanged(InventoryFilterOption.all),
            ),
            FilterChip(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              labelStyle: Theme.of(context).textTheme.labelSmall,
              label: Text('Low Stock Only'.tr()),
              selected: filter == InventoryFilterOption.low,
              onSelected: (_) => onFilterChanged(InventoryFilterOption.low),
            ),
            FilterChip(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              labelStyle: Theme.of(context).textTheme.labelSmall,
              label: Text('Out of Stock Only'.tr()),
              selected: filter == InventoryFilterOption.out,
              onSelected: (_) => onFilterChanged(InventoryFilterOption.out),
            ),
            FilledButton.tonalIcon(
              onPressed: onToggleSort,
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              icon: Icon(
                sortStockDesc ? Icons.south_rounded : Icons.north_rounded,
              ),
              label: Text('Current Stock'.tr()),
            ),
          ],
        ),
      ],
    );
  }
}
