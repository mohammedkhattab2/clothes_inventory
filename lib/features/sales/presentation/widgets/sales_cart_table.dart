import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:clothes_inventory/core/widgets/app_empty_state.dart';
import 'package:clothes_inventory/features/sales/domain/sale_models.dart';

class SalesCartTable extends StatelessWidget {
  const SalesCartTable({
    super.key,
    required this.cart,
    required this.pieceUnitTypeName,
    required this.inlineQuantityDrafts,
    required this.qtyControllerFor,
    required this.qtyFocusNodeFor,
    required this.formatQuantity,
    required this.parseFlexibleNumber,
    required this.onDraftChanged,
    required this.onApplyInlineQuantity,
    required this.onDraftCleared,
    required this.onRemoveItem,
    required this.onUpdateItemQuantity,
    required this.onEditItem,
  });

  final List<SaleDraftItem> cart;
  final String pieceUnitTypeName;
  final Map<int, String> inlineQuantityDrafts;
  final TextEditingController Function(SaleDraftItem item) qtyControllerFor;
  final FocusNode Function(SaleDraftItem item, TextEditingController controller)
  qtyFocusNodeFor;
  final String Function(SaleDraftItem item) formatQuantity;
  final double? Function(String raw) parseFlexibleNumber;
  final void Function(SaleDraftItem item, String value) onDraftChanged;
  final void Function(SaleDraftItem item, String value) onApplyInlineQuantity;
  final void Function(int productId) onDraftCleared;
  final void Function(int productId) onRemoveItem;
  final void Function(int productId, double quantity) onUpdateItemQuantity;
  final void Function(SaleDraftItem item) onEditItem;

  @override
  Widget build(BuildContext context) {
    if (cart.isEmpty) {
      return AppEmptyState(
        icon: Icons.add_shopping_cart_outlined,
        title: 'Add at least one product.'.tr(),
        compact: true,
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.sizeOf(context).width < 1200 ? 760 : 820,
        ),
        child: SingleChildScrollView(
          child: DataTable(
            headingRowHeight: MediaQuery.sizeOf(context).height < 760 ? 40 : 46,
            dataRowMinHeight: MediaQuery.sizeOf(context).height < 760 ? 40 : 46,
            dataRowMaxHeight: MediaQuery.sizeOf(context).height < 760 ? 40 : 46,
            horizontalMargin: 10,
            columnSpacing: MediaQuery.sizeOf(context).height < 760 ? 16 : 20,
            columns: [
              DataColumn(label: Text('Product'.tr())),
              DataColumn(label: Text('Unit'.tr())),
              DataColumn(numeric: true, label: Text('Quantity'.tr())),
              DataColumn(numeric: true, label: Text('Available'.tr())),
              DataColumn(numeric: true, label: Text('Unit Price'.tr())),
              DataColumn(numeric: true, label: Text('Line Total'.tr())),
              DataColumn(label: Text('Actions'.tr())),
            ],
            rows: cart
                .map(
                  (item) => DataRow(
                    cells: [
                      DataCell(Text(item.productName)),
                      DataCell(Text(item.unitType)),
                      DataCell(
                        Builder(
                          builder: (context) {
                            final controller = qtyControllerFor(item);
                            final focusNode = qtyFocusNodeFor(item, controller);
                            final formatted = formatQuantity(item);
                            final draftRaw =
                                inlineQuantityDrafts[item.productId];
                            final draftParsed =
                                draftRaw == null || draftRaw.trim().isEmpty
                                ? null
                                : parseFlexibleNumber(draftRaw);
                            final isOverStockDraft =
                                draftParsed != null &&
                                draftParsed > item.availableStock + 0.000001;

                            if (!focusNode.hasFocus &&
                                controller.text != formatted) {
                              controller.value = controller.value.copyWith(
                                text: formatted,
                                selection: TextSelection.collapsed(
                                  offset: formatted.length,
                                ),
                              );
                            }

                            return SizedBox(
                              width: 90,
                              child: TextField(
                                controller: controller,
                                focusNode: focusNode,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9٠-٩.,٫٬]'),
                                  ),
                                ],
                                textInputAction: TextInputAction.done,
                                style: isOverStockDraft
                                    ? TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                        fontWeight: FontWeight.w700,
                                      )
                                    : null,
                                onChanged: (value) {
                                  onDraftChanged(item, value);
                                  final parsed = parseFlexibleNumber(value);
                                  if (parsed == null) return;

                                  if (parsed <= 0) {
                                    onRemoveItem(item.productId);
                                    onDraftCleared(item.productId);
                                    return;
                                  }

                                  if (item.unitType == pieceUnitTypeName &&
                                      parsed != parsed.roundToDouble()) {
                                    return;
                                  }

                                  if (parsed > item.availableStock + 0.000001) {
                                    return;
                                  }

                                  onUpdateItemQuantity(item.productId, parsed);
                                },
                                onSubmitted: (value) {
                                  onApplyInlineQuantity(item, value);
                                  onDraftCleared(item.productId);
                                },
                                onTapOutside: (_) {
                                  final draft =
                                      inlineQuantityDrafts[item.productId];
                                  if (draft == null || draft.trim().isEmpty) {
                                    return;
                                  }
                                  onApplyInlineQuantity(item, draft);
                                  onDraftCleared(item.productId);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      DataCell(
                        Builder(
                          builder: (context) {
                            final rawDraft =
                                inlineQuantityDrafts[item.productId];
                            final parsedDraft =
                                rawDraft == null || rawDraft.trim().isEmpty
                                ? null
                                : parseFlexibleNumber(rawDraft);
                            final draftOverStock =
                                parsedDraft != null &&
                                parsedDraft > item.availableStock + 0.000001;

                            return Text(
                              item.availableStock.toStringAsFixed(0),
                              style:
                                  (draftOverStock ||
                                      (item.quantity >
                                          item.availableStock + 0.000001))
                                  ? TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                      fontWeight: FontWeight.w700,
                                    )
                                  : null,
                            );
                          },
                        ),
                      ),
                      DataCell(Text(item.unitPrice.toStringAsFixed(2))),
                      DataCell(Text(item.lineTotal.toStringAsFixed(2))),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(
                                minWidth: 30,
                                minHeight: 30,
                              ),
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () {
                                final step = item.unitType == pieceUnitTypeName
                                    ? 1.0
                                    : 0.25;
                                final nextQuantity = item.quantity - step;
                                if (nextQuantity <= 0) {
                                  onRemoveItem(item.productId);
                                  return;
                                }
                                onUpdateItemQuantity(
                                  item.productId,
                                  nextQuantity,
                                );
                              },
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(
                                minWidth: 30,
                                minHeight: 30,
                              ),
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed:
                                  item.quantity >=
                                      item.availableStock - 0.000001
                                  ? null
                                  : () {
                                      final step =
                                          item.unitType == pieceUnitTypeName
                                          ? 1.0
                                          : 0.25;
                                      final nextQuantity = item.quantity + step;
                                      if (nextQuantity >
                                          item.availableStock + 0.000001) {
                                        return;
                                      }
                                      onUpdateItemQuantity(
                                        item.productId,
                                        nextQuantity,
                                      );
                                    },
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(
                                minWidth: 30,
                                minHeight: 30,
                              ),
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => onEditItem(item),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(
                                minWidth: 30,
                                minHeight: 30,
                              ),
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => onRemoveItem(item.productId),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}
