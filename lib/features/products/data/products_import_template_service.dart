import 'dart:io';

import 'package:excel/excel.dart';

class ProductsImportTemplateService {
  static const List<String> _headers = <String>[
    'اسم المنتج',
    'الباركود (اختياري)',
    'نوع الوحدة (قطعة/وزن)',
    'سعر البيع تجزئة',
    'سعر نصف الجملة',
    'سعر الجملة',
    'سعر الشراء',
    'حد المخزون الأدنى',
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

    sheet.appendRow(<CellValue>[TextCellValue('قالب استيراد المنتجات')]);
    sheet.appendRow(<CellValue>[
      TextCellValue(
        'املأ البيانات كما في شاشة إضافة المنتج. الباركود اختياري.',
      ),
    ]);
    sheet.appendRow(<CellValue>[]);

    sheet.appendRow(_headers.map(TextCellValue.new).toList());

    sheet.appendRow(<CellValue>[
      TextCellValue('سكر 1 كيلو'),
      TextCellValue('6221234567890'),
      TextCellValue('قطعة'),
      DoubleCellValue(32.0),
      DoubleCellValue(30.0),
      DoubleCellValue(28.0),
      DoubleCellValue(25.0),
      DoubleCellValue(10.0),
    ]);

    sheet.appendRow(<CellValue>[
      TextCellValue('أرز فاخر 5 كيلو'),
      TextCellValue(''),
      TextCellValue('وزن'),
      DoubleCellValue(185.0),
      DoubleCellValue(180.0),
      DoubleCellValue(175.0),
      DoubleCellValue(160.0),
      DoubleCellValue(4.0),
    ]);

    sheet.appendRow(<CellValue>[
      TextCellValue('زيت 700 مل'),
      TextCellValue('6290001112223'),
      TextCellValue('قطعة'),
      DoubleCellValue(48.0),
      DoubleCellValue(46.0),
      DoubleCellValue(44.0),
      DoubleCellValue(40.0),
      DoubleCellValue(12.0),
    ]);

    final titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.cellStyle = titleStyle;
    final subtitleCell = sheet.cell(CellIndex.indexByString('A2'));
    subtitleCell.cellStyle = subtitleStyle;

    sheet.setRowHeight(0, 28);
    sheet.setRowHeight(1, 34);
    sheet.setRowHeight(3, 28);
    sheet.setDefaultColumnWidth(18);

    final columnWidths = <double>[28, 24, 24, 16, 16, 16, 16, 18];
    for (var i = 0; i < columnWidths.length; i++) {
      sheet.setColumnWidth(i, columnWidths[i]);
    }

    for (var col = 0; col < _headers.length; col++) {
      final headerCell = sheet.cell(
        CellIndex.indexByString(_cellAddress(3, col)),
      );
      headerCell.cellStyle = headerStyle;
    }

    for (var row = 4; row <= 6; row++) {
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
