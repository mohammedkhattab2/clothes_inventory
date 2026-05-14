import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:clothes_inventory/core/widgets/app_empty_state.dart';
import 'package:clothes_inventory/features/products/domain/product.dart';
import 'package:clothes_inventory/features/purchases/domain/purchase_models.dart';
import 'package:clothes_inventory/features/purchases/presentation/purchases_cubit.dart';

class PurchasesCartTableContent extends StatelessWidget {
  const PurchasesCartTableContent({
    required this.state,
    required this.cubit,
    required this.qtyControllerFor,
    required this.qtyFocusNodeFor,
    required this.formatQuantity,
    required this.parseFlexibleNumber,
    required this.inlineQuantityDrafts,
    required this.applyInlineQuantityChange,
    required this.onShowEditItemDialog,
    super.key,
  });

  final PurchasesState state;
  final PurchasesCubit cubit;
  final TextEditingController Function(PurchaseDraftItem item) qtyControllerFor;
  final FocusNode Function(
    PurchaseDraftItem item,
    TextEditingController controller,
  )
  qtyFocusNodeFor;
  final String Function(PurchaseDraftItem item) formatQuantity;
  final double? Function(String raw) parseFlexibleNumber;
  final Map<int, String> inlineQuantityDrafts;
  final void Function(BuildContext context, PurchaseDraftItem item, String raw)
  applyInlineQuantityChange;
  final Future<void> Function(BuildContext context, PurchaseDraftItem item)
  onShowEditItemDialog;

  @override
  Widget build(BuildContext context) {
    if (state.cart.isEmpty) {
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
          minWidth: MediaQuery.sizeOf(context).width < 1200 ? 640 : 700,
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
              DataColumn(numeric: true, label: Text('Unit Price'.tr())),
              DataColumn(numeric: true, label: Text('Line Total'.tr())),
              DataColumn(label: Text('Actions'.tr())),
            ],
            rows: state.cart
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
                                onChanged: (value) {
                                  inlineQuantityDrafts[item.productId] = value;

                                  final parsed = parseFlexibleNumber(value);
                                  if (parsed == null) {
                                    return;
                                  }

                                  if (parsed <= 0) {
                                    cubit.removeItem(item.productId);
                                    inlineQuantityDrafts.remove(item.productId);
                                    return;
                                  }

                                  if (item.unitType == UnitType.piece.name &&
                                      parsed != parsed.roundToDouble()) {
                                    return;
                                  }

                                  cubit.updateItem(
                                    item.productId,
                                    quantity: parsed,
                                  );
                                },
                                onSubmitted: (value) {
                                  applyInlineQuantityChange(
                                    context,
                                    item,
                                    value,
                                  );
                                  inlineQuantityDrafts.remove(item.productId);
                                },
                                onTapOutside: (_) {
                                  final draft =
                                      inlineQuantityDrafts[item.productId];
                                  if (draft == null || draft.trim().isEmpty) {
                                    return;
                                  }
                                  applyInlineQuantityChange(
                                    context,
                                    item,
                                    draft,
                                  );
                                  inlineQuantityDrafts.remove(item.productId);
                                },
                              ),
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
                                final step =
                                    item.unitType == UnitType.piece.name
                                    ? 1.0
                                    : 0.25;
                                final nextQuantity = item.quantity - step;
                                if (nextQuantity <= 0) {
                                  cubit.removeItem(item.productId);
                                  return;
                                }
                                cubit.updateItem(
                                  item.productId,
                                  quantity: nextQuantity,
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
                              onPressed: () {
                                final step =
                                    item.unitType == UnitType.piece.name
                                    ? 1.0
                                    : 0.25;
                                cubit.updateItem(
                                  item.productId,
                                  quantity: item.quantity + step,
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
                              onPressed: () =>
                                  onShowEditItemDialog(context, item),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(
                                minWidth: 30,
                                minHeight: 30,
                              ),
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => cubit.removeItem(item.productId),
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
