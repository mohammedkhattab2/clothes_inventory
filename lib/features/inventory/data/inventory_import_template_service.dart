import 'dart:io';

import 'package:excel/excel.dart';

class InventoryImportTemplateService {
  static const List<String> _headers = <String>[
    'اسم المنتج',
    'الباركود (اختياري)',
    'نوع الوحدة',
    'سعر البيع تجزئة',
    'سعر نصف الجملة',
    'سعر الجملة',
    'سعر الشراء',
    'الحد الأدنى للمخزون',
    'الكمية الافتتاحية',
  ];

  Future<String> saveArabicTemplate({required String targetPath}) async {
    final workbook = Excel.createExcel();
    final sheetName = workbook.getDefaultSheet() ?? 'Sheet1';
    final sheet = workbook[sheetName];

    final titleStyle = CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#0F766E'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final subtitleStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#0F172A'),
      backgroundColorHex: ExcelColor.fromHexString('#CCFBF1'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );
    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#155E75'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
      leftBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.white,
      ),
      rightBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.white,
      ),
      topBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.white,
      ),
      bottomBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.white,
      ),
    );
    final rowStyle = CellStyle(
      fontSize: 11,
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
      leftBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.fromHexString('#E2E8F0'),
      ),
      rightBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.fromHexString('#E2E8F0'),
      ),
      topBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.fromHexString('#E2E8F0'),
      ),
      bottomBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.fromHexString('#E2E8F0'),
      ),
    );

    sheet.appendRow(<CellValue>[TextCellValue('قالب استيراد المخزون')]);
    sheet.appendRow(<CellValue>[
      TextCellValue(
        'أدخل بيانات الصنف مثل شاشة إضافة صنف، مع الكمية الافتتاحية ليتم إضافتها مباشرة إلى المخزون.',
      ),
    ]);
    sheet.appendRow(<CellValue>[]);
    sheet.appendRow(_headers.map(TextCellValue.new).toList(growable: false));

    sheet.appendRow(<CellValue>[
      TextCellValue('سكر 1 كيلو'),
      TextCellValue('1234567890123'),
      TextCellValue('قطعة'),
      DoubleCellValue(32),
      DoubleCellValue(30),
      DoubleCellValue(28),
      DoubleCellValue(25.5),
      DoubleCellValue(10),
      DoubleCellValue(20),
    ]);

    sheet.appendRow(<CellValue>[
      TextCellValue('أرز فاخر 5 كيلو'),
      TextCellValue(''),
      TextCellValue('وزن'),
      DoubleCellValue(185),
      DoubleCellValue(180),
      DoubleCellValue(175),
      DoubleCellValue(160),
      DoubleCellValue(4),
      DoubleCellValue(7.5),
    ]);

    final titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.cellStyle = titleStyle;
    final subtitleCell = sheet.cell(CellIndex.indexByString('A2'));
    subtitleCell.cellStyle = subtitleStyle;

    sheet.setRowHeight(0, 28);
    sheet.setRowHeight(1, 36);
    sheet.setRowHeight(3, 28);
    sheet.setDefaultColumnWidth(18);

    final columnWidths = <double>[28, 22, 18, 16, 16, 16, 16, 20, 18];
    for (var i = 0; i < columnWidths.length; i++) {
      sheet.setColumnWidth(i, columnWidths[i]);
    }

    for (var col = 0; col < _headers.length; col++) {
      final headerCell = sheet.cell(
        CellIndex.indexByString(_cellAddress(3, col)),
      );
      headerCell.cellStyle = headerStyle;
    }

    for (var row = 4; row <= 5; row++) {
      sheet.setRowHeight(row, 24);
      for (var col = 0; col < _headers.length; col++) {
        final dataCell = sheet.cell(
          CellIndex.indexByString(_cellAddress(row, col)),
        );
        dataCell.cellStyle = rowStyle;
      }
    }

    final bytes = workbook.encode();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Failed to generate XLSX template.');
    }

    final file = File(targetPath);
    await file.writeAsBytes(bytes, flush: true);
    return targetPath;
  }

  String _cellAddress(int rowIndex, int columnIndex) {
    var col = columnIndex;
    var label = '';
    while (col >= 0) {
      label = String.fromCharCode((col % 26) + 65) + label;
      col = (col ~/ 26) - 1;
    }
    return '$label${rowIndex + 1}';
  }
}
