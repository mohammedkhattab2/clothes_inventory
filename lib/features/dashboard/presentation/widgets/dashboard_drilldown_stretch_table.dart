import 'package:flutter/material.dart';

/// Full-width responsive table: [Row]s with [Expanded] by [flex] weights.
/// Narrow viewports use horizontal scroll with a minimum table width.
class DashboardDrilldownStretchTable extends StatelessWidget {
  DashboardDrilldownStretchTable({
    required this.columns,
    required this.rowCount,
    required this.cellBuilder,
    this.onRowTap,
    this.horizontalScrollThreshold = 720,
    this.minWidthWhenScrolling = 920,
    super.key,
  }) : assert(columns.isNotEmpty);

  final List<StretchDrilldownColumn> columns;
  final int rowCount;
  final Widget Function(BuildContext context, int rowIndex, int colIndex)
      cellBuilder;
  final ValueChanged<int>? onRowTap;

  /// When max width is below this, wrap the table in horizontal scroll.
  final double horizontalScrollThreshold;

  /// Minimum width of the table body when horizontal scroll is enabled.
  final double minWidthWhenScrolling;

  static const double _rowPaddingV = 10;
  static const double _rowPaddingH = 10;
  static const double _headerPaddingV = 12;
  static const double _headerPaddingH = 10;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final headingStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
        );

    Widget headerChip(StretchDrilldownColumn col) {
      return Expanded(
        flex: col.flex,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _headerPaddingH,
          ),
          child: Text(
            col.label,
            style: headingStyle,
            textAlign: col.headerAlign ?? col.align,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    Widget buildHeader() {
      return Container(
        width: double.infinity,
        color: colorScheme.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(vertical: _headerPaddingV),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: columns.map(headerChip).toList(),
        ),
      );
    }

    Widget buildRow(int rowIndex) {
      final rowColor =
          rowIndex.isOdd ? colorScheme.surfaceContainerLow : null;

      Widget rowInner = Padding(
        padding: const EdgeInsets.symmetric(vertical: _rowPaddingV),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var ci = 0; ci < columns.length; ci++)
              Expanded(
                flex: columns[ci].flex,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _rowPaddingH,
                    vertical: 2,
                  ),
                  child: DefaultTextStyle.merge(
                    style: Theme.of(context).textTheme.bodyMedium,
                    child: Align(
                      alignment: _alignmentForText(columns[ci].align),
                      widthFactor: 1,
                      child:
                          cellBuilder(context, rowIndex, ci),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

      if (onRowTap != null) {
        rowInner = InkWell(
          onTap: () => onRowTap!(rowIndex),
          hoverColor:
              colorScheme.primary.withValues(alpha: 0.06),
          child: Material(
            type: MaterialType.transparency,
            child: rowInner,
          ),
        );
      }

      final decorated = DecoratedBox(
        decoration: BoxDecoration(
          color: rowColor,
          border: Border(
            bottom: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        child: rowInner,
      );

      return decorated;
    }

    Widget table(double widthConstraint) {
      final useHorizontal =
          widthConstraint > 0 && widthConstraint < horizontalScrollThreshold;
      final tableWidth =
          useHorizontal ? minWidthWhenScrolling : widthConstraint;

      return SizedBox(
        width: tableWidth.isFinite && tableWidth > 0 ? tableWidth : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            buildHeader(),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rowCount,
              itemBuilder: (ctx, rowIndex) => buildRow(rowIndex),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final body = table(w);

        if (w > 0 && w < horizontalScrollThreshold) {
          return Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              primary: false,
              child: body,
            ),
          );
        }

        return body;
      },
    );
  }

  static AlignmentGeometry _alignmentForText(TextAlign a) {
    switch (a) {
      case TextAlign.end:
      case TextAlign.right:
        return AlignmentDirectional.centerEnd;
      case TextAlign.center:
        return Alignment.center;
      case TextAlign.start:
      case TextAlign.left:
      case TextAlign.justify:
        return AlignmentDirectional.centerStart;
    }
  }
}

class StretchDrilldownColumn {
  const StretchDrilldownColumn({
    required this.label,
    required this.flex,
    this.align = TextAlign.start,
    this.headerAlign,
  });

  final String label;
  final int flex;

  /// Cell content alignment (also used for header if [headerAlign] is null).
  final TextAlign align;

  /// Optional distinct header alignment.
  final TextAlign? headerAlign;
}
