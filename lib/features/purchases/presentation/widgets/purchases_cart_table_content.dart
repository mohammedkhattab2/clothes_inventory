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

    final colorScheme = Theme.of(context).colorScheme;
    final dense = MediaQuery.sizeOf(context).height < 760;
    final borderSide = BorderSide(
      color: colorScheme.outlineVariant.withValues(alpha: 0.65),
    );
    final tableBorder = TableBorder(
      top: borderSide,
      bottom: borderSide,
      horizontalInside: borderSide,
    );

    TextStyle? headerStyle(BuildContext c) =>
        Theme.of(c).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        );

    Widget headerCell(String text, {TextAlign align = TextAlign.start}) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: dense ? 8 : 10),
        child: Text(text, textAlign: align, style: headerStyle(context)),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.hasBoundedWidth &&
                constraints.maxWidth.isFinite &&
                constraints.maxWidth > 0
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: tableWidth),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(2.2),
                1: FlexColumnWidth(0.65),
                2: FlexColumnWidth(1.05),
                3: FlexColumnWidth(1.0),
                4: FlexColumnWidth(1.0),
                5: FlexColumnWidth(1.5),
              },
              border: tableBorder,
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.35,
                    ),
                  ),
                  children: [
                    headerCell('Product'.tr()),
                    headerCell('Unit'.tr()),
                    headerCell('Quantity'.tr(), align: TextAlign.end),
                    headerCell('Unit Price'.tr(), align: TextAlign.end),
                    headerCell('Line Total'.tr(), align: TextAlign.end),
                    headerCell('Actions'.tr()),
                  ],
                ),
                ...state.cart.map((item) {
                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          item.productName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(item.unitType),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Builder(
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

                            return Align(
                              alignment: Alignment.centerRight,
                              child: SizedBox(
                                width: double.infinity,
                                child: TextField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  textAlign: TextAlign.end,
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
                                      inlineQuantityDrafts.remove(
                                        item.productId,
                                      );
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
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          item.unitPrice.toStringAsFixed(2),
                          textAlign: TextAlign.end,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          item.lineTotal.toStringAsFixed(2),
                          textAlign: TextAlign.end,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 0,
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
                              onPressed: () =>
                                  cubit.removeItem(item.productId),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
