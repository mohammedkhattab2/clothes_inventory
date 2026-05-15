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
                0: FlexColumnWidth(2.0),
                1: FlexColumnWidth(0.6),
                2: FlexColumnWidth(0.95),
                3: FlexColumnWidth(0.75),
                4: FlexColumnWidth(0.95),
                5: FlexColumnWidth(0.95),
                6: FlexColumnWidth(1.5),
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
                    headerCell('Available'.tr(), align: TextAlign.end),
                    headerCell('Unit Price'.tr(), align: TextAlign.end),
                    headerCell('Line Total'.tr(), align: TextAlign.end),
                    headerCell('Actions'.tr()),
                  ],
                ),
                ...cart.map((item) {
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
                                  style: isOverStockDraft
                                      ? TextStyle(
                                          color: colorScheme.error,
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

                                    if (parsed >
                                        item.availableStock + 0.000001) {
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
                        child: Builder(
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
                              textAlign: TextAlign.end,
                              style:
                                  (draftOverStock ||
                                      (item.quantity >
                                          item.availableStock + 0.000001))
                                  ? TextStyle(
                                      color: colorScheme.error,
                                      fontWeight: FontWeight.w700,
                                    )
                                  : null,
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
