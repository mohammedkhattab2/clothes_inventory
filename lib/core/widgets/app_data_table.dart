import 'package:flutter/material.dart';

class AppDataTable extends StatelessWidget {
  const AppDataTable({
    required this.columns,
    required this.rows,
    this.sortColumnIndex,
    this.sortAscending = true,
    this.useCard = true,
    this.dataRowMinHeight,
    this.dataRowMaxHeight,
    this.headingRowHeight,
    this.horizontalMargin,
    this.columnSpacing,
    this.enableVerticalScroll = true,
    this.verticalScrollController,
    super.key,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;
  final int? sortColumnIndex;
  final bool sortAscending;
  final bool useCard;
  final double? dataRowMinHeight;
  final double? dataRowMaxHeight;
  final double? headingRowHeight;
  final double? horizontalMargin;
  final double? columnSpacing;
  final bool enableVerticalScroll;
  final ScrollController? verticalScrollController;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final cardColor = colorScheme.surface;
    final headingRowColor = colorScheme.surfaceContainerHigh;
    final dataRowColor = colorScheme.surface;
    final borderColor = colorScheme.outlineVariant;

    final horizontalTable = LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              columns: columns,
              rows: rows,
              sortColumnIndex: sortColumnIndex,
              sortAscending: sortAscending,
              dataRowMinHeight: dataRowMinHeight,
              dataRowMaxHeight: dataRowMaxHeight,
              headingRowHeight: headingRowHeight,
              horizontalMargin: horizontalMargin,
              columnSpacing: columnSpacing,
              headingRowColor: WidgetStateColor.resolveWith(
                (states) => headingRowColor,
              ),
              dataRowColor: WidgetStateColor.resolveWith(
                (states) => dataRowColor,
              ),
              dividerThickness: 0.45,
              border: TableBorder(
                horizontalInside: BorderSide(color: borderColor, width: 0.45),
                verticalInside: BorderSide(color: borderColor, width: 0.45),
                top: BorderSide(color: borderColor, width: 0.45),
                bottom: BorderSide(color: borderColor, width: 0.45),
                left: BorderSide(color: borderColor, width: 0.45),
                right: BorderSide(color: borderColor, width: 0.45),
              ),
            ),
          ),
        );
      },
    );

    final table = enableVerticalScroll
        ? SingleChildScrollView(
            controller: verticalScrollController,
            child: horizontalTable,
          )
        : horizontalTable;

    if (!useCard) {
      return table;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: borderColor),
      ),
      color: cardColor,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(padding: const EdgeInsets.all(12.0), child: table),
      ),
    );
  }
}
